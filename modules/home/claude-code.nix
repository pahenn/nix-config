# Claude Code, and making ~/.local/bin findable.
#
# Both halves lived in linux-dev.nix until 2026-08-31, so only the dev boxes got
# them. The Macs were left running an installer someone had typed by hand: this
# MacBook had claude at ~/.local/bin/claude placed on 2026-08-29 and declared
# nowhere, and home-mini - built from the same flake - simply did not have it.
# Third instance in one day of the flake depending on something it did not
# install, after the Bitwarden cask and the OrbStack shell init.
#
# The PATH entry is the less obvious half and is why `claude` was "not found"
# rather than merely absent. On the MacBook ~/.local/bin is on PATH only because
# uv's installer happens to leave a ~/.local/bin/env for .zshrc to source - an
# accidental second source, exactly like the one that hid the OrbStack
# completions. home-mini has no such file, so the directory was not on PATH at
# all and installing the binary there would not have been enough.
{ config, lib, pkgs, ... }:
{
  options.claudeCode.install = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install Claude Code from Anthropic's official installer on activation.

      Deliberately imperative. nixpkgs lags the official releases, and on an
      agent box a stale agent is worse than an unmanaged one — so this runs the
      vendor installer rather than pinning a package.
    '';
  };

  config = {
    # Where the installer puts the binary. Declared for every machine: Debian's
    # stock ~/.profile added it conditionally and home-manager's generated one
    # does not, while macOS never adds it at all.
    home.sessionPath = [ "$HOME/.local/bin" ];

    # This activation script MUST NOT be able to fail. home-manager runs
    # activation under `set -eu` with `pipefail`, so a non-zero exit here aborts
    # every later step — which is exactly how a failed Homebrew cask left the
    # Mac half-configured on 2026-08-29. Hence the `|| echo` on the install and
    # the check-then-skip rather than an unconditional run.
    home.activation.claudeCode =
      lib.mkIf config.claudeCode.install (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -x "$HOME/.local/bin/claude" ]; then
          echo "claude-code: present at ~/.local/bin/claude, leaving alone"
        else
          echo "claude-code: installing from https://claude.ai/install.sh"
          # Both the pipe target and the installer's own PATH must be explicit.
          # home-manager's activation PATH is minimal, so letting `| bash`
          # resolve from it is what made the first attempt fail while the same
          # command succeeded by hand.
          $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c \
            'export PATH="${lib.makeBinPath [
                pkgs.curl pkgs.bash pkgs.coreutils pkgs.gnutar pkgs.gzip
                pkgs.gnugrep pkgs.gnused pkgs.which
              ]}:$PATH"; \
             curl -fsSL https://claude.ai/install.sh | bash' \
            || echo "claude-code: install FAILED — continuing activation" >&2
        fi
      '');
  };
}
