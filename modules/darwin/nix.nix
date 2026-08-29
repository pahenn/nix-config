# Nix itself: the Lix migration and the settings the daemon needs.
{ pkgs, ... }:
{
  # Migrate to Lix. These four are the packages that need to come from the Lix
  # package set rather than nixpkgs' own.
  nixpkgs.overlays = [
    (final: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena;
    })
  ];

  nix.package = pkgs.lixPackageSets.stable.lix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # The store only ever grew before this. Weekly, keep a month of generations.
  nix.gc = {
    automatic = true;
    interval = { Weekday = 7; Hour = 3; Minute = 0; };
    options = "--delete-older-than 30d";
  };

  # Hard-link identical files in the store.
  nix.optimise.automatic = true;
}
