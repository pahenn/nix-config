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

  options.devBox.installClaudeCode = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install Claude Code from Anthropic's official installer on activation.

      Deliberately imperative. nixpkgs lags the official releases, and on an
      agent box a stale agent is worse than an unmanaged one — so this runs the
      vendor installer rather than pinning a package.
    '';
  };

  options.devBox.tmuxOnLogin = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Exec into the shared tmux session on interactive SSH login.

      Off inside the mfc-work container: that is entered with `docker exec` from
      a tmux pane on the host, so a second tmux inside would nest for no reason.
    '';
  };

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

    # Claude Code, from the vendor installer rather than nixpkgs.
    #
    # This activation script MUST NOT be able to fail. home-manager runs
    # activation under `set -eu` with `pipefail`, so a non-zero exit here aborts
    # every later step — which is exactly how a failed Homebrew cask left the
    # Mac half-configured on 2026-08-29. Hence the `|| echo` on the install and
    # the check-then-skip rather than an unconditional run.
    home.activation.claudeCode =
      lib.mkIf cfg.installClaudeCode (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -x "$HOME/.local/bin/claude" ]; then
          echo "claude-code: present at ~/.local/bin/claude, leaving alone"
        else
          echo "claude-code: installing from https://claude.ai/install.sh"
          # Both the pipe target and the installer's own PATH must be explicit.
          # home-manager's activation PATH is minimal, so letting `| bash`
          # resolve from it is what made the first attempt fail while the same
          # command succeeded by hand.
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c \
            'export PATH="${lib.makeBinPath [
                pkgs.curl pkgs.bash pkgs.coreutils pkgs.gnutar pkgs.gzip
                pkgs.gnugrep pkgs.gnused pkgs.which
              ]}:$PATH"; \
             curl -fsSL https://claude.ai/install.sh | bash' \
            || echo "claude-code: install FAILED — continuing activation" >&2
        fi
      '');

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
      initExtra = lib.mkIf cfg.tmuxOnLogin ''
        if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ] && command -v tmux >/dev/null; then
        ${cfg.tmuxCommand}
        fi
      '';
    };
  };
}
