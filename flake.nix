{
  description = "pahenn nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-omlx = {
      url = "github:jundot/omlx";
      flake = false;
    };

    homebrew-coolify-cli = {
      url = "github:coollabsio/homebrew-coolify-cli";
      flake = false;
    };

    homebrew-egoist = {
      url = "github:egoist/homebrew-tap";
      flake = false;
    };
  };

  outputs = inputs@{ self, ... }:
  let
    mk = import ./lib { inherit inputs self; };
  in
  {
    # macOS — sudo darwin-rebuild switch --flake .#<name>
    darwinConfigurations = {
      "pahenn-macbook" = mk.mkDarwin {
        user = "pahenn";
        hostModule = ./hosts/pahenn-macbook.nix;
      };

      "home-mini" = mk.mkDarwin {
        user = "pahenn";
        hostModule = ./hosts/home-mini.nix;
      };
    };

    # Linux — home-manager switch --flake .#<name>
    homeConfigurations = {
      "pahenn@devbox" = mk.mkHome {
        system = "x86_64-linux";
        user = "pahenn";
        hostModule = ./hosts/devbox.nix;
      };

      "pahenn@mfcdev" = mk.mkHome {
        system = "x86_64-linux";
        user = "pahenn";
        hostModule = ./hosts/mfcdev.nix;
      };

      # The workspace container on mfcdev. Runs as uid 1000, matching pahenn on
      # the host: /work is a bind mount of /home/pahenn/mfc, and a container
      # running as root creates files there that the VS Code server - which runs
      # as that user - can read and not write. Ownership is the euid of whoever
      # creates the file, so the only fix at the source is being the same user.
      "pahenn@mfc-work" = mk.mkHome {
        system = "x86_64-linux";
        user = "pahenn";
        homeDirectory = "/home/pahenn";
        hostModule = ./hosts/mfc-work.nix;
      };
    };
  };
}
