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

exec "$@"
