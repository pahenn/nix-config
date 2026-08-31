#!/bin/bash
# Activate the home-manager generation baked into this image, then hand off to
# whatever command compose passed (sleep infinity).
#
# Activation happens here rather than at image build because /root is a Docker
# named volume: anything the build wrote there would be masked the moment the
# volume mounts over it. Doing it at start writes the dotfiles into the volume,
# where they persist across restarts.
#
# This must never stop the container coming up. A failed activation should leave
# a usable shell to debug in, not a crash-looping container — the same reasoning
# as the activation hook that installs Claude Code.
set -u
export HOME=/root
export USER=root
export PATH="/opt/nix-profile/bin:/root/.nix-profile/bin:/root/.local/bin:/usr/local/bin:/usr/bin:/bin"

GEN="$(cat /etc/mfc-work-generation 2>/dev/null || true)"
if [ -n "$GEN" ] && [ -x "$GEN/activate" ]; then
  HOME_MANAGER_BACKUP_EXT=hm-bak "$GEN/activate" \
    || echo "warning: home-manager activation failed; container starting anyway" >&2
else
  echo "warning: no home-manager generation baked into this image" >&2
fi

# Hand /work back to the human who edits it.
#
# /work is a bind mount of /home/pahenn/mfc, owned by uid 1000 on the host. This
# container runs as root, so everything it creates there lands root-owned — and
# the VS Code server on mfcdev runs as that user, so it can read the tree and not
# write it, while git refuses the repos outright for dubious ownership. That is
# not hypothetical: bootstrap.sh cloning 12 repos on 2026-08-31 reproduced it
# within minutes of the previous fix, which is what made a one-off chown clearly
# the wrong shape.
#
# Cheap when there is nothing to do — the uid test is a stat per entry and no
# writes — so this can run on every start rather than being remembered.
#
# Must never stop the container coming up, for the same reason as the activation
# above: a workspace you can debug in beats a crash loop.
if [ -d /work ]; then
  find /work ! -uid 1000 -exec chown 1000:1000 {} + 2>/dev/null \
    || echo "warning: could not normalise ownership under /work" >&2
fi

exec "$@"
