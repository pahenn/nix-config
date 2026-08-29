# Linux-only user environment. On the Macs nix-darwin owns nix.conf and the
# fonts, so none of this applies there.
{ pkgs, ... }:
{
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home.packages = with pkgs; [
    zsh

    # fonts
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  fonts.fontconfig.enable = true;
}
