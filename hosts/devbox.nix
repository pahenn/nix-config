# devbox — CT 118 on lab1, 10.73.42.140. Debian 13 LXC, reached through the
# subnet router (CT 116); it runs no Tailscale of its own, so nothing about this
# box's network state can lock you out.
#
# Deliberately has no employer containers, no second tailnet and no employer
# credentials: personal work provably cannot reach employer infrastructure.
# Anything needing that lives on mfcdev.
#
# Docker itself is allowed (installed 2026-10-14, for local service containers
# such as maginox-vnext's Postgres). What the rule protects against is a path to
# the employer, and a database container is not one. Docker Engine is a system
# package from Docker's apt repo, as on mfcdev - home-manager cannot install it.
{ pkgs, ... }:
{
  imports = [ ../modules/home/linux-dev.nix ];

  # maginox-vnext pins Node 24 (`.nvmrc`); Nuxt 4.6 accepts ^22.22.3 or ^24.15.0.
  home.packages = [ pkgs.nodejs_24 ];
}
