# Nix Configuration

Multi-machine Nix configuration using flakes for macOS (nix-darwin) and Linux (home-manager).

**New to this setup?** See [INSTALL.md](INSTALL.md) for installation instructions.

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

- **ubuntu**: Ubuntu VM running on Mac Mini
  - User: `ubuntu`
  - Hostname: `ubuntu`
  - Home directory: `/home/ubuntu`
  - Note: Tailscale must be installed via snap (see below)

## Usage

**Note:** Configuration names match hostnames, so the `--flake .#<name>` argument is optional if you're on that machine. You can just run `darwin-rebuild switch` or `home-manager switch` without specifying the configuration name.

### macOS

```bash
# Build and activate configuration
darwin-rebuild switch --flake .#pahenn-macbook-pro
# or
darwin-rebuild switch --flake .#mini
# or just: darwin-rebuild switch (auto-detects hostname)

# Quick reference - pull latest changes and rebuild:
cd ~/.config/nix && git pull && darwin-rebuild switch --flake .#pahenn-macbook-pro
# or for mini:
cd ~/.config/nix && git pull && darwin-rebuild switch --flake .#mini
# or: cd ~/.config/nix && git pull && darwin-rebuild switch
```

### Linux (Ubuntu)

```bash
# First time setup (only needed once)
nix flake update
nix run home-manager/master -- switch --flake .#ubuntu@ubuntu

# Subsequent updates (use this after the first time)
home-manager switch --flake .#ubuntu@ubuntu
# or just: home-manager switch (auto-detects user@hostname)

# Quick reference - after initial setup, just run:
cd ~/nix-config && git pull && home-manager switch
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
