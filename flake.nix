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
        "APT-CXWK6Q1603-665" = inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            inputs.lytedev.darwinModules.default
            (
              { lib, pkgs, ... }:
              {
                networking.hostName = "APT-CXWK6Q1603-665";
                system.stateVersion = 6;

                # Determinate Nix manages the nix installation
                nix.enable = false;

                # Fix Go packages that fail with "-linkmode=external requires cgo" on macOS 26
                nixpkgs.overlays = [
                  (final: prev: {
                    direnv = prev.direnv.overrideAttrs (old: {
                      env = (old.env or {}) // {CGO_ENABLED = 1;};
                    });
                  })
                ];

                users.users."daniel.flanagan".uid = 502;

                lyte = {
                  username = "daniel.flanagan";
                  shell.enable = true;
                  desktop.enable = true;
                  # editableConfigFiles = true;
                  # flakePath = "/Users/daniel.flanagan/code/nix";
                };

                environment.systemPackages = with pkgs; [
                  gh
                  awscli2
                  git
                ];
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
                  self.darwinConfigurations."APT-CXWK6Q1603-665";
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
