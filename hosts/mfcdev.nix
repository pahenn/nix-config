# mfcdev — CT 119 on lab1, 10.73.42.156. Same build as devbox, plus Docker.
#
# This manages the *host* shell only. The real workspace is the `mfc-work`
# container, which shares a network namespace with a Tailscale container holding
# the employer tailnet — that isolation is the whole design, and pulling it into
# home-manager would mean putting the employer tailnet on the host, which is
# exactly what was rejected. The container stays a Dockerfile.
{ ... }:
{
  imports = [ ../modules/home/linux-dev.nix ];

  # The `work` session is a plain HOST shell, and `dev` steps into the container.
  #
  # It used to exec straight into `docker exec -it mfc-work bash`, which made the
  # session's only process the container's. That tied the tmux session's life to
  # the container's: every rebuild killed it, taking whatever was running inside
  # with it — including a Claude Code session, more than once on 2026-08-31. From
  # the phone it looked like tmux was broken rather than absent.
  #
  # A host shell survives all of that. You reconnect to the same session and type
  # `dev` again, which is one keystroke against a session that outlives the thing
  # it is used to reach.
  programs.bash.initExtra = ''
    # Enter the workspace container — where the employer exit node applies.
    # `docker start` first, so a merely stopped container needs no thought; a
    # container that has been removed needs compose, and says so rather than
    # failing with docker's own less obvious message.
    # `dev` lands in tech-kit; `dev vnext` in any other repo under projects/mfc.
    # Defaulting to a directory rather than the container's home because the
    # point of going in there is the repos, and tech-kit is the one holding the
    # scripts you reach for first.
    dev() {
      local repo="''${1:-tech-kit}"
      local dir="/work/projects/mfc/$repo"

      docker start mfc-work >/dev/null 2>&1
      if ! docker ps --format '{{.Names}}' | grep -qx mfc-work; then
        echo "mfc-work is not running. Recreate it with:" >&2
        echo "  cd /opt/mfc-vpn && sudo docker compose up -d work" >&2
        return 1
      fi

      # Warn, never block: a logged-out employer node costs the VPC route only,
      # and the workspace is still worth entering. Silent when all is well.
      # The script lives on the box, not here: it prints the employer's
      # control-server URL, which must not appear in a public flake.
      [ -x /usr/local/bin/mfc-vpn-check ] && /usr/local/bin/mfc-vpn-check

      # Fall back rather than fail: a typo or an uncloned repo should still put
      # you in the container, where `ls /work/projects/mfc` answers the question.
      if ! docker exec mfc-work test -d "$dir" 2>/dev/null; then
        echo "no such repo: $repo — starting in /work/projects/mfc" >&2
        dir=/work/projects/mfc
      fi

      docker exec -it -w "$dir" mfc-work bash
    }
  '';

  # The employer Headscale expires this node every 7 days, and on 2026-09-05 it
  # did so silently: the workspace went a month without network before anyone
  # noticed. The status bar is on screen the moment `ssh mfcdev` attaches, so
  # the warning lives there. Empty while logged in with more than 48h left; a
  # red LOGIN when the node needs approving, and hours left when it is close.
  programs.tmux.extraConfig = ''
    set -g status-right-length 60
    set -g status-right "#([ -x /usr/local/bin/mfc-vpn-check ] && /usr/local/bin/mfc-vpn-check --tmux)\"#{=21:pane_title}\" %H:%M %d-%b-%y"
  '';
}
