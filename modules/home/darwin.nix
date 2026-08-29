# Mac-only user environment. This is what used to be the unmanaged 162-line
# ~/.zshrc.
#
# Note ~/.zprofile is deliberately NOT managed here: it carries
# `brew shellenv` and the OrbStack init, and having home-manager generate it
# risked losing the Homebrew PATH entirely.
{ config, ... }:
{
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

  programs.zsh.initContent = ''
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
  '';
}
