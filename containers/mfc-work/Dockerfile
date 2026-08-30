# mfc-work — the workspace container on mfcdev.
#
# Deployed to /opt/mfc-vpn/ alongside docker-compose.yml; kept here so it is
# version controlled with the flake it consumes.
#
# Debian base on purpose, NOT a dockerTools image. Claude Code ships a prebuilt,
# dynamically linked binary and expects a normal glibc filesystem layout; a pure
# Nix image has no FHS and would need nix-ld or an FHS wrapper to run it. The
# apt layer therefore exists only to be a conventional Linux, and everything
# that makes this a workspace comes from the flake — the same modules/home
# config as devbox and the mfcdev host, from one source of truth.
FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive

# Only what Nix needs in order to install, plus what a glibc distro is expected
# to have. node, psql, git, tmux, ripgrep, jq and Claude Code all come from the
# flake now and were dropped from here.
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      ca-certificates curl xz-utils procps iproute2 dnsutils \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Single-user Nix: there is no systemd in this container, so there is no daemon.
# The build sandbox is off because Docker does not reliably grant the user
# namespaces it needs — nothing is built here, it all comes from the cache.
# /nix is created here rather than by the installer: the installer shells out to
# `sudo` to make it, and this image has no sudo. It also warns that installing as
# root is unsupported — that warning is expected and harmless in a container,
# where root is the only user and there is no daemon to run as anyone else.
RUN mkdir -m 0755 /nix && chown root /nix \
 && curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install.sh \
 && sh /tmp/nix-install.sh --no-daemon --yes \
 && rm /tmp/nix-install.sh \
 && mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\nsandbox = false\n' > /etc/nix/nix.conf

# The installer puts the profile in /root, which a named volume masks at runtime.
# Pin it somewhere the volume cannot hide so the entrypoint can always find nix.
RUN ln -s "$(readlink -f /root/.nix-profile)" /opt/nix-profile

# Bake the activation package into the image so starting the container needs no
# network. Deploy a commit, never a branch — a mutable ref is cached for an hour
# and will silently build a stale revision.
ARG NIXCONFIG_REV=main
RUN . /opt/nix-profile/etc/profile.d/nix.sh \
 && nix build --no-link --print-out-paths \
      "github:pahenn/nix-config/${NIXCONFIG_REV}#homeConfigurations.\"root@mfc-work\".activationPackage" \
      | tail -1 > /etc/mfc-work-generation \
 && echo "baked generation: $(cat /etc/mfc-work-generation)"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
