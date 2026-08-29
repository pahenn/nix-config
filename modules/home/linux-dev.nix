# The remote agent boxes — devbox and mfcdev. Debian 13 LXC on lab1, reached
# through the subnet router, no Tailscale of their own.
#
# These boxes are deliberately disposable and are not in the sanoid policy, so
# being rebuildable from this file is the whole point: "disposable" is only true
# if the box can be recreated.
{ config, lib, pkgs, ... }:

let
  cfg = config.devBox;
in
{
  imports = [ ./linux.nix ];

  options.devBox.tmuxCommand = lib.mkOption {
    type = lib.types.lines;
    default = "exec tmux new-session -A -s work";
    description = ''
      What an interactive SSH login execs into. devbox lands in a plain shell;
      mfcdev overrides this to land inside the mfc-work container, because that
      is where the employer exit node applies.
    '';
  };

  config = {
    # Debian's stock ~/.profile put this on PATH conditionally; home-manager's
    # generated one does not, and losing it would make `pip install --user` and
    # anything else that installs there silently unreachable.
    home.sessionPath = [ "$HOME/.local/bin" ];

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
    # device joins the same shell. What it execs into is per-host — see
    # devBox.tmuxCommand above.
    #
    # `exec` matters: without it the login shell *launches* tmux and waits, so
    # `exit` drops you back into a login shell that looks identical but is not
    # in tmux, and a second `exit` is needed. Replacing the login shell means one
    # `exit` closes everything.
    #
    # The guard below is only half the story. home-manager's generated .bashrc
    # opens with `[[ $- == *i* ]] || return`, and that is what keeps
    # `ssh devbox 'some command'` from execing into tmux and hanging. Automation
    # on these boxes depends on that line staying above this block —
    # tools/deploy-linux.sh asserts it on every deploy.
    programs.bash = {
      enable = true;
      initExtra = ''
        if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ] && command -v tmux >/dev/null; then
        ${cfg.tmuxCommand}
        fi
      '';
    };
  };
}
