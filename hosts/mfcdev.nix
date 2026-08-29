# mfcdev — CT 119 on lab1, 10.73.42.156. Same build as devbox, plus Docker.
#
# This manages the *host* shell only. The real workspace is the `mfc-work`
# container, which shares a network namespace with a Tailscale container holding
# the employer tailnet — that isolation is the whole design, and pulling it into
# home-manager would mean putting the employer tailnet on the host, which is
# exactly what was rejected. The container stays a Dockerfile.
{ ... }:
{
  imports = [ ../modules/home/linux-dev.nix ];
}
