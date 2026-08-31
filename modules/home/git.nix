# Was ~/.gitconfig, hand-maintained and unmanaged.
{ config, ... }:
let
  # The Vaultwarden agent key. It already authenticates to GitHub, Forgejo, the
  # dev boxes and lab1; from 2026-08-30 it signs commits as well.
  #
  # Renamed 2026-08-31 from "m4 macbook", which described where it was generated
  # rather than what it is. Every Mac that unlocks the vault borrows this one key
  # - home-mini reached mfcdev with nothing added to any authorized_keys - so the
  # old name implied a per-device scheme that does not exist. "(shared)" is the
  # standing warning: revoking it cuts every Mac, both dev boxes, the container
  # and commit signing at once. The comment is cosmetic everywhere it lands;
  # ssh-keygen matches on key material, never on name.
  #
  # PUBLIC half only, which is the whole point: git's ssh signing goes through
  # the ordinary agent protocol, so the signature is produced inside the agent
  # on the Mac and no box needs the secret. That is what makes signing work on
  # devbox and mfcdev, which deliberately hold no keys.
  #
  # This replaced GPG key 3FCD60AD3C53CFA3, which lives only on the Mac and so
  # could not sign anywhere else - gpg --clearsign simply failed. Forwarding
  # gpg-agent was the obvious fix and the wrong one: it needs RemoteForward to a
  # fixed socket path, the design already rejected for the ssh agent because it
  # cannot survive two clients and Blink cannot forward to a unix socket at all.
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPbwozOF6xtJi6w1ralUkoSXPRIPxM2WSn7G1euqN/S pahenn vault key (shared)";
  email = "7787945+pahenn@users.noreply.github.com";
  gitDir = "${config.home.homeDirectory}/.config/git";
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    signing = {
      format = "ssh";
      key = "${gitDir}/signing-key.pub";
      signByDefault = true;
    };

    settings = {
      user = {
        name = "Patrick Hennessey";
        inherit email;
      };
      tag.gpgSign = true;
      pull.rebase = true;
      # Without this, `git log --show-signature` fails with a message about
      # your config rather than about the commit, which reads like a bad
      # signature and is not one.
      gpg.ssh.allowedSignersFile = "${gitDir}/allowed_signers";
    };
  };

  # Absolute paths above, not ~, so nothing depends on git's tilde handling.
  home.file.".config/git/signing-key.pub".text = "${signingKey}\n";
  home.file.".config/git/allowed_signers".text = "${email} ${signingKey}\n";
}
