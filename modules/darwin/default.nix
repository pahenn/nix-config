# Everything every Mac in this repo gets. Machine-specific bits live in hosts/.
{ pkgs, self, user, ... }:
{
  imports = [
    ./nix.nix
    ./shell.nix
    ./homebrew.nix
    ./home.nix
    ./system-defaults.nix
  ];

  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility. please read the changelog
  # before changing: `darwin-rebuild changelog`.
  system.stateVersion = 6;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;

  # Allow user to run Homebrew without sudo password. nix-darwin's own
  # activation shells out to `brew bundle` this way.
  security.sudo.extraConfig = ''
    ${user} ALL=(ALL) NOPASSWD: /opt/homebrew/bin/brew
  '';

  environment.systemPackages = [
    pkgs.utm
    pkgs.starship
    pkgs.wireguard-tools
    pkgs.sshpass

    # fonts
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
