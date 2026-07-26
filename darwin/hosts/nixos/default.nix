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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Support terminal types forwarded by modern clients such as Ghostty.
  environment.enableAllTerminfo = true;

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

  # Allow declarative rebuilds over SSH without provisioning a user password.
  security.sudo.wheelNeedsPassword = false;

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

  systemd.services.config-sync = {
    description = "Pull configuration from GitHub";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "germano";
      Group = "users";
    };
    path = [
      pkgs.coreutils
      pkgs.git
      pkgs.herdr
    ];
    script = ''
      set -eu

      repo=/home/germano/.local/share/config-repo
      install -d /home/germano/.local/share

      if [ ! -e "$repo" ]; then
        git clone --branch main --single-branch \
          https://github.com/STNeto1/config.git "$repo"
      elif [ ! -d "$repo/.git" ]; then
        echo "$repo exists but is not a Git repository" >&2
        exit 1
      else
        git -C "$repo" remote set-url origin \
          https://github.com/STNeto1/config.git
        git -C "$repo" pull --ff-only origin main
      fi

      # This checkout has no credentials and its explicit push URL is disabled.
      git -C "$repo" remote set-url --push origin disabled

      install -d /home/germano/.config/herdr
      install -d /home/germano/.config/fish/functions
      ln -sfn "$repo/herdr/config.toml" \
        /home/germano/.config/herdr/config.toml
      ln -sfn "$repo/fish/functions/herdr-sessionizer.fish" \
        /home/germano/.config/fish/functions/herdr-sessionizer.fish

      if [ -S /home/germano/.config/herdr/sessions/agents/herdr.sock ]; then
        herdr --session agents server reload-config || true
      fi
    '';
  };

  systemd.timers.config-sync = {
    description = "Periodically pull configuration from GitHub";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "5m";
      Unit = "config-sync.service";
    };
  };

  # Set this to the NixOS release used for the first installation.
  system.stateVersion = "26.05";
}
