# nano and its syntax colouring, on every machine.
#
# The settings existed only as a hand-written ~/.nanorc on the MacBook, and it
# could not have travelled if it had been copied: it included from
# /opt/homebrew/share/nanorc, a path that exists on no Linux host. So devbox and
# mfcdev had Debian's nano with no colouring, and mfc-work had no nano at all.
#
# Same defect as the Bitwarden cask, the OrbStack init and Claude Code - see the
# note in nix-config.md. The flake already shipped the `nanorc` *definitions* in
# the shared package list, so the colouring was half-declared: the syntax files
# were installed everywhere and nothing told nano to read them.
{ pkgs, ... }:
{
  # Debian supplies /usr/bin/nano on the dev boxes, but the mfc-work container
  # is slimmer and has none, and relying on the base image means the editor
  # differs per host for no reason. Declared, so every machine has the same one.
  home.packages = [ pkgs.nano ];

  home.file.".nanorc".text = ''
    # Managed by nix-config (modules/home/nano.nix).

    set tabsize 4
    set tabstospaces

    # The definitions come from the `nanorc` package in the shared package list.
    # Referenced by store path rather than by a profile path, so this works
    # identically on darwin and Linux and cannot silently point at nothing.
    include "${pkgs.nanorc}/share/*.nanorc"
  '';
}
