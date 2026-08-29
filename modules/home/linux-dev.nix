# The remote agent boxes — devbox and mfcdev. Debian 13 LXC on lab1, reached
# through the subnet router, no Tailscale of their own.
#
# These boxes are deliberately disposable and are not in the sanoid policy, so
# being rebuildable from this file is the whole point: "disposable" is only true
# if the box can be recreated.
{ pkgs, ... }:
{
  imports = [ ./linux.nix ];

  home.packages = with pkgs; [
    ripgrep
    jq
    fd
    tree
    htop
    mosh
    nodejs_22
    python3
    gnumake
  ];

  programs.tmux = {
    enable = true;
    mouse = true;          # pane selection from a tablet is otherwise miserable
    escapeTime = 10;
    historyLimit = 50000;
    terminal = "screen-256color";
  };

  # Log in over SSH and land straight in the one long-lived session, so every
  # device joins the same shell.
  #
  # `exec` matters: without it the login shell *launches* tmux and waits, so
  # `exit` drops you back into a login shell that looks identical but is not in
  # tmux, and a second `exit` is needed. Replacing the login shell means one
  # `exit` closes everything.
  #
  # Debian's .bashrc returns early for non-interactive shells, so
  # `ssh devbox 'some command'` never lands in tmux — which is what automation
  # wants.
  programs.bash = {
    enable = true;
    initExtra = ''
      if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ] && command -v tmux >/dev/null; then
        exec tmux new-session -A -s work
      fi
    '';
  };
}
