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
# `sudo` to make it, and this image has no sudo.
#
# nix.conf is written BEFORE the install, with build-users-group deliberately
# empty. The installer otherwise leaves the multi-user default of `nixbld`, and
# the very first build then fails with "the group 'nixbld' does not exist" —
# there are no build users in a single-user container, so builds run as root.
#
# The installer's "installing Nix as root is not supported" warning is expected
# and harmless here: root is the only user and there is no daemon.
# uid 1000 to match pahenn on mfcdev. /work is a bind mount of that user's
# directory, and a file's owner is the euid of whoever created it — so a root
# container makes files the VS Code server cannot write. Matching the number is
# the only fix at the source; the name is for legibility, nothing reads it.
RUN useradd --uid 1000 --create-home --shell /bin/bash pahenn
ENV HOME=/home/pahenn

# /nix is chowned to pahenn BEFORE the installer populates it. A chown -R after
# the fact would rewrite 2.2 GB of store into a new layer; setting ownership on
# an empty directory costs nothing and everything created inside inherits it.
RUN mkdir -m 0755 /nix && chown pahenn /nix \
 && mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\nsandbox = false\nbuild-users-group =\n' > /etc/nix/nix.conf \
 && curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install.sh \
 && runuser -u pahenn -- sh /tmp/nix-install.sh --no-daemon --yes \
 && rm /tmp/nix-install.sh

# The installer puts the profile in the home directory, which a named volume
# masks at runtime.
# Pin it somewhere the volume cannot hide so the entrypoint can always find nix.
RUN ln -s "$(readlink -f /home/pahenn/.nix-profile)" /opt/nix-profile

# Bake the activation package into the image so starting the container needs no
# network. Deploy a commit, never a branch — a mutable ref is cached for an hour
# and will silently build a stale revision.
ARG NIXCONFIG_REV=main
# Call nix by absolute path rather than sourcing its profile script: that script
# derives PATH from $HOME/.nix-profile, which does not resolve reliably during a
# docker build, and the first attempt silently produced no output because of it.
#
# No pipe, and `test -s` afterwards. The first attempt piped through `tail -1`,
# so the pipeline's exit status was tail's — nix failed, the file was written
# empty, the build "succeeded", and the image shipped with nothing baked in.
# An empty generation must fail the build, not become a broken container.
RUN runuser -u pahenn -- /opt/nix-profile/bin/nix \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      build --no-link --print-out-paths \
      "github:pahenn/nix-config/${NIXCONFIG_REV}#homeConfigurations.\"pahenn@mfc-work\".activationPackage" \
      > /etc/mfc-work-generation \
 && test -s /etc/mfc-work-generation \
 && echo "baked generation: $(cat /etc/mfc-work-generation)"

# `docker exec` uses the image's ENV, not anything the entrypoint exports — so
# without this, `docker exec mfc-work bash` gets a PATH with none of the flake's
# tools on it even though they are installed and working. Both profile paths live
# in the /home/pahenn volume and are created by activation at first start; a PATH entry
# that does not exist yet is harmless.
ENV PATH=/home/pahenn/.nix-profile/bin:/home/pahenn/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
