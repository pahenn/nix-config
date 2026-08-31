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

  # /work is a bind mount of /home/pahenn/mfc, owned by pahenn (1000). This
  # container runs as root, and git refuses a repository owned by another user
  # — root included, it is not exempt.
  #
  # The files are owned by the human on purpose: the VS Code server on mfcdev
  # runs as pahenn, and without that it can read the repos but not write to
  # them, so the editor silently cannot save. Ownership follows the person who
  # edits; the root container is told to trust it, not the other way round.
  #
  # Declared rather than clicked. VS Code's "allow" button runs
  # `git config --global --add safe.directory`, which writes to
  # ~/.config/git/config — a read-only store symlink on every machine here, so
  # that button can only ever fail. Anything of this shape has to come from the
  # flake.
  #
  # Scoped to /work, not `*`. Git 2.55 treats a trailing /* as recursive, so
  # this covers every repo under the mount and nothing outside it.
  programs.git.settings.safe.directory = "/work/*";

  # CodeCommit over HTTPS, because the SSH route cannot work from here.
  #
  # 12 of the 19 repos in tech-kit's repos.json are on CodeCommit and only 7 on
  # GitHub — which is exactly why 12 of the workspace folders were missing. IAM
  # will not accept an ed25519 key, so the forwarded vault key is refused, and
  # importing an RSA key into the vault does not help either: Bitwarden's agent
  # lists RSA keys and cannot sign with them. Both agent routes are closed
  # upstream. See mfcdev.md.
  #
  # So this is AWS's own recommendation, and it is a real trade: a static
  # credential at rest in the container, which is the thing this estate has
  # otherwise spent effort eliminating. Contained three ways — scoped to the one
  # host rather than a global helper, kept in the root-only /root volume rather
  # than the /work bind mount where the Mac could read it, and an IAM
  # service-specific credential that grants CodeCommit and nothing else.
  #
  # Not in mfc.env: that file is passed to the *vpn* container and carries the
  # Headscale auth key, which the workspace has no reason to see.
  programs.git.settings.credential."https://git-codecommit.us-east-1.amazonaws.com".helper =
    "store --file=/root/.codecommit-credentials";

  home.packages = [
    # The reason this container exists: the targets are RDS instances, and psql
    # needs the exit node's route. Replaces Debian's postgresql-client so the
    # version is pinned by the flake like everything else.
    pkgs.postgresql_17

    # tech-kit's bootstrap wants this for CodeCommit clones and S3. It stays
    # here rather than in the shared module on purpose: devbox is deliberately
    # the box with no path to employer infrastructure, and AWS tooling there
    # invites exactly the drift that separation exists to prevent. pnpm, uv and
    # gh were also declared here at first and have since moved to the shared
    # list - nothing about them is employer-specific.
    #
    # Declared rather than installed by hand because **/nix is in the image
    # layer, not a volume** - only /root, /work and /agent survive. Anything
    # installed into the running container is gone at the next
    # `docker compose up -d work`. On the hosts an ad-hoc `nix profile install`
    # persists; in here it does not.
    pkgs.awscli2

    # The Debian base here carries no openssh-client: the image was cut back to
    # ca-certificates, curl, xz-utils, procps, iproute2 and dnsutils when the
    # toolchain moved into this flake, and ssh was never declared to replace it.
    # git shells out to `ssh` for an SSH remote, so `git clone git@github.com:...`
    # failed with "cannot run ssh: No such file or directory" — git was fine, the
    # transport was missing. The hosts get theirs from Debian and are unaffected.
    pkgs.openssh
  ];
}
