# Starship is read into the store at eval time rather than pointed at a checkout,
# so the prompt does not depend on this repo living at any particular path.
{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}
