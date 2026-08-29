# macOS settings that would otherwise be clicked in by hand on a new machine.
# Everything here is reversible — change the value and rebuild, or override it in
# System Settings and it will be reapplied on the next switch.
{ user, ... }:
{
  system.defaults = {
    NSGlobalDomain = {
      # Key repeat. The stock values are slow enough to be worth changing first
      # on any new Mac; these are near the fastest the sliders allow.
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # Hold a key to repeat it rather than opening the accent picker.
      ApplePressAndHoldEnabled = false;

      AppleShowAllExtensions = true;
      NSNavPanelExpandedStateForSaveMode = true;

      # Substitutions that corrupt code and shell snippets.
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";        # list view
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
    };

    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false;                   # stop spaces reordering themselves
    };

    screencapture = {
      location = "/Users/${user}/Screenshots";
      type = "png";
      disable-shadow = true;
    };

    CustomUserPreferences."com.apple.desktopservices" = {
      # Stop .DS_Store files being written to network shares and USB volumes.
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
  };
}
