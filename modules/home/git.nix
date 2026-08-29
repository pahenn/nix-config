# Was ~/.gitconfig, hand-maintained and unmanaged.
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    signing = {
      key = "3FCD60AD3C53CFA3";
      signByDefault = true;
    };

    settings = {
      user = {
        name = "Patrick Hennessey";
        email = "7787945+pahenn@users.noreply.github.com";
      };
      tag.gpgSign = true;
      pull.rebase = true;
    };
  };
}
