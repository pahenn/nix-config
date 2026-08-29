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

  # Land inside the workspace container, because that is where the employer exit
  # node applies — the host's own routing is deliberately untouched. Ctrl-b c
  # opens a window on the HOST for mfc-on / mfc-off / mfc-status.
  #
  # If the container is down, fall back to a host shell rather than failing the
  # login. Getting locked out of a box because a container is not running would
  # be a poor trade for saving a keystroke.
  devBox.tmuxCommand = ''
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx mfc-work; then
      exec tmux new-session -A -s work 'docker exec -it mfc-work bash'
    else
      exec tmux new-session -A -s work
    fi
  '';
}
