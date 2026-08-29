# Mac Mini.
#
# Nothing machine-specific remains: the `tailscale` brew this used to add is now
# in the shared list in modules/darwin/homebrew.nix, because it turned out to be
# installed on the MacBook too. Both Macs therefore evaluate to the same closure.
{ ... }:
{
}
