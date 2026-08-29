# Nix Configuration

Flake-based configuration for two Macs (nix-darwin) and two Linux dev boxes
(home-manager). See [INSTALL.md](INSTALL.md) to set up a new machine.

## Layout

```
flake.nix              inputs, and one line per machine — nothing else
lib/                   mkDarwin / mkHome
hosts/                 one file per machine; the only place a machine name lives
modules/darwin/        system-level, macOS only
modules/home/          user-level, shared by macOS and Linux
```

The point of `modules/home/` is that the Mac and the dev boxes get the *same*
shell. Before this split the Macs' `~/.zshrc` was 162 unmanaged lines and only
Linux had home-manager.

Package lists are not threaded through function arguments. The module system
merges `homebrew.brews`, `environment.systemPackages` and `home.packages` across
modules, so a host adds to them by setting them directly:
`homebrew.brews = [ "something" ];` in a host file merges with the shared list.

## Machines

| Config | What |
|---|---|
| `pahenn-macbook` | MacBook Pro |
| `home-mini` | Mac Mini |
| `pahenn@devbox` | CT 118 on lab1, `10.73.42.140` — personal dev box |
| `pahenn@mfcdev` | CT 119 on lab1, `10.73.42.156` — dev box with an employer path |

```bash
sudo darwin-rebuild switch --flake .#pahenn-macbook
home-manager switch --flake .#pahenn@devbox
```

All four machines evaluate to just two closures today, which is correct rather
than a bug. The Macs are identical because the `tailscale` brew that used to be
Mac-Mini-only turned out to be installed on both. `devbox` and `mfcdev` are
identical because they differ in Docker and the employer tailnet, and both of
those live in the `mfc-work` container rather than the host shell.

## Adding things

| | where |
|---|---|
| CLI tool, any machine | `modules/home/default.nix` → `home.packages` |
| CLI tool, dev boxes only | `modules/home/linux-dev.nix` |
| macOS GUI app | `modules/darwin/homebrew.nix` → `casks` |
| macOS CLI better from brew | `modules/darwin/homebrew.nix` → `brews` |
| one machine only | that machine's file in `hosts/` |
| a new machine | a file in `hosts/`, plus one line in `flake.nix` |

## Things that will bite

**Homebrew is now authoritative.** `cleanup = "uninstall"` is on, so removing an
entry actually removes the package — which it did not before, and is why ten
packages had drifted out of this file. Dry-run any change:

```bash
nix eval --raw .#darwinConfigurations.pahenn-macbook.config.homebrew.brewfile > /tmp/Brewfile
brew bundle cleanup --file=/tmp/Brewfile
```

**Brews are no longer auto-upgraded.** `upgrade = true` moved all 30 formulae to
whatever shipped that day on every switch, which defeated pinning
`postgresql@18` and meant two machines rebuilt a week apart diverged. Take
updates with `brew update && brew upgrade`.

**`~/.zshrc` is a read-only symlink.** Installers that append to it (Amazon Q,
opencode, OpenKnowledge, Antigravity) will fail. Add the line here, or to
`~/.zshrc.local`, which is sourced last and stays writable.

**`~/.zprofile` is not managed**, on purpose — it holds `brew shellenv`, and
losing that loses Homebrew from PATH entirely.

**`~/.gitconfig` outranks the generated config.** home-manager writes
`~/.config/git/config`; git reads `~/.gitconfig` after it. Move the old one
aside on first switch or it silently wins.

**`postgresql@16` and `@18` are both declared.** `@16` is what has always been on
PATH; `@18` was declared but never on it. Pick one deliberately rather than
letting it drift further — `modules/home/darwin.nix` sets the PATH entry.
