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
    configuration = { config, pkgs, ... }: {

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility. please read the changelog
        # before changing: `darwin-rebuild changelog`.
        system.stateVersion = 6;
        system.primaryUser = "home";

        # Create /etc/zshrc that loads the nix-darwin environment.
        # programs.zsh.enable = true;

        environment.systemPackages = [
          
        ];

        homebrew = {
          enable = true;
          global.autoUpdate = true;
          casks = [
            "ghostty"
            # or with args: { name = "firefox"; args = { appdir = "/Applications"; }; }
          ];
        };

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # darwinConfigurations."pahenn-macbook-pro" = nix-darwin.lib.darwinSystem {
    darwinConfigurations."mini" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration

        # ## BEGIN: Existing homebrew install ##
        # nix-homebrew.darwinModules.nix-homebrew
        # {
        #   nix-homebrew = {
        #     # Install Homebrew under the default prefix
        #     enable = true;

        #     # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
        #     # enableRosetta = true;

        #     # User owning the Homebrew prefix
        #     user = "pahenn";

        #     # Optional: Declarative tap management
        #     taps = {
        #       "homebrew/homebrew-core" = homebrew-core;
        #       "homebrew/homebrew-cask" = homebrew-cask;
        #     };

        #     # Automatically migrate existing Homebrew installations
        #     autoMigrate = true;
        #   };
        # }
        # ## END: Existing homebrew install ##


        # ## BEGIN: No existing homebrew install ##
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            # enableRosetta = true;

            # User owning the Homebrew prefix
            user = "home";


            # Optional: Declarative tap management
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };



              # Optional: Enable fully-declarative tap management
              #
              # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
              mutableTaps = false;
          };
        }
        # ## END: No existing homebrew install ##
      ];
    };
  };
}