# Nix Configuration

Multi-machine Nix configuration using flakes for macOS (nix-darwin) and Linux (home-manager).

## Machines

### macOS (nix-darwin)

- **pahenn-macbook-pro**: Personal MacBook Pro
  - User: `pahenn`
  - Homebrew auto-migration enabled

- **mini**: Mac Mini
  - User: `home`
  - Extra brews: `socat`
  - Immutable Homebrew taps

### Linux (home-manager)

- **ubuntu@ubuntu-server**: Ubuntu VM running on Mac Mini
  - User: `ubuntu`
  - Home directory: `/home/ubuntu`
  - Note: Tailscale must be installed via snap (see below)

## Usage

### macOS

```bash
# Build and activate configuration
darwin-rebuild switch --flake .#pahenn-macbook-pro
# or
darwin-rebuild switch --flake .#mini
```

### Linux (Ubuntu)

```bash
# First time setup
nix flake update
nix run home-manager/master -- switch --flake .#ubuntu@ubuntu-server

# Subsequent updates
home-manager switch --flake .#ubuntu@ubuntu-server
```

## Adding Packages

### macOS - Nix packages
Add to `extraPackages` in the machine configuration:
```nix
extraPackages = with pkgs; [
  htop
  vim
];
```

### macOS - Homebrew packages
Add to `extraBrews` for CLI tools or `homebrew.casks` for GUI apps.

### Linux - Nix packages
Add to `extraPackages` in the home-manager configuration:
```nix
extraPackages = with nixpkgs.legacyPackages.aarch64-linux; [
  git
  htop
];
```

## Manual Setup Required

### Ubuntu Server (Tailscale)
```bash
sudo snap install tailscale
sudo tailscale up
```

## Structure

- `mkDarwinConfig`: Helper function for macOS configurations
  - Automatically sets `system.primaryUser` from config
  - Configures Homebrew with the same user
  - Supports machine-specific packages and brews

- `mkHomeConfig`: Helper function for Linux home-manager configurations
  - User-level package management
  - No system-level daemon support
