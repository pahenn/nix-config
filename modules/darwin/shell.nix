# System-level shell wiring. User-level shell config lives in modules/home/shell.nix.
{ pkgs, ... }:
{
  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh = {
    enable = true;
    # Disable the default prompt (which would override Starship)
    promptInit = "";
    interactiveShellInit = ''
      # Initialize Starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      # Initialize nvm
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
    '';
  };
}
