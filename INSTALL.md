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

Debian 13 LXC containers on lab1, reached through the subnet router. Verified on
devbox: user namespaces work, systemd is present, so the standard multi-user
install is fine with the sandbox left on.

```bash
./bootstrap-linux.sh                                     # nix + flakes
home-manager switch --flake ~/nix-config#pahenn@devbox   # or #pahenn@mfcdev
```

The bootstrap script does the first activation via `nix run`, since
`home-manager` is not on PATH until it has run once.

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
