#!/usr/bin/env bash
# Privileged NixOS systemd-in-container smoke for services.pitstop.
#
# Builds (or reuses) packages.x86_64-linux.nixos-pitstop-docker — a rootfs
# tarball derived from one NixOS system.build.toplevel — imports it into
# Docker/Podman, starts systemd as PID 1, and checks:
#   - systemctl is-active pitstop
#   - curl /healthz inside the container (module default bind is loopback;
#     Docker published ports hit eth0 and cannot reach 127.0.0.1)
#   - a marker under /var/lib/pitstop survives systemctl restart
#   - optional: the same marker survives a recreate with a named volume
#
# Boot race: right after /init, /run/current-system/sw/bin is not linked yet.
# wait_for_exec_ready polls until systemctl is executable (stderr quiet during
# that window). Early OCI "systemctl: not found in $PATH" lines are boot lag,
# not a unit failure — they must not appear once readiness is explicit.
#
# Non-goals (do not extend this script for them):
#   - A→B flake/package upgrade or SQLite-wiki migration matrices
#   - Exhaustive settings-options.nix key coverage
#   - Soft/fake systemd without a real unit start
#   - Claiming the app Docker image covers the NixOS module path
#   - Re-asserting every sandbox key (covered by module evaluation)

set -euo pipefail

IMAGE_NAME="${PITSTOP_NIXOS_TEST_IMAGE:-pitstop-nixos-test}"
CONTAINER_NAME="${PITSTOP_NIXOS_TEST_CONTAINER:-pitstop-nixos-systemd-test}"
VOLUME_NAME="${PITSTOP_NIXOS_TEST_VOLUME_NAME:-pitstop-nixos-test-data}"
KEEP="${PITSTOP_NIXOS_TEST_KEEP:-0}"
# Default on: one volume remount persistence pass. Set 0 to skip.
TEST_VOLUME="${PITSTOP_NIXOS_TEST_VOLUME:-1}"
# Probed via docker exec against the unit's loopback bind (not host-mapped).
HEALTH_URL="http://127.0.0.1:49374/healthz"
DATA_DIR="/var/lib/pitstop"
MARKER_PATH="${DATA_DIR}/.pitstop-nixos-ci-marker"
MARKER_VALUE="nixos-container-smoke"

ENGINE=""
ROOTFS=""
BUILT_IMAGE=0
# docker import leaves no image ENV PATH. Inject the NixOS system bin dirs
# on every exec (nixpkgs docker-image.nix documents /run/current-system/…).
# Profile path covers the brief window before activation links current-system.
NIXOS_PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/system/sw/bin:/bin"

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

ctr_exec() {
  "${ENGINE}" exec -e "PATH=${NIXOS_PATH}" "${CONTAINER_NAME}" "$@"
}

ctr_exec_root() {
  "${ENGINE}" exec -u root -e "PATH=${NIXOS_PATH}" "${CONTAINER_NAME}" "$@"
}

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/.." && pwd
}

detect_engine() {
  if [ -n "${PITSTOP_DOCKER:-}" ]; then
    ENGINE="${PITSTOP_DOCKER}"
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    ENGINE=docker
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
    return 0
  fi
  fail "need docker or podman on PATH (or set PITSTOP_DOCKER)"
}

cleanup() {
  if [ "${KEEP}" = "1" ]; then
    log "Keeping container ${CONTAINER_NAME} (PITSTOP_NIXOS_TEST_KEEP=1)"
    return 0
  fi
  if [ -n "${ENGINE}" ]; then
    "${ENGINE}" rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    if [ "${TEST_VOLUME}" = "1" ]; then
      "${ENGINE}" volume rm -f "${VOLUME_NAME}" >/dev/null 2>&1 || true
    fi
    if [ "${BUILT_IMAGE}" = "1" ] && [ "${KEEP}" != "1" ]; then
      "${ENGINE}" rmi -f "${IMAGE_NAME}" >/dev/null 2>&1 || true
    fi
  fi
}

# Activation links /run/current-system a few seconds after /init. Until then,
# docker exec with NIXOS_PATH fails with OCI "executable file not found".
# Poll quietly; fail hard if PATH never appears.
wait_for_exec_ready() {
  local i
  for i in $(seq 1 120); do
    if ctr_exec test -x /run/current-system/sw/bin/systemctl >/dev/null 2>&1; then
      log "PATH ready (systemctl executable)"
      return 0
    fi
    sleep 0.5
  done
  fail "timed out waiting for /run/current-system/sw/bin/systemctl (activation PATH never appeared)"
}

wait_for_http() {
  local url="$1"
  local i
  for i in $(seq 1 120); do
    if ctr_exec curl -fsS "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  ctr_exec journalctl -u pitstop --no-pager -n 120 >&2 || true
  fail "timed out waiting for in-container ${url}"
}

wait_for_active() {
  local i
  for i in $(seq 1 120); do
    if ctr_exec systemctl is-active --quiet pitstop; then
      return 0
    fi
    sleep 0.5
  done
  ctr_exec systemctl status pitstop --no-pager >&2 || true
  ctr_exec journalctl -u pitstop --no-pager -n 120 >&2 || true
  fail "timed out waiting for systemctl is-active pitstop"
}

run_container() {
  local extra_args=("$@")
  # Privileged + host cgroup namespace: systemd as PID 1 on cgroup v2 hosts
  # (including GitHub Actions ubuntu-latest) needs this to activate units.
  # No -p: default --bind is 127.0.0.1; published ports never reach it.
  "${ENGINE}" run -d --name "${CONTAINER_NAME}" \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    "${extra_args[@]}" \
    "${IMAGE_NAME}" /init
}

write_marker() {
  # PATH is injected so chown/coreutils resolve after activation.
  ctr_exec_root /bin/sh -c \
    "printf '%s\n' '${MARKER_VALUE}' > '${MARKER_PATH}' && chown pitstop:pitstop '${MARKER_PATH}'"
}

assert_marker() {
  local got
  got="$(ctr_exec cat "${MARKER_PATH}")"
  if [ "${got}" != "${MARKER_VALUE}" ]; then
    fail "marker mismatch at ${MARKER_PATH}: expected '${MARKER_VALUE}', got '${got}'"
  fi
}

smoke_once() {
  wait_for_exec_ready

  log "Waiting for pitstop unit"
  wait_for_active
  ctr_exec systemctl is-active pitstop

  log "Waiting for in-container ${HEALTH_URL}"
  wait_for_http "${HEALTH_URL}"
  ctr_exec curl -fsS "${HEALTH_URL}" >/dev/null

  log "Writing marker and restarting pitstop"
  write_marker
  ctr_exec systemctl restart pitstop
  wait_for_active
  wait_for_http "${HEALTH_URL}"
  assert_marker
  log "Marker survived systemctl restart"
}

main() {
  detect_engine
  trap cleanup EXIT

  local root
  root="$(repo_root)"
  cd "${root}"

  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64 | Linux-amd64) ;;
    *)
      fail "NixOS container smoke is Linux x86_64 only (got $(uname -s)-$(uname -m))"
      ;;
  esac

  log "Building packages.x86_64-linux.nixos-pitstop-docker"
  nix build --print-build-logs '.#packages.x86_64-linux.nixos-pitstop-docker'
  ROOTFS="$(pwd)/result/rootfs.tar.xz"
  if [ ! -e "${ROOTFS}" ]; then
    fail "missing rootfs tarball at ${ROOTFS}"
  fi
  if [ -f "$(pwd)/result/image-name" ]; then
    IMAGE_NAME="$(tr -d '[:space:]' <"$(pwd)/result/image-name")"
  fi

  cleanup
  # Re-arm trap after cleanup cleared a previous container.
  trap cleanup EXIT

  log "Importing rootfs into ${ENGINE} as ${IMAGE_NAME}"
  "${ENGINE}" import "${ROOTFS}" "${IMAGE_NAME}"
  BUILT_IMAGE=1

  log "Starting privileged NixOS container ${CONTAINER_NAME}"
  run_container

  smoke_once

  if [ "${TEST_VOLUME}" = "1" ]; then
    log "Recreating with named volume ${VOLUME_NAME} at ${DATA_DIR}"
    "${ENGINE}" rm -f "${CONTAINER_NAME}" >/dev/null
    "${ENGINE}" volume rm -f "${VOLUME_NAME}" >/dev/null 2>&1 || true
    "${ENGINE}" volume create "${VOLUME_NAME}" >/dev/null

    run_container -v "${VOLUME_NAME}:${DATA_DIR}"
    wait_for_exec_ready
    wait_for_active
    wait_for_http "${HEALTH_URL}"
    write_marker

    log "Remounting volume and checking marker survival"
    "${ENGINE}" rm -f "${CONTAINER_NAME}" >/dev/null
    run_container -v "${VOLUME_NAME}:${DATA_DIR}"
    wait_for_exec_ready
    wait_for_active
    wait_for_http "${HEALTH_URL}"
    assert_marker
    log "Marker survived volume remount"
  fi

  log "NixOS systemd container smoke passed"
}

main "$@"
