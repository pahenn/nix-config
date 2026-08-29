# Homebrew, and the nix-homebrew wiring that makes the taps themselves flake inputs.
{ config, inputs, ... }:
{
  # Homebrew 6.x requires third-party taps to be explicitly trusted via
  # `brew trust`, which writes to ~/.homebrew/trust.json (outside nix).
  # Opt out system-wide instead. This must live in brew.env rather than
  # environment.variables: nix-darwin runs `brew bundle` under
  # `sudo --preserve-env=PATH`, which strips every other variable, but
  # bin/brew sources this file itself on every invocation.
  environment.etc."homebrew/brew.env".text = ''
    HOMEBREW_NO_REQUIRE_TAP_TRUST=1
  '';

  # Ensure brew-installed node (pulled as a dependency) never shadows nvm
  system.activationScripts.postActivation.text = ''
    if /opt/homebrew/bin/brew ls --versions node &>/dev/null; then
      /opt/homebrew/bin/brew unlink node 2>/dev/null || true
    fi
  '';

  homebrew = {
    enable = true;
    # Formula definitions are refreshed deliberately, not on every switch.
    # With upgrade = true every `darwin-rebuild switch` moved all 30 brews to
    # whatever shipped that day, which defeats pinning postgresql@18 and means
    # two machines rebuilt a week apart diverge. To take updates:
    #   brew update && brew upgrade
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # The lists below are now the source of truth: anything installed but not
      # named here is removed on the next switch. "zap" would also delete app
      # data, which is why it is not used.
      cleanup = "uninstall";
    };

    brews = [
      "qemu"
      "tree"
      "go"
      "nano"
      "nanorc"
      "gh"
      "nvtop"
      "mactop"
      "openjdk"
      "postgresql@18"
      "pnpm"
      "yq"
      "sqlcmd"
      "uv"
      "unixODBC"
      "freetds"
      "duckdb"
      "minio-mc"
      "rainfrog"
      "duf"
      "htop"
      "git-filter-repo"
      "awscli"
      "aws-elasticbeanstalk"
      "nmap"
      "rust"
      "tailscale"
      # Declared alongside postgresql@18: @16 is what ~/.zshrc has always put on
      # PATH, so it stays until the client tooling is moved over deliberately.
      "postgresql@16"
      "coollabsio/coolify-cli/coolify-cli"
      # "opencode" # opt for direct install -> curl -fsSL https://opencode.ai/install | bash
      "ollama"
      "llama.cpp"
      "mlx"
      "mlx-lm"
      "omlx"
      # Required by the installed omlx build. The current omlx formula no longer
      # declares it, so `brew bundle cleanup` would remove it and break omlx —
      # confirmed with `brew uses --installed python@3.11`.
      "python@3.11"
    ];

    casks = [
      "brave-browser"
      "ghostty"
      "obsidian"
      "raycast"
      "orbstack"
      "visual-studio-code"
      "egoist/tap/kero"
      "spotify"
      "discord"
      "itsycal"
      "mos"
      "gcloud-cli"
      "tableplus"
      "lunar"
      "rectangle"
      # ai
      "lm-studio"
      "jan"
      # "claude-code" # moving this into native binary install direct from Anthropic -> curl -fsSL https://claude.ai/install.sh | bash
      # needs password
      "gpg-suite-no-mail"
      "zoom"
      # fonts
      "font-fira-code"
      "font-fira-code-nerd-font"
      "font-fira-mono-for-powerline"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-meslo-lg-nerd-font"
      # office
      "onlyoffice"
      "tailscale-app"
      "macwhisper"
      # aws
      "session-manager-plugin"
      "orcaslicer"
      "alt-tab"
      "orchard"
      "bambu-studio"
      "microsoft-teams"
      "rustdesk"
    ];
  };

  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    autoMigrate = false;
    mutableTaps = true;
    taps = {
      "jundot/homebrew-omlx" = inputs.homebrew-omlx;
      "coollabsio/homebrew-coolify-cli" = inputs.homebrew-coolify-cli;
      "egoist/homebrew-tap" = inputs.homebrew-egoist;
    };
  };
}
