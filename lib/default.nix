# Constructors for every machine in this repo.
#
# Each takes a single host module. Package lists are deliberately *not* threaded
# through function arguments: the module system already merges `homebrew.brews`,
# `environment.systemPackages` and friends across modules, so a host file adds to
# them by setting them directly. That is why there is no `extraBrews` any more.
{ inputs, self }:

let
  inherit (inputs) nixpkgs nix-darwin home-manager nix-homebrew;
in
{
  mkDarwin = hostModule: nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs self; };
    modules = [
      ../modules/darwin
      nix-homebrew.darwinModules.nix-homebrew
      hostModule
    ];
  };

  mkHome = { system, hostModule }: home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.${system};
    extraSpecialArgs = { inherit inputs; };
    modules = [
      ../modules/home
      hostModule
    ];
  };
}
