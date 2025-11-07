# ~/.config/nix/flake.nix

{
  description = "pahenn nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, homebrew-core, homebrew-cask}:
  let
    # Helper function to create a Darwin configuration with a specific user
    mkDarwinConfig = { user, autoMigrate ? false, mutableTaps ? true }: nix-darwin.lib.darwinSystem {
      modules = [
        ({ config, pkgs, ... }: {
          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility. please read the changelog
          # before changing: `darwin-rebuild changelog`.
          system.stateVersion = 6;

          # Automatically set primary user from configuration
          system.primaryUser = user;

          # Create /etc/zshrc that loads the nix-darwin environment.
          # programs.zsh.enable = true;

          environment.systemPackages = [
            pkgs.utm
          ];

          homebrew = {
            enable = true;
            global.autoUpdate = true;
            casks = [
              "ghostty"
              "tailscale"
              "orbstack"
              "brave-browser"
            ];
          };

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        })

        # Homebrew configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = user;
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
            inherit autoMigrate mutableTaps;
          };
        }
      ];
    };
  in
  {
    darwinConfigurations."pahenn-macbook-pro" = mkDarwinConfig {
      user = "pahenn";
      autoMigrate = true;
    };

    darwinConfigurations."mini" = mkDarwinConfig {
      user = "home";
      mutableTaps = false;
    };
  };
}