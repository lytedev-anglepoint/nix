{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    iosevka-lyte.url = "github:lytedev-anglepoint/iosevka-lyte";

    lytedev.url = "git+https://git.lyte.dev/lytedev/nix?ref=nix-darwin";
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

                lyte = {
                  username = "daniel.flanagan";
                  shell.enable = true;
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
        }
      );
    };
}
