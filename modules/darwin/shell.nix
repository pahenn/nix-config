# System-level shell wiring only. The prompt, PATH, aliases and functions are
# home-manager's job now — see modules/home/shell.nix and modules/home/darwin.nix.
#
# Starship used to be initialised here *and* at the bottom of ~/.zshrc, and nvm
# was sourced here from ~/.nvm while ~/.zshrc sourced Homebrew's copy over the
# top. Both are now done exactly once, by home-manager.
{ ... }:
{
  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh = {
    enable = true;
    # Disable the default prompt (which would override Starship)
    promptInit = "";
  };
}
