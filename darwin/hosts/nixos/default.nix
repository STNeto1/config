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

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [22];

  users.users.germano = {
    isNormalUser = true;
    description = "Germano";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0JxtM90bKT645dVACk2N0q7xqkDsafFEw83azcGuz1 gfreitasneto18@gmail.com"
    ];
  };

  # Set this to the NixOS release used for the first installation.
  system.stateVersion = "25.11";
}
