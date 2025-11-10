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

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew, homebrew-core, homebrew-cask}:
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

          # Let home-manager manage itself
          programs.home-manager.enable = true;
        }
      ] ++ extraModules; # Allow additional custom modules per-machine
    };

    # Helper function to create a Darwin configuration with a specific user
    mkDarwinConfig = { user, autoMigrate ? false, mutableTaps ? true, extraPackages ? [], extraBrews ? [], extraModules ? [] }: nix-darwin.lib.darwinSystem {
      modules = [
        ({ config, pkgs, ... }: {
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
          # programs.zsh.enable = true;

          environment.systemPackages = [
            pkgs.utm
            pkgs.neovim

            # fonts
            pkgs.nerd-fonts.fira-code
            pkgs.nerd-fonts.fira-mono
            pkgs.nerd-fonts.hack
            pkgs.nerd-fonts.jetbrains-mono
          ] ++ extraPackages;

          # Configure Starship with custom config
          programs.starship = {
            enable = true;
            interactiveOnly = false;
            settings = builtins.fromTOML (builtins.readFile ./home/starship/starship.toml);
          };

          homebrew = {
            enable = true;
            global.autoUpdate = true;
            brews = extraBrews;
            casks = [
              "brave-browser"
              "font-fira-code"
              "font-fira-code-nerd-font"
              "font-fira-mono-for-powerline"
              "font-hack-nerd-font"
              "font-jetbrains-mono-nerd-font"
              "font-meslo-lg-nerd-font"
              "ghostty"
              "orbstack"
              "tailscale"
            ];
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
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };
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
      autoMigrate = true;
    };

    darwinConfigurations."mini" = mkDarwinConfig {
      user = "home";
      mutableTaps = false;
      extraBrews = [
        "socat"
      ];
    };

    # home-manager configurations (for Linux systems)
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
  };
}