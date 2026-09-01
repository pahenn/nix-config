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
  # Pinned deliberately: nothing tracks upstream nvm releases, and an installer
  # fetched from a moving ref is a different program on every new machine.
  nvmVersion = "v0.40.7";

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

  # Vaultwarden from the shell. Mac only, deliberately: a `bw` session is a
  # credential, and the whole point of the dev boxes is that they hold none -
  # see secrets.md. The vault is already the index of record for the estate, so
  # having it reachable without the GUI is what makes things like the
  # ~/.ssh/config.d/private.conf note verifiable rather than merely stored.
  #
  # One-time setup per machine, both stateful and so not declarable here:
  #   bw config server https://vaultwarden.pahenn.xyz
  #   bw login
  #
  # rbw is the one to reach for interactively. `bw` has no vault-timeout concept
  # at all - no resident process, so every shell needs its own session key from
  # `bw unlock --raw`, and the only way to make that persist is to leave a vault
  # decryption key on disk. That would negate the property ssh.nix depends on:
  # locking the vault disables the SSH keys. rbw instead runs an agent holding
  # the key in memory with a lock_timeout, which is the same model as ssh-agent
  # and as the desktop app. It is third-party, which is the reason to keep the
  # official client alongside it rather than replacing it.
  #
  # pinentry-mac is not optional: rbw-agent has no way to ask for the master
  # password without it.
  #
  #   rbw config set base_url https://vaultwarden.pahenn.xyz
  #   rbw config set email patrick@pahenn.dev
  #   rbw config set pinentry pinentry-mac
  #   rbw config set lock_timeout 28800
  #   rbw login
  #
  # Not declared as ~/.config/rbw/config.json on purpose, yet: rbw writes to
  # that file itself and it is not yet established whether login stores a device
  # id there, which a read-only store symlink would break. Worth revisiting once
  # that is known - it is otherwise exactly the kind of file that belongs here.
  home.packages = [ pkgs.bitwarden-cli pkgs.rbw pkgs.pinentry_mac ];

  # nvm, installed by its own installer on activation — the same shape as
  # claude-code.nix, and for the same reason: nixpkgs does not package a shell
  # function usefully, and the vendor installer is the supported path.
  #
  # This exists because ~/.nvm was never a standalone install, whatever the
  # comment above used to claim. It was a directory of symlinks into
  # /opt/homebrew/opt/nvm — so when the Homebrew formula was dropped, nvm.sh and
  # nvm-exec went dangling and node vanished from PATH on 2026-09-01. It failed
  # silently because the guard is `[ -s "$NVM_DIR/nvm.sh" ]` and `-s` follows
  # symlinks: a dangling one is simply false. No error, no nvm, and ~/.nvm/versions
  # still holding v22.14.0 the whole time.
  #
  # `-r` rather than `-s` as the guard here, so a dangling symlink counts as
  # absent and this repairs it rather than skipping.
  #
  # PROFILE=/dev/null is load-bearing: the installer appends its own block to
  # ~/.zshrc, which is a read-only store symlink. The sourcing is declared above
  # anyway, so the installer must be told not to try.
  #
  # Verified against a directory shaped like the broken one — dangling nvm.sh
  # plus a populated versions/ — and it replaces the symlink while leaving the
  # installed node versions alone.
  #
  # The PATH list is not decoration. The first run printed
  # `nvm.sh: line 741: awk: command not found` because gawk was missing from it:
  # activation runs with a minimal PATH, so anything the installer shells out to
  # has to be named here. It survived only because the install had already
  # finished and the failure was in the installer sourcing nvm.sh at the end.
  home.activation.nvm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -r "$HOME/.nvm/nvm.sh" ]; then
      echo "nvm: present at ~/.nvm, leaving alone"
    else
      echo "nvm: installing ${nvmVersion}"
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c \
        'export PATH="${lib.makeBinPath [
             pkgs.curl pkgs.git pkgs.bash pkgs.coreutils
             pkgs.gnused pkgs.gnugrep pkgs.gawk
           ]}:$PATH"; \
         export PROFILE=/dev/null; \
         curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${nvmVersion}/install.sh | bash' \
        || echo "nvm: install FAILED — continuing activation" >&2
    fi
  '';

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

    # The other Mac. Here rather than in ssh.nix because a workstation is not
    # lab: the dev boxes have no reason to reach a laptop, the tailnet ACL does
    # not grant tagged devices a path to a user device anyway, and writing a
    # block that cannot work is how config stops being trustworthy. Move it to
    # ssh.nix the day a dev box genuinely needs it.
    #
    # Addressed by its tailnet IP, not a LAN one: the two Macs are not reliably
    # on the same network, which is the whole reason this entry is useful.
    #
    # INERT UNTIL Remote Login is enabled on that machine - macOS ships it off,
    # and port 22 was refused as of 2026-08-31. Nothing here can turn it on;
    # it is System Settings > General > Sharing.
    (lib.mkOrder 400 ''

      Host home-mini
          HostName 100.64.0.7
          User pahenn
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
    # ~/.nvm holds the installed node versions, and since 2026-09-01 the nvm
    # program itself — see the activation below for why that needed saying.
    NVM_DIR = "${config.home.homeDirectory}/.nvm";
  };

  # system.defaults points screencapture here; macOS silently keeps using the
  # Desktop if the directory does not exist.
  home.file."Screenshots/.keep".text = "";

  programs.zsh.shellAliases = {
    flushdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
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
