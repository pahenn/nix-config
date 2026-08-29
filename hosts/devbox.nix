# devbox — CT 118 on lab1, 10.73.42.140. Debian 13 LXC, reached through the
# subnet router (CT 116); it runs no Tailscale of its own, so nothing about this
# box's network state can lock you out.
#
# Deliberately has no Docker, no second tailnet and no employer credentials:
# personal work provably cannot reach employer infrastructure. Anything needing
# that lives on mfcdev.
{ ... }:
{
  imports = [ ../modules/home/linux-dev.nix ];
}
