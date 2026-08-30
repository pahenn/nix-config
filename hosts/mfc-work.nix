# The mfc-work container on mfcdev — the workspace that shares a network
# namespace with the Tailscale container, so everything in it egresses through
# the employer exit node.
#
# This is the *same* module the hosts use, so the container gets the same shell,
# the same tools and the same Claude Code from one source of truth. It runs as
# root, and /root is a Docker named volume, so activation happens at container
# start rather than image build — build-time dotfiles would be masked by the
# volume mounting over them.
{ pkgs, ... }:
{
  imports = [ ../modules/home/linux-dev.nix ];

  # Entered with `docker exec -it mfc-work bash` from a tmux pane on the host.
  # A second tmux in here would nest for no reason.
  devBox.tmuxOnLogin = false;

  home.packages = [
    # The reason this container exists: the targets are RDS instances, and psql
    # needs the exit node's route. Replaces Debian's postgresql-client so the
    # version is pinned by the flake like everything else.
    pkgs.postgresql_17
  ];
}
