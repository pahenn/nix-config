#!/usr/bin/env bash
# Deploy a Linux dev box from this flake. Run this FROM the Mac.
#
#   ./tools/deploy-linux.sh devbox
#   ./tools/deploy-linux.sh mfcdev
#
# Idempotent: installs Nix only if absent, and is the same command for the first
# deploy and every update after.
#
# Why it drives everything over ssh instead of running on the box: devbox and
# mfcdev deliberately hold no private keys, so they cannot clone from GitHub or
# Forgejo. The repo is public, so they fetch the flake by URL and need no
# credentials at all. Nothing is cloned onto the box.
set -euo pipefail

HOST="${1:-}"
if [ -z "$HOST" ]; then
  echo "usage: $0 <devbox|mfcdev>" >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLAKE_REPO="github:pahenn/nix-config"
CONFIG="pahenn@${HOST}"
NIX=/nix/var/nix/profiles/default/bin/nix
FLAGS="--extra-experimental-features nix-command --extra-experimental-features flakes"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Deploy an exact commit, never a branch name.
#
# `github:owner/repo` is mutable, and nix caches the resolved tarball for an hour
# (tarball-ttl). A deploy that looks successful can therefore build a *previous*
# revision: that happened here, and mfcdev silently kept an older generation
# while the script reported success. A commit-pinned ref is immutable, so it is
# never stale and every deploy is auditable.
SHA="$(git -C "$REPO" rev-parse HEAD)"

if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
  echo "warning: working tree is dirty — the box deploys $SHA from GitHub, not from disk" >&2
fi
if ! git -C "$REPO" branch -r --contains "$SHA" 2>/dev/null | grep -q 'origin/'; then
  echo "error: $SHA is not on any origin branch. Push before deploying." >&2
  exit 1
fi

FLAKE="${FLAKE_REPO}/${SHA}"
echo "deploying $SHA"

say "$HOST: checking reachability"
ssh -o ConnectTimeout=8 -o BatchMode=yes "$HOST" 'echo "  reachable as $(whoami)"'

say "$HOST: ensuring Nix is installed"
# NOTE: do not wrap remote commands in `bash -lc`. The SSH environment already
# exports __ETC_PROFILE_NIX_SOURCED, so a login shell re-runs /etc/profile —
# which *resets* PATH — and then /etc/profile.d/nix.sh returns early without
# re-adding Nix. `ssh host 'bash -s'` with an explicit PATH avoids the trap.
ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
  echo "  already installed: $(/nix/var/nix/profiles/default/bin/nix --version)"
else
  echo "  installing Nix (multi-user)..."
  curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install.sh
  sh /tmp/nix-install.sh --daemon --yes >/tmp/nix-install.log 2>&1
  rm -f /tmp/nix-install.sh
  echo "  installed: $(/nix/var/nix/profiles/default/bin/nix --version)"
fi
REMOTE

# Build before activating. Evaluation proves the module logic; only a build
# proves the packages resolve. Doing this first leaves the box untouched if it
# fails -- the lesson from the Mac, where a failed activation step left the
# machine half-configured.
say "$HOST: pre-flight build (box untouched if this fails)"
GEN=$(ssh "$HOST" "$NIX $FLAGS build --no-link --print-out-paths '${FLAKE}#homeConfigurations.\"${CONFIG}\".activationPackage'")
echo "  built    $GEN"

# Evaluate the same pinned ref locally and require the two to agree. The Mac
# cannot *build* x86_64-linux, but it can evaluate it, and a mismatch means the
# box resolved something other than what was asked for.
EXPECTED=$(nix $FLAGS eval --raw "${FLAKE}#homeConfigurations.\"${CONFIG}\".activationPackage")
if [ "$GEN" != "$EXPECTED" ]; then
  echo "error: box built $GEN but this commit evaluates to $EXPECTED" >&2
  exit 1
fi
echo "  matches  what $SHA evaluates to locally"

# Activate the package just built, rather than `nix run home-manager/master`, so
# activation uses the home-manager this flake pins instead of whatever is on
# master today.
say "$HOST: activating"
ssh "$HOST" "HOME_MANAGER_BACKUP_EXT=hm-bak '$GEN/activate'"

say "$HOST: verifying"
ssh "$HOST" 'bash -s' <<'REMOTE'
export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
fail=0
for t in rg jq fd tmux mosh node starship git nix; do
  if command -v "$t" >/dev/null; then printf '  %-9s ok\n' "$t"
  else printf '  %-9s MISSING\n' "$t"; fail=1; fi
done
# Automation must never land in tmux: the interactive guard has to come before
# the exec, or `ssh host 'some command'` would hang forever.
if grep -q 'i\* \]\] || return' ~/.bashrc; then
  echo "  bashrc    non-interactive guard present"
else
  echo "  bashrc    NO INTERACTIVE GUARD -- scripted ssh would exec into tmux"; fail=1
fi
echo "  git       $(git config user.email)"
exit $fail
REMOTE

say "$HOST: done"
echo "Interactive login attaches to the 'work' tmux session; Ctrl-b d detaches."
