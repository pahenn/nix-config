# User environment shared by every machine, Mac and Linux alike.
{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
    ./ssh.nix
    ./claude-code.nix
    ./nano.nix
  ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    neovim
    cloudflared
    nanorc
    # Moved here 2026-11-09 from homebrew.brews (Mac) and linux-dev.nix (Linux),
    # so every machine runs the same gh from the same pin. On the Mac it came
    # from /opt/homebrew/bin, which only reaches PATH through `brew shellenv` in
    # the unmanaged ~/.zprofile - so a non-login shell never saw it.
    gh
  ];

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
