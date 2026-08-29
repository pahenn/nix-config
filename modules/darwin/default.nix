# Everything every Mac in this repo gets. Machine-specific bits live in hosts/.
{ config, pkgs, self, ... }:
{
  imports = [
    ./nix.nix
    ./shell.nix
    ./homebrew.nix
  ];

  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility. please read the changelog
  # before changing: `darwin-rebuild changelog`.
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Allow user to run Homebrew without sudo password. nix-darwin's own
  # activation shells out to `brew bundle` this way.
  security.sudo.extraConfig = ''
    ${config.system.primaryUser} ALL=(ALL) NOPASSWD: /opt/homebrew/bin/brew
  '';

  # Note: Git GPG signing is configured via ~/.gitconfig
  # (set with: git config --global user.signingkey, commit.gpgsign, gpg.program)

  environment.systemPackages = [
    pkgs.utm
    pkgs.neovim
    pkgs.starship
    pkgs.wireguard-tools
    pkgs.cloudflared
    pkgs.nanorc
    pkgs.sshpass

    # fonts
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # Point starship to config in this repo via environment variable
  environment.variables.STARSHIP_CONFIG = "$HOME/nix-config/home/starship/starship.toml";
}
