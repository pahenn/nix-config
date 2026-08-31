# Mac Mini.
#
# This used to be empty, with a note that both Macs evaluated to the same
# closure. That is no longer true, and the one difference is deliberate.
{ ... }:
{
  # Remote Login, declared rather than toggled in System Settings.
  #
  # This machine is used remotely and nothing else about it is: it sits
  # somewhere else, is often the only Mac not in front of you, and until now
  # could not be reached at all - a problem could only be diagnosed by reading
  # commands out to whoever was standing next to it. devbox and mfcdev are
  # debuggable precisely because they answer on 22, and this is the same
  # argument.
  #
  # Scoped to this host on purpose. The MacBook stays `null` - macOS-managed,
  # which is off - because a laptop that follows you around has no equivalent
  # reason to listen, and "both Macs are identical" is a weaker property than
  # "neither listens unless it has a reason to".
  #
  # Access is still the vault key: this turns on sshd, it does not add an
  # authorized_keys entry. ~/.ssh/authorized_keys on this box has to carry the
  # same key the dev boxes do - see vaultwarden-ssh-agent.
  services.openssh.enable = true;
}
