# Mac-only user environment. This is what used to be the unmanaged 162-line
# ~/.zshrc.
#
# ~/.zprofile IS generated here, contrary to what this comment said until
# 2026-08-30. Nothing was lost by that: `brew shellenv` moved to nix-darwin's
# /etc/zshrc, which runs for every shell. The OrbStack init did go -- its
# binaries are all still on PATH via /usr/local/bin and /opt/homebrew/bin, so
# only the zsh completions for docker, kubectl, orb and orbctl went with it.
{ config, lib, pkgs, ... }:
let
  # Where the Vaultwarden desktop app serves the vault SSH keys.
  bitwardenAgent =
    "${config.home.homeDirectory}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock";

  # git signs by shelling out to `ssh-keygen -Y sign`, and ssh-keygen resolves
  # its agent from SSH_AUTH_SOCK. It does NOT read ~/.ssh/config, so the
  # `IdentityAgent` line pointing ssh at the vault agent is invisible to it.
  # On the Mac that means the signing key is reachable by ssh and not by
  # ssh-keygen, and every commit fails with "No private key found for public
  # key" while `ssh` and `git push` keep working -- see git-signing.md.
  #
  # Exporting SSH_AUTH_SOCK in the shell also fixes it and is the wrong fix: it
  # takes launchd's agent out of the picture for everything else, which is
  # exactly the tradeoff vaultwarden-ssh-agent.md rejected when it chose
  # ssh_config over an export. gpg.ssh.program confines the override to signing.
  #
  # The dev boxes need none of this. Their agent is forwarded onto SSH_AUTH_SOCK
  # already, which is why signing worked there and this stayed hidden.
  gitSigner = pkgs.writeShellScriptBin "ssh-keygen-vault-agent" ''
    if [ -S "${bitwardenAgent}" ]; then
      export SSH_AUTH_SOCK="${bitwardenAgent}"
    fi
    exec ${pkgs.openssh}/bin/ssh-keygen "$@"
  '';
in
{
  programs.git.settings.gpg.ssh.program = "${gitSigner}/bin/ssh-keygen-vault-agent";

  # The Mac-only half of ~/.ssh/config. The shared lab hosts are in ssh.nix.
  home.file.".ssh/config".text = lib.mkMerge [
    # OrbStack writes this line into ~/.ssh/config itself when it installs or
    # updates. Once home-manager owns that file it is a read-only symlink into
    # the store and OrbStack can no longer add it - the same trap shell.nix
    # records for installers that append to ~/.zshrc. Declared here so it
    # survives, and placed above the Host blocks the way OrbStack asks, which
    # the hand-maintained file did not do.
    (lib.mkOrder 200 ''
      Include ~/.orbstack/ssh/config
    '')

    # Last, because ssh_config is first-match-wins and `Host *` matches
    # everything: any specific block above must get to set its own options
    # first. This is the only place the vault agent is named for ssh itself -
    # git signing cannot use it, which is what gitSigner above exists for.
    (lib.mkAfter ''

      # Bitwarden desktop as the SSH agent, backed by self-hosted Vaultwarden.
      # Private keys live in the vault and never touch disk. On-disk
      # IdentityFile keys still work as a fallback, so this is additive.
      # NOTE: locking the vault disables these keys - that is the security
      # property, but it also means an unattended script fails until the vault
      # is unlocked.
      Host *
          IdentityAgent ${bitwardenAgent}
    '')
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/Library/pnpm"
    "/opt/homebrew/opt/openjdk/bin"
    "/opt/homebrew/opt/postgresql@16/bin"
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.antigravity/antigravity/bin"
    "${config.home.homeDirectory}/.opencode/bin"
  ];

  home.sessionVariables = {
    PNPM_HOME = "${config.home.homeDirectory}/Library/pnpm";
    # The standalone nvm in ~/.nvm holds the installed node versions. The
    # Homebrew nvm formula was a second copy of the script pointed at this same
    # directory, and has been dropped.
    NVM_DIR = "${config.home.homeDirectory}/.nvm";
  };

  # system.defaults points screencapture here; macOS silently keeps using the
  # Desktop if the directory does not exist.
  home.file."Screenshots/.keep".text = "";

  programs.zsh.shellAliases = {
    flushdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
    nano = "/opt/homebrew/bin/nano";
  };

  programs.zsh.initContent = lib.mkMerge [
    # OrbStack, at order 550 so it lands BEFORE home-manager's compinit.
    # Its init.zsh does two things: appends ~/.orbstack/bin to PATH, which is
    # redundant (every binary is already symlinked into /usr/local/bin or
    # /opt/homebrew/bin), and appends its completions dir to fpath, which is
    # not. fpath after compinit is fpath ignored, so the ordering is the whole
    # point -- sourcing this in the default block silently gets you nothing.
    #
    # Lost when ~/.zprofile became generated on 2026-08-29 and nobody noticed,
    # because the commands all kept working and only the completions went.
    (lib.mkOrder 550 ''
      [ -f "$HOME/.orbstack/shell/init.zsh" ] && . "$HOME/.orbstack/shell/init.zsh"
    '')

    ''
    # uv's installer drops a PATH shim here
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

    # nvm — sourced once, from the standalone install that owns the versions
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

    # uv completions
    command -v uv  >/dev/null && eval "$(uv generate-shell-completion zsh)"
    command -v uvx >/dev/null && eval "$(uvx --generate-shell-completion zsh)"

    [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

    [ -f "$HOME/.ok/env.sh" ] && . "$HOME/.ok/env.sh"

    # tailscale: account switch + exit nodes
    # macOS GUI caches the exit-node menu per profile and doesn't repopulate
    # after a switch. Uses the app-bundled CLI (matches tailscaled build;
    # the Homebrew binary is a different build and warns every call).
    ts-exit() {
      local TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      [[ -x $TS ]] || TS=$(command -v tailscale) || { print -u2 "no tailscale CLI"; return 1 }

      case "''${1:-status}" in
        status|"")
          print "profile:   $($TS switch --list 2>/dev/null | awk '/\*/{print $2, $3}')"
          local en=$($TS debug prefs 2>/dev/null | awk -F'"' '/"ExitNodeID"/{print $4}')
          print "exit node: ''${en:-<none>}"
          ;;
        accounts|ls) $TS switch --list ;;
        use)
          [[ -n ''${2:-} ]] || { print -u2 "usage: ts-exit use <id|tailnet|account>"; return 1 }
          print "switching -> $2"
          $TS switch "$2" || return 1
          print -n "waiting for netmap"
          local i
          for i in {1..20}; do
            $TS exit-node list 2>/dev/null | grep -qE '^ 100\.' && break
            sleep 0.75
          done
          print " ok"; print
          $TS exit-node list
          ;;
        nodes|list) $TS exit-node list ;;
        exit|set)
          [[ -n ''${2:-} ]] || { print -u2 "usage: ts-exit exit <hostname|ip>"; return 1 }
          $TS set --exit-node="$2" --exit-node-allow-lan-access && print "exit node -> $2 (LAN access on)"
          ;;
        off|clear) $TS set --exit-node= && print "exit node cleared" ;;
        *)
          print "ts-exit — tailscale account + exit node helper

      ts-exit                  current profile and exit node
      ts-exit accounts         list profiles
      ts-exit use <id>         switch profile, wait for netmap, show exit nodes
      ts-exit nodes            list exit nodes for current profile
      ts-exit exit <host|ip>   use an exit node (LAN access enabled)
      ts-exit off              stop using an exit node"
          ;;
      esac
    }
    ''
  ];
}
