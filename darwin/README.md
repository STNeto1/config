# System configurations

This flake contains both macOS (`nix-darwin`) and NixOS configurations.

## Layout

- `modules/common/` — CLI packages and settings shared by macOS and NixOS
- `modules/desktop/` — desktop applications shared by macOS and NixOS
- `hosts/darwin/` — macOS-only packages and nix-darwin settings
- `hosts/nixos/` — NixOS host settings

## macOS

```sh
darwin-rebuild switch --flake .#simple
```

## NixOS

The default NixOS output is named `nixos` and targets `x86_64-linux`.
Before using it on a machine, copy that machine's generated hardware configuration:

```sh
cp /etc/nixos/hardware-configuration.nix hosts/nixos/hardware-configuration.nix
sudo nixos-rebuild switch --flake .#nixos
```

Change `networking.hostName`, the user settings, architecture, and
`system.stateVersion` to match the target machine. Keep the generated
`hardware-configuration.nix` host-specific.
