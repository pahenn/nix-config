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
}
