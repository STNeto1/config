# Linuxbox

This directory defines the NixOS host used as the remote Pi and Herdr worker.
The flake output is `nixos`.

## Host identity

- Hostname: `nixos`
- Architecture: `x86_64-linux`
- User: `germano`
- Tailscale DNS: `nixos.tail63cf69.ts.net`
- NixOS flake: `darwin#nixos`
- Remote Herdr session: `agents`

The Mac repository and GitHub `main` branch are the source of truth. Do not edit
the synchronized files directly on linuxbox.

## Configuration files

System configuration in this repository:

- `darwin/flake.nix`
- `darwin/hosts/nixos/default.nix`
- `darwin/hosts/nixos/hardware-configuration.nix`
- `darwin/modules/common/default.nix`

Runtime locations on linuxbox:

- Pulled repository: `/home/germano/.local/share/config-repo`
- Herdr configuration: `/home/germano/.config/herdr/config.toml`
- Herdr named-session state: `/home/germano/.config/herdr/sessions/agents/`
- Fish sessionizer: `/home/germano/.config/fish/functions/herdr-sessionizer.fish`
- Pi configuration: `/home/germano/.pi/agent/`

The Herdr configuration and Fish sessionizer are symlinks into the pulled
repository. Herdr sockets, logs, sessions, and Pi credentials remain local and
are not synchronized.

## Bootstrap a fresh installation

A fresh installation initially has only:

```text
/etc/nixos/configuration.nix
/etc/nixos/hardware-configuration.nix
```

If Ghostty's terminal type is not yet available, use a compatible terminal type
for the bootstrap shell:

```sh
export TERM=xterm-256color
```

Create `/etc/nixos/bootstrap-remote.nix`:

```nix
{ ... }:

{
  imports = [ ./configuration.nix ];

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # Temporary bootstrap access. The final flake disables root SSH.
      PermitRootLogin = "yes";
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0JxtM90bKT645dVACk2N0q7xqkDsafFEw83azcGuz1 gfreitasneto18@gmail.com"
  ];
}
```

Activate the temporary configuration and enroll the machine in Tailscale:

```sh
NIXOS_CONFIG=/etc/nixos/bootstrap-remote.nix nixos-rebuild switch
tailscale up
tailscale ip -4
```

From the Mac repository root, retrieve and stage the machine-generated hardware
configuration:

```sh
scp root@<TAILSCALE-IP>:/etc/nixos/hardware-configuration.nix \
  darwin/hosts/nixos/hardware-configuration.nix

git add darwin/hosts/nixos/hardware-configuration.nix
nix flake check ./darwin --no-build --all-systems
```

Perform the first flake deployment while temporary root access is available:

```sh
nix run nixpkgs#nixos-rebuild -- switch \
  --flake ./darwin#nixos \
  --target-host root@<TAILSCALE-IP> \
  --build-host root@<TAILSCALE-IP>
```

The final configuration creates `germano`, authorizes the Mac SSH key, permits
passwordless sudo for remote rebuilds, allows SSH only through Tailscale, and
disables root SSH.

## Normal NixOS deployments

Validate locally before deployment:

```sh
nix flake check ./darwin --no-build --all-systems
```

Deploy from the Mac:

```sh
nix run nixpkgs#nixos-rebuild -- switch \
  --flake ./darwin#nixos \
  --target-host germano@nixos.tail63cf69.ts.net \
  --build-host germano@nixos.tail63cf69.ts.net \
  --elevate=sudo
```

The GitHub synchronization service does not run `nixos-rebuild`. System changes
must be validated and deployed explicitly with this command.

## Pull-only GitHub synchronization

`config-sync.timer` first runs one minute after boot and then every five
minutes. It performs a fast-forward-only pull from:

```text
https://github.com/STNeto1/config.git
```

The checkout has no GitHub credentials and its push URL is set to `disabled`.
Linuxbox cannot push through this checkout.

After a successful pull, the service links:

```text
~/.config/herdr/config.toml
  -> ~/.local/share/config-repo/herdr/config.toml

~/.config/fish/functions/herdr-sessionizer.fish
  -> ~/.local/share/config-repo/fish/functions/herdr-sessionizer.fish
```

It then reloads the running `agents` Herdr server when present.

Trigger synchronization manually:

```sh
sudo systemctl start config-sync.service
```

Inspect synchronization:

```sh
systemctl status config-sync.service
systemctl status config-sync.timer
journalctl -u config-sync.service

git -C ~/.local/share/config-repo remote -v
git -C ~/.local/share/config-repo status --short --branch
```

The expected remote configuration is:

```text
origin  https://github.com/STNeto1/config.git (fetch)
origin  disabled                            (push)
```

The normal update flow is:

1. Edit configuration on the Mac.
2. Commit and push to GitHub `main`.
3. Wait up to five minutes or start `config-sync.service` manually.
4. Use the explicit NixOS deployment command if system configuration changed.

## Pi and Herdr initialization

The NixOS configuration installs Pi, Herdr, Git, Fish, and the shared CLI tools.
Initialize user-level Pi and Herdr state once as `germano`:

```sh
mkdir -p ~/.pi/agent/extensions
herdr integration install pi
pi install npm:@ogulcancelik/pi-herdr
pi install npm:pi-subagents
pi
```

Use `/login` inside Pi to configure provider authentication. Pi credentials are
machine-local and must not be committed to GitHub.

Verify the integration:

```sh
herdr integration status
pi list
```

## Projects and the sessionizer

Remote projects are expected under:

```text
/home/germano/Code
/home/germano/RSR
/home/germano/Aldea
```

Clone projects on linuxbox so builds and agents use its local filesystem:

```sh
mkdir -p ~/Code
cd ~/Code
git clone <repository-url>
```

From the Mac, launch the remote project picker:

```fish
herdr-sessionizer nixos
```

The function checks SSH, starts the named `agents` Herdr server when necessary,
lists remote projects through local `fzf`, focuses or creates the matching
workspace, and attaches the local Herdr thin client.

Direct attachment without the sessionizer:

```sh
herdr --remote ssh://germano@nixos.tail63cf69.ts.net --session agents
```

Optional Fish overrides:

```fish
set -gx HERDR_REMOTE_TARGET germano@nixos.tail63cf69.ts.net
set -gx HERDR_REMOTE_SESSION agents
set -gx HERDR_REMOTE_SEARCH_PATHS /home/germano/Code /srv/projects
```

## Verification

```sh
ssh germano@nixos.tail63cf69.ts.net
sudo -n true
infocmp xterm-ghostty
systemctl is-active sshd tailscaled config-sync.timer
command -v git pi herdr
herdr --session agents status
```

Root SSH should fail after the final flake is active:

```sh
ssh root@nixos.tail63cf69.ts.net
```

## Recovery

If synchronization fails because the checkout was edited on linuxbox, discard
those local edits and pull again:

```sh
sudo -u germano git -C /home/germano/.local/share/config-repo restore .
sudo systemctl start config-sync.service
```

If the checkout is damaged, recreate it:

```sh
sudo systemctl stop config-sync.timer
sudo rm -rf /home/germano/.local/share/config-repo
sudo systemctl start config-sync.service
sudo systemctl start config-sync.timer
```

If Herdr does not reload the synchronized configuration:

```sh
herdr --session agents server reload-config
herdr --session agents status
```
