#!/usr/bin/env bash
# Manual native Linux integration test for the Arch/AUR install path.
#
# This is intentionally not part of CI. It creates a disposable Arch distrobox,
# installs the current working tree into native filesystem locations, then tests
# the packaged systemd assets against a real system manager where distrobox
# supports `--init`.

set -euo pipefail

BOX_NAME="${PITSTOP_NATIVE_TEST_BOX:-pitstop-native-systemd-test}"
IMAGE="${PITSTOP_NATIVE_TEST_IMAGE:-docker.io/library/archlinux:latest}"
KEEP_BOX="${PITSTOP_NATIVE_TEST_KEEP_BOX:-0}"
HOST_TEST_HOME=""

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

assert_inside_container() {
  if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${container:-}" ]; then
    return 0
  fi
  if command -v systemd-detect-virt >/dev/null 2>&1 \
    && systemd-detect-virt --container --quiet; then
    return 0
  fi
  fail "refusing to run destructive native install test outside a container/distrobox"
}

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/.." && pwd
}

wait_for_http() {
  local url="$1"
  local unit="$2"
  for _ in $(seq 1 80); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  journalctl -u "${unit}" --no-pager -n 120 >&2 || true
  fail "timed out waiting for ${url}"
}

run_inside() {
  assert_inside_container

  cd /work/pitstop

  log "Installing Arch build/runtime dependencies"
  sudo pacman -Syu --noconfirm --needed \
    base-devel \
    ca-certificates \
    curl \
    git \
    pkgconf \
    rustup \
    systemd

  log "Installing Rust 1.95 toolchain"
  rustup toolchain install 1.95 --profile minimal --component rustfmt --component clippy
  rustup default 1.95

  log "Checking package metadata syntax"
  bash -n packaging/aur/PKGBUILD
  bash -n packaging/aur/PKGBUILD-bin
  (cd packaging/aur && makepkg --printsrcinfo -p PKGBUILD) >/tmp/pitstop.PKGBUILD.SRCINFO
  (cd packaging/aur && makepkg --printsrcinfo -p PKGBUILD-bin) >/tmp/pitstop-bin.PKGBUILD.SRCINFO

  log "Building pitstop release binary from current working tree"
  cargo build --release -p pitstop-cli

  log "Installing native package layout into the disposable distrobox"
  sudo install -Dm0755 target/release/pitstop /usr/bin/pitstop
  sudo rm -rf /usr/share/pitstop/hooks
  sudo install -dm0755 /usr/share/pitstop
  sudo cp -a hooks /usr/share/pitstop/
  sudo install -Dm0644 crates/pitstop-cli/templates/config.default.toml /etc/pitstop/config.toml
  sudo install -Dm0640 packaging/env/pitstop.env /etc/pitstop/env
  sudo install -Dm0644 packaging/systemd/pitstop.service /usr/lib/systemd/system/pitstop.service
  sudo install -Dm0644 packaging/systemd/pitstop-user.service /usr/lib/systemd/user/pitstop.service
  sudo install -Dm0644 packaging/sysusers/pitstop.conf /usr/lib/sysusers.d/pitstop.conf
  sudo install -Dm0644 packaging/tmpfiles/pitstop.conf /usr/lib/tmpfiles.d/pitstop.conf

  log "Verifying systemd unit files"
  systemd-analyze verify /usr/lib/systemd/system/pitstop.service
  systemd-analyze --user verify /usr/lib/systemd/user/pitstop.service

  log "Creating system service user and state directory"
  sudo systemd-sysusers /usr/lib/sysusers.d/pitstop.conf
  sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/pitstop.conf
  test -d /var/lib/pitstop
  test "$(stat -c '%U:%G' /var/lib/pitstop)" = "pitstop:pitstop"

  log "Initializing system-service data with explicit /var + /etc paths"
  sudo -u pitstop /usr/bin/pitstop \
    --data-dir /var/lib/pitstop \
    --config /etc/pitstop/config.toml \
    init
  sudo test -d /var/lib/pitstop/wiki
  sudo test -d /var/lib/pitstop/db

  if ! systemctl list-units --type=service --no-pager >/dev/null 2>&1; then
    fail "systemd is not reachable inside this distrobox. Recreate with distrobox --init, or use a provider that supports systemd containers."
  fi

  log "Starting packaged system service with real systemctl"
  sudo systemctl daemon-reload
  sudo systemctl restart pitstop.service
  wait_for_http http://127.0.0.1:49374/web pitstop.service
  sudo -u pitstop /usr/bin/pitstop \
    --data-dir /var/lib/pitstop \
    --config /etc/pitstop/config.toml \
    status --json >/tmp/pitstop-system-status.json
  sudo systemctl stop pitstop.service

  log "Initializing user profile paths"
  mkdir -p "${HOME}/.config/pitstop" "${HOME}/.local/share/pitstop"
  /usr/bin/pitstop \
    --data-dir "${HOME}/.local/share/pitstop" \
    --config "${HOME}/.config/pitstop/config.toml" \
    init
  sed -i 's/127\.0\.0\.1:49374/127.0.0.1:49375/' "${HOME}/.config/pitstop/config.toml"

  log "Starting user-profile command under transient systemd supervision"
  sudo systemd-run \
    --unit pitstop-user-profile-smoke \
    --collect \
    --uid "$(id -u)" \
    --gid "$(id -g)" \
    --setenv "HOME=${HOME}" \
    /usr/bin/pitstop \
      --data-dir "${HOME}/.local/share/pitstop" \
      --config "${HOME}/.config/pitstop/config.toml" \
      serve --transport http --enable-web
  wait_for_http http://127.0.0.1:49375/web pitstop-user-profile-smoke.service
  sudo systemctl stop pitstop-user-profile-smoke.service

  log "Verifying packaged hook source lookup and agent config writes"
  /usr/bin/pitstop install-mcp --client claude-code --apply --server-url http://127.0.0.1:49375/mcp
  /usr/bin/pitstop install-hooks --agent claude-code --apply --server-url http://127.0.0.1:49375
  test -x "${HOME}/.local/share/pitstop/hooks/claude-code/session-start.sh"
  test -f "${HOME}/.claude.json"

  log "Native Arch systemd integration passed"
}

main() {
  if [ "${PITSTOP_NATIVE_TEST_INNER:-0}" = "1" ]; then
    run_inside
    return
  fi

  command -v distrobox >/dev/null 2>&1 || fail "distrobox is required"

  local repo
  repo="$(repo_root)"
  HOST_TEST_HOME="$(mktemp -d /tmp/pitstop-native-home.XXXXXX)"

  cleanup() {
    if [ "${KEEP_BOX}" != "1" ]; then
      distrobox rm --force "${BOX_NAME}" >/dev/null 2>&1 || true
      if [ -n "${HOST_TEST_HOME}" ]; then
        rm -rf "${HOST_TEST_HOME}"
      fi
    else
      printf 'keeping distrobox %s and home %s\n' "${BOX_NAME}" "${HOST_TEST_HOME}" >&2
    fi
  }
  trap cleanup EXIT

  log "Creating disposable Arch distrobox ${BOX_NAME}"
  distrobox rm --force "${BOX_NAME}" >/dev/null 2>&1 || true
  distrobox create \
    --yes \
    --name "${BOX_NAME}" \
    --image "${IMAGE}" \
    --init \
    --home "${HOST_TEST_HOME}" \
    --volume "${repo}:/work/pitstop:rw"

  log "Running native integration inside ${BOX_NAME}"
  distrobox enter "${BOX_NAME}" -- \
    env PITSTOP_NATIVE_TEST_INNER=1 \
    bash /work/pitstop/scripts/test-native-arch-systemd-distrobox.sh
}

main "$@"
