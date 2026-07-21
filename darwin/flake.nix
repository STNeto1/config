{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
  }: let
    configuration = {pkgs, ...}: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [
        pkgs.vim
        pkgs.neovim
        pkgs.opencode
        pkgs.codex
        pkgs.claude-code
        # pkgs.t3code
        # pkgs.cursor-cli

        pkgs.gh
        pkgs.atlas
        pkgs.libpq
        pkgs.terraform
        pkgs.go-task
        pkgs.templ
        pkgs.air

        pkgs.rustup
        pkgs.go
        pkgs.nodejs_26
        pkgs.python313
        pkgs.pnpm
        # pkgs.beam28Packages.elixir_1_20
        # pkgs.beam28Packages.erlang
        pkgs.lua51Packages.tree-sitter-cli
        pkgs.rubyPackages.cocoapods
        # pkgs.postman

        # pkgs.duckdb
        # pkgs.btop
        # pkgs.postgresql

        # sr
        # pkgs.awscli2
        # pkgs.lens
        # pkgs.kubectl
        pkgs.jetbrains.datagrip

        pkgs.iterm2
        pkgs.fish
        pkgs.starship
        pkgs.fzf
        pkgs.ripgrep
        pkgs.zoxide
        pkgs.eza
        pkgs.lazygit
        pkgs.tmux
        pkgs.raycast
        # pkgs.rectangle
        pkgs.orbstack
      ];

      fonts.packages = with pkgs; [
        nerd-fonts.blex-mono
      ];
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
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
      8=
      */

      # Enable alternative shell support in nix-darwin.
      programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;
      security.pam.services.sudo_local.touchIdAuth = true;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (pkgs.lib.getName pkg) [
          "lens-desktop"
          "raycast"
          "datagrip"
          "orbstack"
          "claude-code"
          "postman"
          "cursor-cli"
          "terraform"
        ];
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
      modules = [configuration];
    };
  };
}
