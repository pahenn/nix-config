# User environment shared by every machine, Mac and Linux alike.
{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
    ./ssh.nix
    ./claude-code.nix
  ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    neovim
    cloudflared
    nanorc
  ];

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
