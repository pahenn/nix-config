# User environment shared by every machine. Imported by the Linux home-manager
# configurations today; the Darwin configurations pick it up too.
{ pkgs, ... }:
{
  # Specify the Nix package
  nix.package = pkgs.nix;

  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    neovim
    zsh
    cloudflared
    nanorc

    # fonts
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];

  # Configure Zsh as default shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Configure Starship with custom config
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../home/starship/starship.toml);
  };

  # Enable font configuration
  fonts.fontconfig.enable = true;

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
