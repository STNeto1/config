{
  lib,
  pkgs,
  ...
}: {
  imports =
    [
      ../../modules/common
      ../../modules/desktop
    ]
    ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
  };

  users.users.germano = {
    isNormalUser = true;
    description = "Germano";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  # Set this to the NixOS release used for the first installation.
  system.stateVersion = "25.11";
}
