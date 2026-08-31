# The SSH client config every machine shares.
#
# Split by what can be published, not by what is convenient. **nix-config is a
# public repository**, and deliberately so: `tools/deploy-linux.sh` works
# because the dev boxes hold no credentials and fetch the flake by URL. So
# anything naming employer or client infrastructure, or a real internet-facing
# host, stays out of here and lives in `~/.ssh/config.d/` instead - outside git
# for the same reason `~/.secrets.zsh` is.
#
# The include comes FIRST because ssh_config is first-match-wins, so a local
# entry always beats anything below it. A glob matching nothing is not an error.
#
# What is kept here is the lab: RFC1918 addresses reachable only over the
# tailnet, plus the comments explaining ForwardAgent and ControlMaster - which
# are the part actually worth carrying to a new machine, having been learned the
# expensive way.
{ lib, ... }:
let
  # devbox and mfcdev are configured identically, for identical reasons. Written
  # once here rather than twice, which is how the hand-maintained file had it.
  #
  # A function so the whole block is one string literal: Nix strips the common
  # indentation of a '' literal, so interpolating a separate body would flatten
  # these options to column 0 and make them read as global directives. ssh does
  # not care, but anyone opening the file does.
  devBox = name: ip: ''
    Host ${name}
        HostName ${ip}
        User pahenn
        # Plain agent forwarding, to wherever sshd wants to put the socket. A login
        # then runs `agent-relay` on the box, which republishes it at the fixed path
        # ~/agent/agent.sock that mfcdev bind-mounts into the workspace container.
        #
        # This replaced a RemoteForward straight to that fixed path, which had each
        # connection unlink the previous socket and delete it on exit - breaking any
        # other live session silently. It is also the only form Blink on iOS can do,
        # so the Mac and the phone now behave identically.
        ForwardAgent yes
        # Share ONE connection per box. Without this every `ssh mfcdev 'cmd'` opens
        # its own, and because sshd has StreamLocalBindUnlink yes for the fixed agent
        # path, each one unlinks the interactive session's socket, binds its own, and
        # removes it again on exit - leaving the long-lived session with a forward
        # that nothing can reach. That is not hypothetical: it silently broke 7 repo
        # clones on 2026-08-30 while the same clone by hand worked fine.
        # Multiplexed, the master owns the forward and every later invocation rides it.
        ControlMaster auto
        ControlPath ~/.ssh/control/%C
        ControlPersist 10m
  '';
in
{
  home.file.".ssh/config".text = lib.mkMerge [
    (lib.mkOrder 100 ''
      # Managed by nix-config (modules/home/ssh.nix).
      # Edits here are silently replaced on the next activation - put local or
      # private entries in ~/.ssh/config.d/*.conf, which is included first and
      # therefore wins.
      Include ~/.ssh/config.d/*.conf
    '')

    # Host blocks last: any option written outside a Host block belongs to the
    # global context only until the first one, so a stray global directive
    # appended after these would silently attach itself to the last host.
    (lib.mkOrder 500 ''

      # Remote dev boxes on lab1 (CT 118 / 119), reached via the tailnet subnet
      # router. No IdentityFile: the key comes from the Vaultwarden agent, and
      # neither box holds a private key of its own. Git over SSH there
      # authenticates with that forwarded agent.
      #
      # Needs `StreamLocalBindUnlink yes` in sshd_config on the box, or the
      # second login cannot rebind the stale socket and silently gets no agent.
      ${devBox "devbox" "10.73.42.140"}
      ${devBox "mfcdev" "10.73.42.156"}
      Host lab1
        HostName 10.73.42.5
        User root
        IdentityFile ~/.ssh/id_ed25519

      Host spark
        HostName 10.73.42.20
        User pahenn
        IdentityFile ~/.ssh/id_ed25519
    '')
  ];

  # The include above needs somewhere to point.
  home.file.".ssh/config.d/.keep".text = "";

  # ControlPath's parent, which ssh does NOT create. Without it multiplexing
  # fails on a freshly built machine with a message about the socket rather
  # than about the directory, and the first symptom is a connection per command
  # again - the exact thing ControlMaster is there to prevent.
  home.file.".ssh/control/.keep".text = "";
}
