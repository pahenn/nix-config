# Constructors for every machine in this repo.
#
# Package lists are deliberately *not* threaded through function arguments: the
# module system already merges `homebrew.brews`, `environment.systemPackages` and
# friends across modules, so a host file adds to them by setting them directly.
# That is why there is no `extraBrews` any more.
#
# `user` is a real argument rather than being read back out of
# `config.system.primaryUser`, because home-manager keys its per-user config by
# attribute name and reading config in a key position invites infinite recursion.
{ inputs, self }:

let
  inherit (inputs) nixpkgs nix-darwin home-manager nix-homebrew;
in
{
  mkDarwin = { user, hostModule }: nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs self user; };
    modules = [
      ../modules/darwin
      nix-homebrew.darwinModules.nix-homebrew
      home-manager.darwinModules.home-manager
      hostModule
    ];
  };

  mkHome = { system, user, homeDirectory ? "/home/${user}", hostModule }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ../modules/home
        { home.username = user; home.homeDirectory = homeDirectory; }
        hostModule
      ];
    };
}
