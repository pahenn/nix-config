# The remote agent boxes — devbox and mfcdev. Debian 13 LXC on lab1, reached
# through the subnet router, no Tailscale of their own.
#
# These boxes are deliberately disposable and are not in the sanoid policy, so
# being rebuildable from this file is the whole point: "disposable" is only true
# if the box can be recreated.
{ config, lib, pkgs, ... }:

let
  cfg = config.devBox;

  # Publish the connected client's forwarded agent at one stable path.
  #
  # Why a relay rather than `RemoteForward` straight to that path: the container
  # on mfcdev bind-mounts the *directory*, so the socket has to physically live
  # in it - a symlink to sshd's own /tmp socket is broken inside the container's
  # mount namespace. And Blink on iOS cannot RemoteForward to a unix socket at
  # all: its config parser types the value as <port>:<host>:<port> with UInt16
  # ports and no path branch, and no streamlocal request exists in its SSH
  # implementation. Plain ForwardAgent is the only thing both clients can do.
  #
  # It also fixes what RemoteForward got wrong. With a fixed bind path every
  # connection unlinked the previous socket and removed it on exit, so a second
  # live session was left holding a forward nothing could reach - which silently
  # broke 19 repo clones on 2026-08-30. Here each session keeps its own socket
  # and only the relay moves, so a disconnect can never destroy someone else's.
  agentRelay = pkgs.writeShellScriptBin "agent-relay" ''
    set -u
    RELAY="$HOME/agent/agent.sock"
    PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/agent-relay.$(id -u).pid"

    # "Alive" means the socket answers AND holds at least one key - exit 0.
    #
    # Not 0-or-1. `ssh-add -l` exits 1 both for a reachable agent holding no
    # identities and for "communication with agent failed", which is exactly
    # what a relay whose upstream has died returns: socat still accepts the
    # connection, then finds nothing on the other side. Treating 1 as alive
    # made the self-heal a no-op against the one failure it exists to repair,
    # confirmed by test on 2026-08-30. Exit 2 is a missing socket file.
    #
    # A key-less agent is useless here anyway - there is nothing on these boxes
    # to authenticate with - so demanding a key loses nothing and is the only
    # check that distinguishes the states that matter.
    alive() {
      SSH_AUTH_SOCK="$1" ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1
    }

    # Find any forwarded agent on this box that answers, newest first, and
    # prefer one whose session has a tty.
    #
    # This exists because trusting $SSH_AUTH_SOCK made the self-heal
    # unreachable in the one case it was written for. On 2026-08-30 both dev
    # boxes sat with a dead relay while a live forwarded agent holding the key
    # was on the same box the whole time. Opening a shell did not fix it: that
    # login had no SSH_AUTH_SOCK of its own, so the first guard returned before
    # the repair, and the fallback below then pointed that very shell at the
    # corpse. The session that arrived able to fix it became another victim.
    #
    # @pts before @notty because a one-shot `ssh host cmd` exits in seconds and
    # relaying to it replaces a stale relay with a stale relay - the failure
    # this file's own header warns about. A tty means a person is sitting
    # there, which is the best proxy available for "will still exist shortly".
    # /proc/PID/cmdline reads `sshd-session: user@pts/3` or `user@notty`, so
    # this needs nothing installed.
    scan() {
      local pass s pid args
      for pass in tty any; do
        for s in $(ls -t /tmp/ssh-*/agent.* 2>/dev/null); do
          [ -S "$s" ] || continue
          [ "$s" = "$RELAY" ] && continue
          pid="''${s##*/agent.}"
          case "$pid" in ""|*[!0-9]*) continue ;; esac
          # owning session gone: its socket is a corpse like the one we replace
          kill -0 "$pid" 2>/dev/null || continue
          args="$(tr "\0" " " < "/proc/$pid/cmdline" 2>/dev/null)"
          if [ "$pass" = tty ]; then
            case "$args" in *@pts*) ;; *) continue ;; esac
          fi
          alive "$s" || continue
          printf "%s" "$s"
          return 0
        done
      done
      return 1
    }

    # This session's own agent first - it is the one certain to be live and to
    # belong to whoever is asking. Never the relay itself: that would loop.
    UPSTREAM="''${SSH_AUTH_SOCK:-}"
    [ "$UPSTREAM" = "$RELAY" ] && UPSTREAM=""
    if [ -z "$UPSTREAM" ] || ! alive "$UPSTREAM"; then
      UPSTREAM="$(scan || true)"
    fi
    # Genuinely nobody attached. Leave whatever is published alone - a mosh
    # session, which cannot forward at all, keeps borrowing a live relay.
    [ -n "$UPSTREAM" ] || exit 0

    # If something live is already published, leave it alone. First client in
    # owns the path; later ones use their own forwarded socket directly and
    # never notice. Taking it over would gain nothing and churn the container.
    #
    # This is also the self-heal. When the owner disconnects its socat is left
    # relaying to a dead upstream: the listen still accepts, then closes
    # immediately, so `ssh-add -l` reports it as unreachable and the next
    # interactive shell on the box republishes. That is why this runs from
    # every interactive shell and not only at login - a stale relay is repaired
    # by opening a pane rather than by knowing to reconnect.
    if alive "$RELAY"; then exit 0; fi

    mkdir -p "$(dirname "$RELAY")"
    if [ -f "$PIDFILE" ]; then kill "$(cat "$PIDFILE")" 2>/dev/null || true; fi
    ${pkgs.socat}/bin/socat \
      UNIX-LISTEN:"$RELAY",fork,mode=600,unlink-early \
      UNIX-CONNECT:"$UPSTREAM" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
  '';
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

  options.devBox.agentSocket = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "$HOME/agent/agent.sock";
    description = ''
      Where the Mac's forwarded SSH agent socket lands on this box.

      These boxes deliberately hold no private keys — see tools/deploy-linux.sh —
      so git over SSH authenticates with the Vaultwarden agent on the Mac,
      forwarded here by a RemoteForward in the Mac's ~/.ssh/config.

      The path is fixed rather than the random /tmp one ForwardAgent would give,
      because the long-lived tmux session outlives any single login: a pane
      opened yesterday still holds yesterday's SSH_AUTH_SOCK, and only a stable
      path makes that value still true after reconnecting. mfc-work needs it
      stable for a second reason — the directory is bind-mounted into the
      container, and a mount cannot chase a path that changes every login.

      null on mfc-work: the socket arrives there through the bind mount at
      /agent, and compose sets SSH_AUTH_SOCK, because `docker exec` reads the
      container's env and never sources ~/.profile.
    '';
  };

  config = {
    # Debian's stock ~/.profile put this on PATH conditionally; home-manager's
    # generated one does not, and losing it would make `pip install --user` and
    # anything else that installs there silently unreachable.
    home.sessionPath = [ "$HOME/.local/bin" ];

    home.packages = (lib.optionals (cfg.agentSocket != null) [
      agentRelay
      pkgs.socat
    ]) ++ (with pkgs; [
      ripgrep
      jq
      fd
      tree
      htop
      mosh
      nodejs_22
      python3
      gnumake

      # Added to the shared list 2026-08-30. These arrived for tech-kit's
      # bootstrap and were declared in hosts/mfc-work.nix, so they landed in the
      # container and nowhere else - `gh` missing on devbox is what surfaced it.
      # Nothing about them is employer-specific, and these boxes are supposed to
      # be the same box twice, so the narrow scoping was the mistake.
      pnpm
      uv
      gh
    ]);

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

    # SSH client configuration, managed here so a rebuilt box behaves the same.
    #
    # Two files on purpose. New hosts still append to ~/.ssh/known_hosts — the
    # first file listed is the one ssh writes to — while the flake-pinned file
    # stays read-only and keeps github.com and Forgejo verifiable on a box that
    # was rebuilt an hour ago. Without it the first clone stops at a yes/no
    # prompt, which a person answers and an agent hangs on forever.
    #
    # Keys taken from `ssh-keyscan`, cross-checked against the ssh_keys field of
    # https://api.github.com/meta. Forgejo serves RSA only — it is Go's SSH
    # server, not OpenSSH, and offers no ed25519 host key.
    home.file = {
      ".ssh/config".text = ''
        # Managed by nix-config (modules/home/linux-dev.nix).
        # Edits here are silently replaced on the next activation.

        # **This repository is public.** Anything host- or employer-specific -
        # a CodeCommit SSH key id, an internal hostname - must not be written
        # here. Drop it in ~/.ssh/config.d/ on the box instead, which is
        # outside git for the same reason ~/.secrets.zsh is. First match wins
        # in ssh_config, so the include goes at the top and local entries
        # override anything below. A glob that matches nothing is not an error.
        Include ~/.ssh/config.d/*.conf

        UserKnownHostsFile ~/.ssh/known_hosts ~/.ssh/known_hosts_flake
      '';

      # The include above needs somewhere to point.
      ".ssh/config.d/.keep".text = "";

      ".ssh/known_hosts_flake".text = ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        [10.73.42.192]:2222 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQnSSVJ1eC7xXKe1fslbjLl3rRptrBEnv7/VojESqtxoiBmohIPsApq0uk9PYbPlh9NCxEQW7DV96IK8GRUyuqXAF7FMYCsO1RZFAmIodCDBukIhlT13cSwXFhnpsJnpYGFGrdNki+AagRcTAa0T4ruwgiSZs+MQHmUo/tjCKPxIOAj2VBSr6M4wUalk3dQdPCYzH9AWVFdGZK3TixOBz+cEfhdrPJGTgc8q2ENskeSzkjrkpkWqont4SWHPNWUpwW7X6V4zeBalhG9pY4Y2XL/b8BbqPxSsNK78Tn7Bx54BLhGy8J9nJbsoLga+AXNgrnlOm70cr0TJrXXeqTFxxZGjHapUq/6HbF8ijS12JztedIFOqUCsoZks5ZQgLUujiTCi0c7xubQxrZNW5nchCE7j/JTD6fZR19NQn4mdanJGbhtwA7pLkMQ7yE9hIvo0QiUNaHhjDn2gUL4skugeqvRWgItVSRo3hVvxNwbZA/wnwUOuctXFztEOPU4EFdBMUSKR2N4yw2CKKiDwqVLq1wvFeLdriAH2UO0NJprb4p+HHmdjRIpcIGTwqdpw1G+22Fgeq5hOu7iTwg7lZ5KZG+xuFmpgSklDiR/zNmqcBTyvSwGeGeVCgfWLD2teP+a5QKt78XVq29iB4F2R4ToQ5++pliy4tC5h/TrStFHnxmIQ==
      '';
    } // lib.optionalAttrs (cfg.agentSocket != null) {
      # sshd binds the forwarded socket here but will not create the directory,
      # and a missing parent is a silent failure: the login succeeds, the
      # forward does not, and the first clue is "Permission denied (publickey)".
      "agent/.keep".text = "";
    };

    # Points at the socket above. Harmless when nothing is connected — ssh finds
    # no agent and, since there are no keys on disk either, simply fails to
    # authenticate rather than doing something surprising.
    home.sessionVariables = lib.mkIf (cfg.agentSocket != null) {
      SSH_AUTH_SOCK = cfg.agentSocket;
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
        # Re-assert the flake's PATH entries on every interactive shell.
        #
        # home.sessionPath alone is not enough. A tmux pane is a *login* shell,
        # so it re-runs /etc/profile, which resets PATH — and then both
        # /etc/profile.d/nix.sh and hm-session-vars.sh return early, because
        # their "already sourced" guards are exported variables the tmux server
        # inherited from the first login. The pane comes up with the stock
        # Debian PATH and not one flake-installed tool on it.
        #
        # That is not theoretical: on 2026-08-30 devbox's tmux pane, created
        # before that day's deploy, had PATH=/usr/local/bin:/usr/bin:/bin:...
        # and nothing else. Claude Code looked uninstalled while
        # ~/.local/bin/claude was sitting right there, and rg, fd, jq and node
        # were invisible the same way.
        #
        # .bashrc runs for every interactive shell and no guard gates it, so
        # this is the one place the correction always lands. Listed
        # lowest-priority first: each is prepended, so the last one ends up in
        # front.
        for __d in /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin" "$HOME/.local/bin"; do
          case ":$PATH:" in
            *":$__d:"*) ;;
            *) PATH="$__d:$PATH" ;;
          esac
        done
        unset __d
        export PATH
      '' + lib.optionalString (cfg.agentSocket != null) ''

        # Publish this session's forwarded agent at the stable path, if nothing
        # live is published there already. Deliberately not restricted to the
        # login shell: a relay whose owner disconnected is repaired by whoever
        # next opens a pane, which is the only repair path that does not require
        # noticing the problem first. It is a no-op - one socket probe - when
        # the relay is healthy.
        agent-relay

        # Then point at it. `:=` only fills a blank, so a session that forwarded
        # its own agent keeps using that directly and never goes via the relay;
        # this is what a pane older than the current login falls back to, and
        # what a mosh session - which cannot forward at all - relies on.
        : "''${SSH_AUTH_SOCK:=${cfg.agentSocket}}"
        export SSH_AUTH_SOCK
      '' + lib.optionalString cfg.tmuxOnLogin ''

        if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ] && command -v tmux >/dev/null; then
        ${cfg.tmuxCommand}
        fi
      '';
    };
  };
}
