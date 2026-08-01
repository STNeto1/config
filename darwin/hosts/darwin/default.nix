{
  pkgs,
  self,
  ...
}: {
  imports = [
    ../../modules/common
    ../../modules/desktop
  ];

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
  };

  environment.systemPackages = with pkgs; [
    rubyPackages.cocoapods
    raycast
    orbstack
    # iterm2
    # rectangle
    ngrok
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.blex-mono
  ];

  # Nix is managed separately on this Mac.
  nix.enable = false;

  /*
  system.defaults = {
    dock.autohide = true;
    dock.mru-spaces = false;
    finder.AppleShowAllExtensions = true;
    finder.FXPreferredViewStyle = "clmv";
    loginwindow.LoginwindowText = "nixcademy.com";
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPasswordDelay = 10;
  };
  */

  system.configurationRevision = self.rev or self.dirtyRev or null;
  security.pam.services.sudo_local.touchIdAuth = true;

  # Do not change this unless the nix-darwin release notes require it.
  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
