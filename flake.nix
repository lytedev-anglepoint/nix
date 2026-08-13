{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    iosevka-lyte.url = "github:lytedev-anglepoint/iosevka-lyte";

    lytedev.url = "git+https://git.lyte.dev/lytedev/nix";
    lytedev.inputs.iosevka-lyte.follows = "iosevka-lyte";
    lytedev.inputs.nixpkgs-unstable.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      inherit (inputs) self;
      inherit (self) outputs;

      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = inputs.nixpkgs.lib.genAttrs systems;

      # Upstream's darwinModules do not evaluate on nix-darwin at current
      # main: the shared shell-config defines NixOS-only options
      # (services.fwupd, programs.git, ...) under `lib.mkIf (!isDarwin)`, and
      # the module system requires options to be declared even when the
      # condition is false. patches/lytedev-darwin-eval.patch switches that
      # block to `lib.optionalAttrs`, which removes the definitions entirely
      # on darwin. Import the darwin modules from a patched copy of the
      # source until the fix lands upstream; the substitute `self` points the
      # modules (and therefore lyte.dotfilesPath) at the patched tree.
      lytedevDarwin =
        let
          pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
          src = pkgs.applyPatches {
            name = "lytedev-nix-darwin-eval-fix";
            src = inputs.lytedev;
            patches = [ ./patches/lytedev-darwin-eval.patch ];
          };
          self' = {
            outPath = "${src}";
            inherit (inputs.lytedev) lastModified;
            inherit (inputs.lytedev) flakeLib;
            outputs = {
              darwinModules = modules;
            };
          };
          modules = import "${src}/lib/modules/darwin" (inputs.lytedev.inputs // { self = self'; });
        in
        modules;

      deployPkgs = import inputs.nixpkgs {
        system = "aarch64-darwin";
        overlays = [
          inputs.deploy-rs.overlays.default
          (final: prev: {
            deploy-rs = {
              inherit (prev) deploy-rs;
              lib = inputs.deploy-rs.lib;
            };
          })
        ];
      };
    in
    {
      darwinConfigurations = {
        "APT-CXWK6Q1603-915" = inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            lytedevDarwin.default
            (
              { lib, pkgs, ... }:
              let
                username = "daniel.flanagan";
                userHome = "/Users/${username}";

                # A minimal .app bundle that opens files in helix inside
                # ghostty, so Finder and `open` have an editor to associate
                # file types with.
                helix-app = pkgs.stdenvNoCC.mkDerivation {
                  pname = "Helix";
                  version = "1.0.0";
                  dontUnpack = true;
                  installPhase = ''
                    mkdir -p "$out/Applications/Helix.app/Contents/MacOS"
                    cat > "$out/Applications/Helix.app/Contents/MacOS/Helix" <<'SCRIPT'
                    #!/bin/bash
                    open -a Ghostty --args -e hx -- "$@"
                    SCRIPT
                    chmod +x "$out/Applications/Helix.app/Contents/MacOS/Helix"
                    cat > "$out/Applications/Helix.app/Contents/Info.plist" <<'PLIST'
                    <?xml version="1.0" encoding="UTF-8"?>
                    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                    <plist version="1.0">
                    <dict>
                      <key>CFBundleName</key>
                      <string>Helix</string>
                      <key>CFBundleIdentifier</key>
                      <string>dev.lyte.helix-wrapper</string>
                      <key>CFBundleVersion</key>
                      <string>1.0.0</string>
                      <key>CFBundleExecutable</key>
                      <string>Helix</string>
                      <key>CFBundleDocumentTypes</key>
                      <array>
                        <dict>
                          <key>CFBundleTypeRole</key>
                          <string>Editor</string>
                          <key>LSItemContentTypes</key>
                          <array>
                            <string>public.plain-text</string>
                            <string>public.source-code</string>
                            <string>public.shell-script</string>
                            <string>public.script</string>
                            <string>public.json</string>
                            <string>public.xml</string>
                            <string>public.yaml</string>
                            <string>public.data</string>
                            <string>net.daringfireball.markdown</string>
                          </array>
                        </dict>
                      </array>
                    </dict>
                    </plist>
                    PLIST
                  '';
                };

                # Copied (not symlinked) into ~/Applications because
                # LaunchServices does not reliably register apps behind
                # symlinks into the nix store. duti must run as the user since
                # file associations live in the per-user LaunchServices
                # database.
                helix-file-associations = pkgs.writeShellScript "helix-file-associations" ''
                  set -eu
                  HELIX_APP="${userHome}/Applications/Helix.app"
                  rm -rf "$HELIX_APP"
                  mkdir -p "${userHome}/Applications"
                  cp -rL "${helix-app}/Applications/Helix.app" "$HELIX_APP"
                  chmod -R u+w "$HELIX_APP"

                  BUNDLE_ID="dev.lyte.helix-wrapper"
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.plain-text editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.source-code editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.shell-script editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.json editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.xml editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" public.yaml editor
                  ${pkgs.duti}/bin/duti -s "$BUNDLE_ID" net.daringfireball.markdown editor
                '';
              in
              {
                networking.hostName = "APT-CXWK6Q1603-915";
                system.stateVersion = 6;

                # Determinate Nix manages the nix installation
                nix.enable = false;

                # mkAfter so this composes after upstream's forSelfOverlay;
                # otherwise the iamb/spotify-player replacements below lose.
                nixpkgs.overlays = lib.mkAfter [
                  (final: prev: {
                    # Fix Go packages that fail with "-linkmode=external requires cgo" on macOS 26
                    direnv = prev.direnv.overrideAttrs (old: {
                      env = (old.env or { }) // { CGO_ENABLED = 1; };
                    });

                    # The network here 403s nixpkgs' fetch-cargo-vendor-util
                    # (user-agent filtering at the proxy), so upstream's
                    # from-source rust packages cannot vendor their crates.
                    # Use binary-cached nixpkgs builds instead — from
                    # lytedev's locked stable nixpkgs, because our own pin is
                    # old enough that its iamb fails to compile (rustc E0275
                    # in matrix-sdk) and is not cached for darwin. Note:
                    # upstream bumped spotify-player to 0.24.1 because the
                    # nixpkgs build is broken at runtime; live with that here.
                    inherit (inputs.lytedev.inputs.nixpkgs.legacyPackages.aarch64-darwin)
                      iamb
                      spotify-player
                      ;
                  })
                ];

                users.users.${username}.uid = 502;

                # Required for user-scoped options (launchd.user.agents, etc.)
                system.primaryUser = username;

                lyte = {
                  inherit username userHome;
                  shell.enable = true;
                  desktop.enable = true;
                  # editableConfigFiles = true;
                  # flakePath = "/Users/daniel.flanagan/nix";
                };

                environment.systemPackages = with pkgs; [
                  gh
                  awscli2
                  git

                  duti

                  # container runtime for local dev/test (e.g. `docker compose up -d`).
                  # colima runs a Linux VM with a real Docker daemon; run `colima start`
                  # once after switching. NOTE: lyte shell-config ships a
                  # docker-compose->podman-compose shim on PATH, so use the
                  # `docker compose` subcommand (works) rather than bare `docker-compose`.
                  colima
                  docker
                  docker-compose

                  # Serves the household assistant's local model. Declared so a
                  # GC cannot delete the binary out from under the running
                  # server.
                  ollama
                ];

                # Keep the model server up without a human.
                #
                # It answers for the assistant on bigtower whenever Claude is
                # unavailable, so it has to survive a crash, a logout, and a
                # reboot on its own.
                launchd.user.agents.ollama = {
                  serviceConfig = {
                    ProgramArguments = [
                      "${pkgs.ollama}/bin/ollama"
                      "serve"
                    ];
                    RunAtLoad = true;
                    KeepAlive = true;
                    EnvironmentVariables = {
                      # Bind to the LAN, not just loopback: another host
                      # reaches it.
                      OLLAMA_HOST = "0.0.0.0:11434";
                    };
                    StandardOutPath = "${userHome}/Library/Logs/ollama.log";
                    StandardErrorPath = "${userHome}/Library/Logs/ollama.err.log";
                  };
                };

                # Copy Helix.app into ~/Applications and set file associations
                system.activationScripts.extraActivation.text = ''
                  sudo -u ${username} ${helix-file-associations} || echo "warning: helix file associations failed" >&2
                '';
              }
            )
          ];
        };
      };

      deploy = {
        nodes = {
          work-mac = {
            hostname = "Mac.lan";
            remoteBuild = true;
            interactiveSudo = true;
            profiles.system = {
              sshUser = "daniel.flanagan";
              user = "root";
              path =
                deployPkgs.deploy-rs.lib.aarch64-darwin.activate.darwin
                  self.darwinConfigurations."APT-CXWK6Q1603-915";
            };
          };
        };
      };

      formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.alejandra);

      checks = forAllSystems (system: {
        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
          };
        };
      });

      devShell = forAllSystems (
        system:
        inputs.nixpkgs.legacyPackages.${system}.mkShell {
          inherit (outputs.checks.${system}.pre-commit-check) shellHook;
          packages = [ inputs.deploy-rs.packages.${system}.default ];
        }
      );
    };
}
