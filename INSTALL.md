# Installation

## macOS

### 1. Install Lix

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Restart the shell, or `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.

### 2. Clone this repository

```bash
git clone <repo-url> ~/nix-config
```

The path matters only for convenience — nothing in the flake depends on it any
more. (It used to: `STARSHIP_CONFIG` pointed at `~/nix-config/home/starship/`.)

### 3. First switch

`darwin-rebuild` does not exist yet on a fresh machine, so bootstrap through
`nix run`:

```bash
sudo nix run nix-darwin -- switch --flake ~/nix-config#pahenn-macbook
```

Afterwards:

```bash
sudo darwin-rebuild switch --flake ~/nix-config#pahenn-macbook   # or #home-mini
```

### 4. Clean up what home-manager replaced

The first switch renames `~/.zshrc` and `~/.zshenv` to `*.hm-bak`. One file is
**not** handled automatically:

```bash
mv ~/.gitconfig ~/.gitconfig.pre-nix
```

home-manager writes `~/.config/git/config`, but git reads `~/.gitconfig` *after*
it, so a leftover `~/.gitconfig` silently wins for any key it sets.

`~/.zprofile` is deliberately left alone — it carries `brew shellenv` and the
OrbStack init.

## Linux (devbox, mfcdev)

One command, from the Mac. It installs Nix if absent, builds, activates and
verifies:

```bash
./tools/deploy-linux.sh devbox
./tools/deploy-linux.sh mfcdev
```

It is idempotent — the same command is the first deploy and every update after.

**The boxes hold no private keys**, by design, so they cannot clone from GitHub
or Forgejo. This repo is public, so they fetch the flake by URL and need no
credentials at all; nothing is cloned onto the box. The consequence is that
**they deploy from `origin/main`, not from your working tree** — push first. The
script warns if you have not.

Verified on devbox: unprivileged user namespaces work in the LXC and systemd is
present, so the standard multi-user install is fine with the sandbox left on.

### Two traps this script exists to avoid

**Do not wrap remote commands in `bash -lc`.** The SSH environment already
exports `__ETC_PROFILE_NIX_SOURCED`, so a login shell re-runs `/etc/profile`,
which *resets* `PATH`, and then `/etc/profile.d/nix.sh` returns early without
re-adding Nix. The result is `nix: command not found` on a box where Nix is
installed and working. Use `ssh host 'bash -s'` with an explicit `PATH`.

**Build before activating.** Evaluation proves the module logic; only a build
proves the packages resolve. The script builds first so a failure leaves the box
untouched.

### After the first deploy

`~/.bashrc` and `~/.profile` are backed up to `*.hm-bak`. The hand-written tmux
block is now generated from `modules/home/linux-dev.nix`, so the backup copy can
be discarded once the login has been confirmed.

home-manager's generated `.bashrc` keeps `[[ $- == *i* ]] || return` above the
tmux block, so `ssh devbox 'some command'` still returns normally instead of
execing into tmux. The deploy script asserts this — if that guard ever moved,
every scripted SSH to these boxes would hang.

## Updating

```bash
cd ~/nix-config && git pull
sudo darwin-rebuild switch --flake .#pahenn-macbook      # macOS
home-manager switch --flake .#pahenn@devbox              # Linux
```

To move the pinned inputs forward:

```bash
nix flake update           # everything
nix flake update nixpkgs   # one input
```

Homebrew formulae are *not* upgraded by a switch any more. Take those
deliberately with `brew update && brew upgrade`.

## Troubleshooting

**`darwin-rebuild: command not found`** — restart the terminal, or use the
`nix run nix-darwin` form above.

**An installer wants to append to `~/.zshrc`** — it cannot; the file is a
read-only symlink into the store. Put the line in this flake, or in
`~/.zshrc.local`, which is sourced at the end and stays writable.

**A `switch` wants to uninstall something unexpected** — `cleanup = "uninstall"`
is on, so anything not in `modules/darwin/homebrew.nix` is removed. Check first:

```bash
nix eval --raw .#darwinConfigurations.pahenn-macbook.config.homebrew.brewfile > /tmp/Brewfile
brew bundle cleanup --file=/tmp/Brewfile     # dry run; add --force to apply
```
