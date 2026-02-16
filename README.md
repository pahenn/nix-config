# Nix Configuration

Multi-machine Nix configuration using flakes for macOS (nix-darwin) and Linux (home-manager).

**New to this setup?** See [INSTALL.md](INSTALL.md) for installation instructions.

## Machines

### macOS (nix-darwin)

- **pahenn-macbook**: Personal MacBook Pro
  - User: `pahenn`
  - Extra casks: tastytrade, notion-calendar, rectangle, bambu-studio

- **home-mini**: Mac Mini
  - User: `pahenn`
  - Extra brews: `socat`

### Linux (home-manager)

- **ubuntu@ubuntu**: Ubuntu VM running on Mac Mini (aarch64)
  - User: `ubuntu`
  - Hostname: `ubuntu`
  - Home directory: `/home/ubuntu`
  - Note: Tailscale must be installed via snap (see below)

- **patrick@patrick-homelab**: Proxmox VM (x86_64)
  - User: `patrick`
  - Hostname: `patrick-homelab`
  - Home directory: `/home/patrick`
  - Note: Tailscale must be installed via snap (see below)

## Usage

**Note:** Configuration names match hostnames, so the `--flake .#<name>` argument is optional if you're on that machine. You can just run `darwin-rebuild switch` or `home-manager switch` without specifying the configuration name.

### macOS

```bash
# Build and activate configuration (requires sudo)
sudo darwin-rebuild switch --flake ~/nix-config#pahenn-macbook
# or
sudo darwin-rebuild switch --flake ~/nix-config#home-mini

# Quick reference - pull latest changes and rebuild:
cd ~/nix-config && git pull && sudo darwin-rebuild switch --flake ~/nix-config#pahenn-macbook
# or for home-mini:
cd ~/nix-config && git pull && sudo darwin-rebuild switch --flake ~/nix-config#home-mini
```

**Note:** Using `--flake ~/nix-config#<config-name>` reads directly from your git repository, eliminating the need to manually copy files to `/etc/nix-darwin`. This is the recommended flake-native approach.

### Linux (Ubuntu)

```bash
# First time setup (only needed once)
cd ~/nix-config
nix flake update
nix run home-manager/master -- switch --flake ~/nix-config#ubuntu@ubuntu

# Subsequent updates (use this after the first time)
home-manager switch --flake ~/nix-config#ubuntu@ubuntu

# Quick reference - after initial setup, pull and rebuild:
cd ~/nix-config && git pull && home-manager switch --flake ~/nix-config#ubuntu@ubuntu
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

## Post-Installation Setup (Ubuntu)

After running `home-manager switch` for the first time on Ubuntu, run the bootstrap script to complete the setup:

```bash
cd ~/nix-config
./bootstrap-ubuntu.sh
```

This script will:
- Install OpenSSH server for remote access
- Install Tailscale via snap
- Add Nix's zsh to `/etc/shells` and set it as your default shell

After the script completes, run `sudo tailscale up` to connect to your Tailscale network, then log out and back in for the shell change to take effect.

## Structure

- `mkDarwinConfig`: Helper function for macOS configurations
  - Automatically sets `system.primaryUser` from config
  - Configures Homebrew with the same user
  - Supports machine-specific packages and brews

- `mkHomeConfig`: Helper function for Linux home-manager configurations
  - User-level package management
  - No system-level daemon support

## Advanced Configuration

### Helper Function Parameters

Both helper functions support `extraModules` for custom configurations without modifying the helper functions.

#### `mkDarwinConfig` Parameters
- `user`: Username for system.primaryUser and Homebrew
- `autoMigrate`: Auto-migrate existing Homebrew installations (default: false)
- `mutableTaps`: Allow mutable Homebrew taps (default: true)
- `extraPackages`: Additional Nix packages to install
- `extraBrews`: Additional Homebrew CLI packages
- `extraModules`: Custom nix-darwin modules for advanced configuration

#### `mkHomeConfig` Parameters
- `system`: Target system architecture (e.g., "aarch64-linux")
- `username`: User account name
- `homeDirectory`: Full path to home directory
- `extraPackages`: Additional Nix packages to install
- `extraModules`: Custom home-manager modules for advanced configuration

### Using `extraModules`

Use `extraModules` to add custom configuration without modifying the helper functions.

#### macOS Example (nix-darwin)
```nix
darwinConfigurations."my-machine" = mkDarwinConfig {
  user = "myuser";
  extraModules = [
    ({ config, pkgs, ... }: {
      # Custom system configuration
      system.defaults.dock.autohide = true;

      # Additional services
      services.some-service.enable = true;
    })
  ];
};
```

#### Linux Example (home-manager)
```nix
homeConfigurations."myuser@myhost" = mkHomeConfig {
  system = "x86_64-linux";
  username = "myuser";
  homeDirectory = "/home/myuser";
  extraModules = [
    ({ config, pkgs, ... }: {
      # Custom home-manager configuration
      programs.git = {
        enable = true;
        userName = "My Name";
        userEmail = "my@email.com";
      };

      # Custom environment variables
      home.sessionVariables = {
        EDITOR = "nvim";
      };
    })
  ];
};
```
