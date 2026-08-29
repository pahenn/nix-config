# Cross-platform shell. Machine-specific PATH and tooling live in darwin.nix /
# linux-dev.nix.
#
# home-manager owns ~/.zshrc and ~/.zshenv from here on, which means they become
# read-only symlinks into the nix store. Installers that append to ~/.zshrc
# (Amazon Q, opencode, OpenKnowledge, Antigravity) can no longer do so — add the
# line to this flake instead, or drop it in ~/.zshrc.local, which is sourced at
# the end and stays writable.
{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      upnpm = "corepack prepare pnpm@latest --activate";
      venv = "source .venv/bin/activate";
    };

    # ~/.zshenv. Secrets are sourced here and nowhere else — this file exists
    # because home-manager generates .zshenv and would otherwise drop the line.
    envExtra = ''
      # Secrets live in a 0600 file, not here.
      [[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh
    '';

    initContent = ''
      # gpg needs to know which tty to prompt on, and it differs per shell.
      export GPG_TTY=$(tty)

      # clean pycache and ipynb checkpoints from here down
      pyclean() {
        find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
        find . -type f -name '*.ipynb[co]' -delete -o -type d -name .ipynb_checkpoints -delete
      }

      # cd to the repo root
      gohome() {
        local base_dir
        base_dir=$(git rev-parse --show-toplevel) && cd "$base_dir"
      }

      # commit using message.commit at the repo root
      gcef() {
        local base_dir
        base_dir=$(git rev-parse --show-toplevel) && git commit -eF "$base_dir/message.commit"
      }

      # Escape hatch for anything not worth putting in the flake.
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };

  home.sessionVariables.POETRY_VIRTUALENVS_IN_PROJECT = "1";
}
