#!/usr/bin/env bash
# Bootstrap a Debian dev box (devbox, mfcdev) to the point where
# `home-manager switch` works. Safe to re-run.
#
# These boxes are LXC containers on lab1. Verified on devbox: unprivileged user
# namespaces work and systemd is present, so the standard multi-user install is
# fine and the build sandbox can stay on.
set -euo pipefail

CONFIG="${1:-}"
if [ -z "$CONFIG" ]; then
  echo "usage: $0 <pahenn@devbox|pahenn@mfcdev>" >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix (multi-user)"
  sh <(curl -L https://nixos.org/nix/install) --daemon
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo "==> Nix already installed"
fi

echo "==> Enabling flakes for this user"
mkdir -p ~/.config/nix
grep -q 'experimental-features' ~/.config/nix/nix.conf 2>/dev/null \
  || echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

echo "==> First activation"
# home-manager is not on PATH until it has run once.
nix run home-manager/master -- switch --flake "$HOME/nix-config#${CONFIG}" -b hm-bak

cat <<'EOF'

==> Done.

Subsequent updates:
  cd ~/nix-config && git pull && home-manager switch --flake .#<config>

The tmux auto-attach now comes from modules/home/linux-dev.nix. Remove the
hand-written block from ~/.bashrc if one is still there, or the session will be
started twice.
EOF
