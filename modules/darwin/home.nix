# Hand the user environment to home-manager, so the Macs and the Linux boxes
# share modules/home rather than the Mac's shell being unmanaged.
{ inputs, user, ... }:
{
  # home-manager derives homeDirectory from here. Without it the darwin
  # integration hands it a null and evaluation fails. The account already
  # exists — this only describes it, it is not in users.knownUsers, so
  # nix-darwin will not try to create or modify it.
  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    # First switch will find real ~/.zshrc, ~/.zshenv and ~/.gitconfig in place
    # and refuse to clobber them without this. They are renamed to *.hm-bak.
    backupFileExtension = "hm-bak";

    extraSpecialArgs = { inherit inputs; };

    users.${user} = {
      imports = [
        ../home
        ../home/darwin.nix
      ];
    };
  };
}
