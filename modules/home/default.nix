# User environment shared by every machine, Mac and Linux alike.
{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./starship.nix
    ./git.nix
    ./ssh.nix
    ./claude-code.nix
    ./nano.nix
  ];

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    neovim
    cloudflared
    nanorc

    # Moved here 2026-11-09 from homebrew.brews (Mac) and linux-dev.nix (Linux),
    # so every machine runs the same tools from the same pin. On the Mac they came
    # from /opt/homebrew/bin, which only reaches PATH through `brew shellenv` in
    # the unmanaged ~/.zprofile - so a non-login shell never saw them.
    # Each one was removed from homebrew.brews in the same commit: /opt/homebrew/bin
    # is ahead of the nix profile on PATH, so a copy left in both silently wins.
    gh
    tree
    htop
    uv
    pnpm
    go
    duf
    duckdb
    git-filter-repo
    nmap
    rainfrog
    minio-client   # still installs `mc`
    # NOT `yq`: in nixpkgs that is kislyuk's Python jq wrapper (v3). Homebrew's
    # `yq` is mikefarah's Go tool (v4), which is yq-go here. Same binary name,
    # different syntax - the obvious rename would have changed behaviour silently.
    yq-go
  ];

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
