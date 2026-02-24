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
              let
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
              in
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

                home.packages = with pkgs; [
                  gh
                  awscli2

                  # TODO: should be included in lyte.shell.enable?
                  git
                  sd
                  fd

                  duti
                  helix-app
                ];

                # symlink Helix.app into ~/Applications and set file associations
                home.activation.helix-file-associations =
                  lib.hm.dag.entryAfter ["writeBoundary"] ''
                    HELIX_APP="$HOME/Applications/Helix.app"
                    rm -rf "$HELIX_APP"
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
