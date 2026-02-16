# ~/.config/nix/flake.nix

{
  description = "pahenn nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew }:
  let
    # Helper function to create a home-manager configuration
    mkHomeConfig = { system, username, homeDirectory, extraPackages ? [], extraModules ? [] }: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [
        {
          # Specify the Nix package
          nix.package = nixpkgs.legacyPackages.${system}.nix;

          # Enable experimental features
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          home.username = username;
          home.homeDirectory = homeDirectory;
          home.stateVersion = "25.05";

          # Packages to install
          home.packages = with nixpkgs.legacyPackages.${system}; [
            neovim
            zsh
            cloudflared
            nanorc

            # fonts
            nerd-fonts.fira-code
            nerd-fonts.fira-mono
            nerd-fonts.hack
            nerd-fonts.jetbrains-mono
          ] ++ extraPackages;

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
            settings = builtins.fromTOML (builtins.readFile ./home/starship/starship.toml);
          };

          # Enable font configuration
          fonts.fontconfig.enable = true;

          # Note: GNOME Terminal configuration disabled due to API changes
          # You can configure terminal colors manually in GNOME Terminal preferences
          # Recommended: FiraCode Nerd Font 11, Solarized Light theme

          # Let home-manager manage itself
          programs.home-manager.enable = true;
        }
      ] ++ extraModules; # Allow additional custom modules per-machine
    };

    # Helper function to create a Darwin configuration with a specific user
    mkDarwinConfig = { 
      user, 
      autoMigrate ? false,
      mutableTaps ? true,
      extraPackages ? [],
      extraBrews ? [],
      extraCasks ? [],
      extraModules ? [] 
    }: nix-darwin.lib.darwinSystem {
      modules = [
        ({ config, pkgs, ... }: {
          # Migrate to Lix
          nixpkgs.overlays = [ (final: prev: {
            inherit (prev.lixPackageSets.stable)
              nixpkgs-review
              nix-eval-jobs
              nix-fast-build
              colmena;
          }) ];

          nix.package = pkgs.lixPackageSets.stable.lix;


          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility. please read the changelog
          # before changing: `darwin-rebuild changelog`.
          system.stateVersion = 6;

          # Automatically set primary user from configuration
          system.primaryUser = user;

          # Allow user to run Homebrew without sudo password
          security.sudo.extraConfig = ''
            ${user} ALL=(ALL) NOPASSWD: /opt/homebrew/bin/brew
          '';

          # Create /etc/zshrc that loads the nix-darwin environment.
          programs.zsh = {
            enable = true;
            # Disable the default prompt (which would override Starship)
            promptInit = "";
            interactiveShellInit = ''
              # Initialize Starship prompt
              eval "$(${pkgs.starship}/bin/starship init zsh)"
            '';
          };

          environment.systemPackages = [
            pkgs.utm
            pkgs.neovim
            pkgs.starship
            pkgs.wireguard-tools
            pkgs.cloudflared
            pkgs.nanorc

            # fonts
            pkgs.nerd-fonts.fira-code
            pkgs.nerd-fonts.fira-mono
            pkgs.nerd-fonts.hack
            pkgs.nerd-fonts.jetbrains-mono
          ] ++ extraPackages;

          # Point starship to config in this repo via environment variable
          environment.variables.STARSHIP_CONFIG = "$HOME/nix-config/home/starship/starship.toml";

          homebrew = {
            enable = true;
            taps = [ ];
            global.autoUpdate = true;
            onActivation = {
              autoUpdate = true;
              upgrade = true;
              # cleanup = "uninstall"; # this go me into trouble. Oh well, there now
              cleanup = "zap";
            };
            brews = [
              "qemu"
              "tree"
              "go"
              "nano"
              "nanorc"
              "nvm"
              "gh"
              "nvtop"
              "mactop"
              "openjdk"
              "postgresql@16"
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
              # "opencode" # opt for direct install -> curl -fsSL https://opencode.ai/install | bash
              "ollama"
              "llama.cpp"
              "mlx"
              "mlx-lm"
            ] ++ extraBrews;
            casks = [
              "brave-browser"
              "ghostty"
              "obsidian"
              "raycast"
              "tailscale-app"
              "cursor"
              "orbstack"
              "visual-studio-code"
              "spotify"
              "discord"
              "itsycal"
              "mos"
              "gcloud-cli"
              "tableplus"
              "lunar"
              # ai
              "lm-studio"
              "ollama-app"
              "jan"
              # "claude-code" # moving this into native binary install direct from Anthropic -> curl -fsSL https://claude.ai/install.sh | bash
              # needs password
              "gpg-suite-no-mail"
              "zoom"
              "logi-options+"
              # fonts
              "font-fira-code"
              "font-fira-code-nerd-font"
              "font-fira-mono-for-powerline"
              "font-hack-nerd-font"
              "font-jetbrains-mono-nerd-font"
              "font-meslo-lg-nerd-font"
              # office
              "onlyoffice"
              "cap"
              # security
              # "bitwarden" # need to use mac app to get browser integration
              "macwhisper"
              "rustdesk"
            ] ++ extraCasks;
          };

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        })

        # Homebrew configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = user;
            inherit autoMigrate mutableTaps;
          };
        }
      ] ++ extraModules; # Allow additional custom modules per-machine
    };
  in
  {
    # macOS configurations
    darwinConfigurations."pahenn-macbook" = mkDarwinConfig {
      user = "pahenn";
      # autoMigrate = true;
      mutableTaps = true;
      extraBrews = [
        
      ];
      extraCasks = [
        "tastytrade"
        "notion-calendar"
        "rectangle"
        "bambu-studio"
      ];
    };

    darwinConfigurations."home-mini" = mkDarwinConfig {
      user = "pahenn";
      mutableTaps = true;
      extraBrews = [
        "socat"
      ];
    };

    # home-manager configurations (for aarch64 Linux systems)
    homeConfigurations."ubuntu@ubuntu" = mkHomeConfig {
      system = "aarch64-linux";
      username = "ubuntu";
      homeDirectory = "/home/ubuntu";
      extraPackages = with nixpkgs.legacyPackages.aarch64-linux; [
        # Add packages here
        # Note: Tailscale must be installed via snap (see INSTALL.md):
        # - sudo snap install tailscale
        # - sudo tailscale up
      ];
    };
    # home-manager configurations (for x86_64 Linux systems - Proxmox VM)
    homeConfigurations."patrick@patrick-homelab" = mkHomeConfig {
      system = "x86_64-linux";
      username = "patrick";
      homeDirectory = "/home/patrick";
      extraPackages = with nixpkgs.legacyPackages.x86_64-linux; [
        # Add packages here
        # Note: Tailscale must be installed via snap (see INSTALL.md):
        # - sudo snap install tailscale
        # - sudo tailscale up
      ];
    };
  };
}
