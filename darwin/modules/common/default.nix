{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vim
    neovim
    # opencode
    codex
    claude-code
    pi-coding-agent
    # t3code
    # cursor-cli

    git
    gh
    atlas
    # libpq
    terraform
    # go-task
    # templ
    # air

    rustup
    go
    nodejs_26
    python313
    pnpm
    bun
    # beam28Packages.elixir_1_20
    # beam28Packages.erlang
    lua51Packages.tree-sitter-cli

    # duckdb
    # btop
    # postgresql

    awscli2
    kubectl
    tailscale

    fish
    starship
    fzf
    ripgrep
    zoxide
    eza
    lazygit
    tmux
    herdr
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.fish.enable = true;

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
      "ngrok"
      "tailscale"
      "obsidian"
      "slack"
    ];
}
