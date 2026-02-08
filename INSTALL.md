# Installation Guide

This guide covers installing Nix and the required tools for each platform.

## macOS Installation

### 1. Install Lix

```bash
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Or use the official installer:

```bash
sh <(curl -L https://nixos.org/nix/install)
```

### 2. Clone this repository

```bash
git clone <your-repo-url> ~/.config/nix
cd ~/.config/nix
```

### 3. Build and activate your configuration

```bash
# For MacBook Pro
darwin-rebuild switch --flake .#pahenn-macbook-pro

# For Mac Mini
darwin-rebuild switch --flake .#mini
```

## Linux (Ubuntu) Installation

### 1. Install Nix

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 2. Enable flakes

**Important:** After installing Nix, you need to restart your shell or source the Nix profile before proceeding.

```bash
# Restart your shell or run:
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

Then enable experimental features:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
```

**Verify it works:**

```bash
nix --version  # Should show Nix version
```

### 3. Clone this repository

```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
```

### 4. Install home-manager and activate configuration

```bash
# Update flake inputs
nix flake update

# First-time activation (backs up existing config files)
nix run home-manager/master -- switch --flake .#ubuntu@ubuntu -b backup
```

### 5. Install Tailscale (manual step)

```bash
sudo snap install tailscale
sudo tailscale up
```

## Updating

### macOS

```bash
cd ~/.config/nix
git pull
darwin-rebuild switch --flake .#<machine-name>
```

### Linux

```bash
cd ~/nix-config
git pull
home-manager switch --flake .#ubuntu@ubuntu
```

## Troubleshooting

### macOS: "darwin-rebuild: command not found"

The installer should have added Nix to your PATH. Try:

- Restart your terminal
- Or manually source: `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`

### Linux: "nix: command not found"

After installation, you may need to:

- Restart your shell session
- Or manually source: `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`

### Flakes not enabled

If you see errors about flakes being experimental, ensure you've added the experimental features configuration (see Linux step 2).
