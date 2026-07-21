# macOS configuration

## Setup

Clone the repository:

```sh
git clone git@github.com:STNeto1/config.git ~/.config
```

Bootstrap nix-darwin and apply the `simple` configuration:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/.config/darwin#simple
```

## Apply changes

Rebuild the system after changing the configuration:

```sh
sudo darwin-rebuild switch --flake ~/.config/darwin#simple
```
