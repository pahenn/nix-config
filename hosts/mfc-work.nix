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

  # The forwarded agent socket reaches this container through a bind mount of
  # /home/pahenn/agent at /agent, and compose sets SSH_AUTH_SOCK — `docker exec`
  # reads the container's env and never sources ~/.profile, so the session
  # variable home-manager writes for the hosts would not be seen here anyway.
  devBox.agentSocket = null;

  home.packages = [
    # The reason this container exists: the targets are RDS instances, and psql
    # needs the exit node's route. Replaces Debian's postgresql-client so the
    # version is pinned by the flake like everything else.
    pkgs.postgresql_17

    # tech-kit's bootstrap.sh prereqs. Declared here rather than installed with
    # `npm install -g` or `nix profile install`, because **/nix is in the image
    # layer, not a volume** - only /root, /work and /agent survive. Anything
    # installed into the running container is silently gone at the next
    # `docker compose up -d work`, which is a rebuild away at any time. On the
    # hosts an ad-hoc `nix profile install` persists; in here it does not.
    pkgs.pnpm
    pkgs.uv
    pkgs.gh          # /create-pr; still needs `gh auth login` in the container
    pkgs.awscli2     # CodeCommit clones and AWS resources

    # The Debian base here carries no openssh-client: the image was cut back to
    # ca-certificates, curl, xz-utils, procps, iproute2 and dnsutils when the
    # toolchain moved into this flake, and ssh was never declared to replace it.
    # git shells out to `ssh` for an SSH remote, so `git clone git@github.com:...`
    # failed with "cannot run ssh: No such file or directory" — git was fine, the
    # transport was missing. The hosts get theirs from Debian and are unaffected.
    pkgs.openssh
  ];
}
