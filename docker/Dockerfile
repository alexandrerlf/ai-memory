# syntax=docker/dockerfile:1.7
#
# Multi-stage build for the pitstop MCP server.
# Builder: rust:1.95-slim with the release binary cached against
#          BuildKit's cargo registry + target caches.
# Runtime: debian:bookworm-slim with a non-root `pitstop` user that
#          owns /data. CA certificates included for outgoing HTTPS (LLM
#          providers in M6+).
#
# The default final target builds the binary from source. Release automation and
# CI can target the prebuilt runtime stages after downloading native release
# artifacts, avoiding duplicate Rust compiles in Docker jobs.

FROM rust:1.95-slim-bookworm AS builder
WORKDIR /work
# Optional console; default builds retain the existing feature set.
ARG PITSTOP_FEATURES=""
RUN apt-get update \
 && apt-get install -y --no-install-recommends pkg-config build-essential curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock rust-toolchain.toml deny.toml LICENSE ./
COPY crates ./crates
# `evals/` is a workspace member (off-tree A/B harness, not shipped
# in the image — but Cargo refuses to parse the workspace manifest
# if a declared member doesn't exist on disk). Copy the dir so the
# manifest resolves; `-p pitstop-cli` keeps the binary build narrow.
COPY evals ./evals
# `docs/logo*.png` are include_bytes!'d by pitstop-web's static
# routes at compile time, so they must be in the build context.
COPY docs ./docs
# Product documentation embeds the current changelog into the web binary.
COPY CHANGELOG.md ./
# `pitstop setup` renders the user service from these packaged templates,
# include_str!'d at compile time.
COPY packaging/systemd ./packaging/systemd
COPY packaging/launchd ./packaging/launchd
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/work/target \
    cargo build --locked --release -p pitstop-cli --features "${PITSTOP_FEATURES}" \
 && cp target/release/pitstop /usr/local/bin/pitstop

FROM debian:bookworm-slim AS runtime-base
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 1000 --user-group --home-dir /data \
         --shell /usr/sbin/nologin pitstop \
 && mkdir -p /data \
 && chown -R pitstop:pitstop /data
# Lifecycle-hook scripts bundled into the image so docker-only users
# can `pitstop setup-agent` without needing a repo checkout. The
# scripts live on a path scanned by `install_hooks::resolve_hooks_dir`
# (and by `setup_agent::resolve_source`).
COPY hooks /usr/local/share/pitstop/hooks
ENV PITSTOP_DATA_DIR=/data
# Allow Docker Desktop's host alias by default so the macOS wrapper's
# thin-client commands — which reach the loopback-published server from a
# one-shot helper container via host.docker.internal — aren't rejected by the
# Host-header DNS-rebinding guard (issue #107). This widens only the *image*
# default; native (non-Docker) installs keep the loopback-only default, and
# exposed/homelab deployments still set their own `PITSTOP_ALLOWED_HOSTS`,
# which replaces this value entirely.
ENV PITSTOP_ALLOWED_HOSTS="localhost,127.0.0.1,::1,host.docker.internal"
# Tell the server it is containerised, so the unauthenticated-bind guard in
# `serve` knows the `0.0.0.0` bind below is a namespace requirement rather
# than evidence of network exposure (issue #407). `/.dockerenv` covers Docker
# and `/run/.containerenv` covers Podman; this makes the signal explicit and
# runtime-independent.
ENV PITSTOP_IN_CONTAINER=1
WORKDIR /data
EXPOSE 49374
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/pitstop", "status"]
ENTRYPOINT ["/usr/local/bin/pitstop"]
CMD ["serve", "--transport", "http", "--bind", "0.0.0.0:49374", "--enable-web"]

FROM runtime-base AS runtime-prebuilt-amd64
COPY --chmod=0755 dist/docker/pitstop-linux-x86_64/pitstop /usr/local/bin/pitstop
USER pitstop

FROM runtime-base AS runtime-prebuilt-arm64
COPY --chmod=0755 dist/docker/pitstop-linux-aarch64/pitstop /usr/local/bin/pitstop
USER pitstop

FROM runtime-base AS runtime-source
COPY --from=builder /usr/local/bin/pitstop /usr/local/bin/pitstop
USER pitstop
