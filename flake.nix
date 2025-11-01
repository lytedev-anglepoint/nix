{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    iosevka-lyte.url = "github:lytedev-anglepoint/iosevka-lyte";

    lytedev.url = "git+https://git.lyte.dev/lytedev/nix";
    lytedev.inputs.iosevka-lyte.follows = "iosevka-lyte";
    lytedev.inputs.nixpkgs.follows = "nixpkgs";
    lytedev.inputs.home-manager.follows = "home-manager";
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
      homeConfigurations = {
        "daniel.flanagan" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs =
            (import inputs.nixpkgs { system = "aarch64-darwin"; }).extend
              inputs.lytedev.overlays.forSelf;

          modules = with inputs.lytedev.homeManagerModules; [
            (
              { lib, pkgs, ... }:
              {
                home = {
                  stateVersion = "25.11";
                  username = lib.mkForce "daniel.flanagan";
                  homeDirectory = lib.mkForce "/Users/daniel.flanagan";
                };
                programs.home-manager.enable = true;

                # install using the OS's package manager instead
                programs.firefox.enable = false;
                programs.ghostty.enable = false;

                lyte.shell = {
                  enable = true;
                  learn-jujutsu-not-git.enable = true;
                };
                lyte.desktop = {
                  enable = true;
                  environment = "macos";
                };

                programs.btop = {
                  package = lib.mkForce pkgs.btop;
                };

                home.pointerCursor.enable = lib.mkForce false;

                home.packages = with pkgs; [ gh ];
                # programs.ssh.enable = lib.mkForce false;
                # programs.atuin.enable = lib.mkForce false;
              }
            )
            daniel
            default
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
