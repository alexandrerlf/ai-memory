# Nix flake for pitstop.
#
# Provides:
#   nix build              # → result/bin/pitstop  (native release binary)
#   nix run . -- --version # smoke-test without installing
#   nix develop            # dev shell with Rust 1.95 (pinned)
#
# The build is self-contained: SQLite is bundled via rusqlite's `bundled`
# feature, libgit2 is vendored via git2's `vendored-libgit2` feature, and
# TLS uses rustls (webpki-roots) — no OpenSSL, no system-library hunting.
# The only extra step is TAILWIND_SKIP=1 so the web crate's build script
# uses the vendored static/tailwind.css instead of downloading the
# Tailwind CLI (which a sandboxed Nix build cannot do).
#
# `doCheck = false` skips the packaging test suite. Those tests exercise
# `bin/pitstop`, a Docker-wrapper shell script that needs `docker` or
# `podman` on PATH — they are host-environment tests, not build tests,
# and are not Nix's responsibility. Run them manually with
# `nix develop -c cargo test -p pitstop-cli --test packaging` if your
# machine has Docker.

{
  description = "Long-term memory for AI coding agents";

  # Inputs are pinned to explicit revisions rather than floating branches.
  #
  # A flake's value is reproducibility, and `github:NixOS/nixpkgs/nixos-unstable`
  # resolves to whatever that branch points at today, so two people — or the
  # same person a week apart — can get different builds from identical source.
  # Normally `flake.lock` handles this; pinning here achieves the same
  # determinism and keeps the tree honest for contributors who do not have
  # Nix installed and so cannot regenerate a lock.
  #
  # To update: bump these revisions deliberately, in their own commit, and
  # let the `nix` CI job prove the result still builds.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/0ae2bc1419c3f345984c2629e72e7a631820fa4d";
    flake-utils.url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b";
    rust-overlay = {
      url = "github:oxalica/rust-overlay/99607a06c2ea1290cd3258c11d1416dde9201f94";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    let
      linuxPkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ (import rust-overlay) ];
      };
      inherit (linuxPkgs) lib;

      # Eval-only NixOS module smoke tests. Kept at the top level under
      # checks.x86_64-linux only — the eval always targets x86_64-linux, so
      # duplicating these under every package system would add noise on Darwin.
      ageSopsStub =
        { lib, ... }:
        {
          options.age.secrets = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options.path = lib.mkOption { type = lib.types.path; };
            });
            default = { };
          };
          options.sops.secrets = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options.path = lib.mkOption { type = lib.types.path; };
            });
            default = { };
          };
          config.age.secrets.pitstop-env.path = "/run/agenix/pitstop-env";
          config.sops.secrets."pitstop/env".path = "/run/secrets/pitstop/env";
        };

      mkNixos = extra: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ageSopsStub
          { system.stateVersion = "25.05"; }
          extra
        ];
      };

      # enableWeb defaults to false, so the enabled-smoke config sets
      # it explicitly to true — this exercises the --enable-web
      # wiring, it isn't asserting what the default is.
      enabled = mkNixos { services.pitstop = { enable = true; enableWeb = true; }; };
      disabled = mkNixos { services.pitstop.enable = false; };
      apiOnly = mkNixos {
        services.pitstop = {
          enable = true;
          enableApi = true;
        };
      };
      withSettings = mkNixos {
        services.pitstop = {
          enable = true;
          settings.allowed_hosts = [
            "localhost"
            "127.0.0.1"
            "::1"
          ];
          settings.log_level = "info";
        };
      };
      withAge = mkNixos {
        services.pitstop = {
          enable = true;
          bind = "0.0.0.0";
          ageSecret = "pitstop-env";
        };
      };
      withSops = mkNixos {
        services.pitstop = {
          enable = true;
          bind = "0.0.0.0";
          sopsSecret = "pitstop/env";
        };
      };
      loopbackEnvFile = mkNixos {
        services.pitstop = {
          enable = true;
          environmentFile = "/run/pitstop/env";
        };
      };
      nonLoopbackNoSecrets = mkNixos {
        services.pitstop = {
          enable = true;
          bind = "0.0.0.0";
        };
      };
      localhostNoSecrets = mkNixos {
        services.pitstop = {
          enable = true;
          bind = "localhost";
        };
      };
      withIpv6Loopback = mkNixos {
        services.pitstop = {
          enable = true;
          bind = "::1";
        };
      };
      bothAgeAndSops = mkNixos {
        services.pitstop = {
          enable = true;
          ageSecret = "pitstop-env";
          sopsSecret = "pitstop/env";
        };
      };
      ageAndEnvironmentFile = mkNixos {
        services.pitstop = {
          enable = true;
          ageSecret = "pitstop-env";
          environmentFile = "/run/pitstop/env";
        };
      };
      secretsInSettings = mkNixos {
        services.pitstop = {
          enable = true;
          settings.auth.bearer_token = "sekrit";
        };
      };
      headersInSettings = mkNixos {
        services.pitstop = {
          enable = true;
          settings.llm_headers = [ "Authorization: Bearer sekrit" ];
        };
      };
      bindInSettings = mkNixos {
        services.pitstop = {
          enable = true;
          settings.bind = "0.0.0.0";
        };
      };
      withCustomDataDir = mkNixos {
        services.pitstop = {
          enable = true;
          dataDir = "/data/custom pitstop";
        };
      };
      withFirewall = mkNixos {
        services.pitstop = {
          enable = true;
          openFirewall = true;
        };
      };
      withLimits = mkNixos {
        services.pitstop = {
          enable = true;
          memoryMax = "2G";
          tasksMax = 512;
        };
      };

      failingAssertions = sys: lib.filter (a: !a.assertion) sys.config.assertions;
      nonLoopbackFailing = failingAssertions nonLoopbackNoSecrets;
      localhostFailing = failingAssertions localhostNoSecrets;
      ageSopsFailing = failingAssertions bothAgeAndSops;
      ageEnvironmentFailing = failingAssertions ageAndEnvironmentFile;
      secretsFailing = failingAssertions secretsInSettings;
      headersFailing = failingAssertions headersInSettings;
      bindFailing = failingAssertions bindInSettings;

      enabledSc = enabled.config.systemd.services.pitstop.serviceConfig;
      enabledUnit = enabled.config.systemd.services.pitstop;
      execStart = enabledSc.ExecStart;
      settingsExec =
        withSettings.config.systemd.services.pitstop.serviceConfig.ExecStart;
      ipv6Exec = withIpv6Loopback.config.systemd.services.pitstop.serviceConfig.ExecStart;
      apiOnlyExec = apiOnly.config.systemd.services.pitstop.serviceConfig.ExecStart;
      ageUnit = withAge.config.systemd.services.pitstop;
      customSc = withCustomDataDir.config.systemd.services.pitstop.serviceConfig;
      customTmpfiles = withCustomDataDir.config.systemd.tmpfiles.settings."10-pitstop";
      limitsSc = withLimits.config.systemd.services.pitstop.serviceConfig;
      escapedExecArgs = args: lib.concatStringsSep " " (map builtins.toJSON args);

      # One NixOS system for the container smoke path. Building its
      # docker-image tarball builds system.build.toplevel once; there is
      # no separate bare-toplevel check that would rebuild the same closure.
      containerNixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          (
            { modulesPath, pkgs, ... }:
            {
              imports = [ "${modulesPath}/virtualisation/docker-image.nix" ];
              system.stateVersion = "25.05";
              networking.hostName = "pitstop";
              # Slim the closure: docs are useless inside the smoke image.
              documentation.enable = false;
              documentation.doc.enable = false;
              documentation.info.enable = false;
              documentation.man.enable = false;
              documentation.nixos.enable = false;
              # In-container /healthz probe (docker published ports cannot
              # reach the module's default 127.0.0.1 bind).
              environment.systemPackages = [ pkgs.curl ];
              services.pitstop.enable = true;
            }
          )
        ];
      };

      nixosPitstopDocker =
        linuxPkgs.runCommand "nixos-pitstop-docker"
          {
            meta.description = "NixOS rootfs tarball with services.pitstop for systemd-in-container smoke tests";
            passthru = {
              toplevel = containerNixos.config.system.build.toplevel;
              tarball = containerNixos.config.system.build.tarball;
              imageName = "pitstop-nixos-test";
            };
          }
          ''
            mkdir -p "$out"
            # Building this derivation builds toplevel via the tarball dep —
            # single closure path for CI (no duplicate bare-toplevel job).
            ln -s ${containerNixos.config.system.build.tarball}/tarball/*.tar.xz \
              "$out/rootfs.tar.xz"
            ln -s ${containerNixos.config.system.build.toplevel} "$out/toplevel"
            printf '%s\n' "pitstop-nixos-test" > "$out/image-name"
          '';

      nixosChecks = {
        nixos-module-eval =
          assert lib.hasInfix (escapedExecArgs [ "--enable-web" ]) execStart;
          assert lib.hasInfix (escapedExecArgs [ "--enable-api" ]) apiOnlyExec;
          assert !(lib.hasInfix (escapedExecArgs [ "--enable-web" ]) apiOnlyExec);
          assert lib.hasInfix
            (escapedExecArgs [ "--bind" "127.0.0.1:49374" ]) execStart;
          assert lib.hasInfix
            (escapedExecArgs [ "--data-dir" "/var/lib/pitstop" ]) execStart;
          assert lib.hasInfix
            (escapedExecArgs [ "serve" "--transport" "http" ]) execStart;
          assert !(disabled.config.systemd.services ? pitstop);
          assert enabledSc.MemoryDenyWriteExecute == true;
          assert enabledSc.RestrictNamespaces == true;
          assert enabledSc.UMask == "0077";
          assert enabledSc.CapabilityBoundingSet == [ ];
          assert enabledSc.NoNewPrivileges == true;
          assert enabledSc.PrivateTmp == true;
          assert enabledSc.ProtectHome == true;
          assert enabledSc.ProtectSystem == "strict";
          assert enabledSc.StateDirectory == "pitstop";
          assert lib.elem "/var/lib/pitstop" enabledSc.ReadWritePaths;
          assert lib.hasInfix (escapedExecArgs [ "--config" ]) settingsExec;
          assert withAge.config.systemd.services.pitstop.serviceConfig.EnvironmentFile
            == "/run/agenix/pitstop-env";
          assert withSops.config.systemd.services.pitstop.serviceConfig.EnvironmentFile
            == "/run/secrets/pitstop/env";
          assert loopbackEnvFile.config.systemd.services.pitstop.serviceConfig.EnvironmentFile
            == "-/run/pitstop/env";
          assert nonLoopbackFailing != [ ];
          assert lib.any (a: lib.hasInfix "non-loopback bind requires" a.message)
            nonLoopbackFailing;
          assert lib.any (a: lib.hasInfix "non-loopback bind requires" a.message)
            localhostFailing;
          assert lib.hasInfix
            (escapedExecArgs [ "--bind" "[::1]:49374" ]) ipv6Exec;
          assert lib.any (a: lib.hasInfix "mutually exclusive" a.message) ageSopsFailing;
          assert lib.any (a: lib.hasInfix "mutually exclusive" a.message)
            ageEnvironmentFailing;
          assert lib.any (a: lib.hasInfix "settings.auth must not contain secrets" a.message)
            secretsFailing;
          assert lib.any (a: lib.hasInfix "settings.llm_headers" a.message) headersFailing;
          assert lib.any (a: lib.hasInfix "settings.bind is not allowed" a.message)
            bindFailing;
          assert (customSc.StateDirectory or null) == null;
          assert lib.elem "/data/custom pitstop" customSc.ReadWritePaths;
          assert customTmpfiles."/data/custom pitstop".d.mode == "0750";
          assert customTmpfiles."/data/custom pitstop".d.user == "pitstop";
          assert lib.hasInfix
            (escapedExecArgs [ "--data-dir" "/data/custom pitstop" ])
            customSc.ExecStart;
          assert lib.elem "network.target" enabledUnit.after;
          assert !(lib.elem "network-online.target" (enabledUnit.wants or [ ]));
          assert lib.elem "network-online.target" ageUnit.after;
          assert lib.elem "network-online.target" ageUnit.wants;
          assert lib.elem 49374 withFirewall.config.networking.firewall.allowedTCPPorts;
          assert limitsSc.MemoryMax == "2G";
          assert limitsSc.TasksMax == 512;
          linuxPkgs.runCommand "pitstop-nixos-module-eval" { } "touch $out";

      };
    in
    (flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        inherit (pkgs) lib;

        # Read the same toolchain file the project pins for every other CI
        # path — rust-toolchain.toml says `channel = "1.95"`.
        rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        rustPlatform = pkgs.makeRustPlatform {
          rustc = rust;
          cargo = rust;
        };
      in
      {
        packages =
          {
            default = rustPlatform.buildRustPackage {
              pname = "pitstop";
              version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;

              src = ./.;
              cargoLock = {
                lockFile = ./Cargo.lock;
                outputHashes = {
                  "zip-8.6.0" = "sha256-cnLvGK9nhGeYqJYA6kjlYTYChH0fXs2q27rWvHEZWpg=";
                };
              };

              # No nativeBuildInputs needed — the build is fully self-contained
              # (SQLite bundled, libgit2 vendored, rustls with webpki-roots).
              #
              # The binary is deliberately NOT wrapped (wrapProgram renames it
              # to `.pitstop-wrapped`, which hides a running server from the
              # live-process guard that matches the process name `pitstop`).
              # Commands that shell out to `git` find it on PATH; the NixOS
              # module adds git to the service's PATH.

              # Skip the Tailwind CLI download in the sandbox. The build script
              # falls back to the vendored static/tailwind.css committed to the
              # repo (see crates/pitstop-web/build.rs).
              TAILWIND_SKIP = "1";

              buildType = "release";

              # The packaging test suite (tests/packaging.rs) exercises the
              # Docker-wrapper shell script `bin/pitstop` and needs
              # docker/podman on PATH — not available in a Nix sandbox. The
              # rest of the workspace test suite (unit tests + integration)
              # does not need them and can be run via `nix develop -c cargo
              # test --workspace` on a machine with Docker.
              doCheck = false;

              # Install the bundled hook scripts alongside the binary,
              # mirroring what the AUR PKGBUILD does. Native binary users
              # (`pitstop serve`, `install-hooks`) look up hooks under
              # the binary's share directory at runtime.
              #
              # `bin/pitstop` (the Docker-wrapper shell script) is NOT
              # installed — Nix users build the native binary directly and
              # have no need for a Docker wrapper.
              postInstall = ''
                mkdir -p $out/share/pitstop
                cp -a hooks $out/share/pitstop/

                # Install the default config template so `pitstop init`
                # has a known-good starting point without a network fetch.
                mkdir -p $out/etc/pitstop
                cp crates/pitstop-cli/templates/config.default.toml \
                   $out/etc/pitstop/config.default.toml
              '';

              meta = {
                description = "Long-term memory for AI coding agents";
                homepage = "https://aimemory.sh";
                license = pkgs.lib.licenses.mit;
                mainProgram = "pitstop";
              };
            };
          }
          // lib.optionalAttrs (system == "x86_64-linux") {
            # Rootfs tarball derived from the same NixOS system as
            # passthru.toplevel — single closure for the container smoke.
            nixos-pitstop-docker = nixosPitstopDocker;
          };

        devShells.default = pkgs.mkShell {
          name = "pitstop-dev";

          buildInputs = [
            rust
            pkgs.cargo-watch
          ];

          # Same escape hatch for local `cargo build` / `cargo test` —
          # prevents the web crate from trying to download Tailwind.
          TAILWIND_SKIP = "1";

          shellHook = ''
            echo ""
            echo "pitstop dev shell — Rust $(rustc --version)"
            echo ""
            echo "  cargo build --workspace          # build"
            echo "  cargo test --workspace           # unit + integration tests"
            echo "  cargo test -p pitstop-cli --test packaging  # needs docker"
            echo ""
          '';
        };
      }
    ))
    // {
      # Additive: a NixOS host can run `services.pitstop.enable = true` to
      # get this binary as a hardened systemd service (see
      # nix/nixos-module.nix). Merged at the top level, not inside
      # eachSystem, because NixOS modules are not system-scoped.
      nixosModules.default =
        { pkgs, lib, ... }:
        {
          imports = [ ./nix/nixos-module.nix ];
          config.services.pitstop.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      checks.x86_64-linux = nixosChecks;
    };
}
