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
    darwinConfigurations = {
      "pahenn-macbook" = mk.mkDarwin ./hosts/pahenn-macbook.nix;
      "home-mini" = mk.mkDarwin ./hosts/home-mini.nix;
    };

    homeConfigurations = {
      "ubuntu@ubuntu" = mk.mkHome {
        system = "aarch64-linux";
        hostModule = ./hosts/ubuntu.nix;
      };

      "patrick@patrick-homelab" = mk.mkHome {
        system = "x86_64-linux";
        hostModule = ./hosts/patrick-homelab.nix;
      };
    };
  };
}
