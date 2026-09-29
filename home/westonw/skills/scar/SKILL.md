---
name: scar
description: Access and maintain scar, Weston's general-purpose self-hosting NixOS laptop, over Tailscale. Use for SSH, service diagnostics, deployments, and self-hosted apps on scar.
---

# Scar

Scar is Weston's headless NixOS laptop for self-hosting. It currently hosts Simple
and a Minecraft server, but treat it as a general-purpose host rather than
assuming every task concerns those services. Its declarative configuration is
in `~/nixos-config/hosts/scar/`, `modules/roles/server.nix`,
`modules/services/`, and `home/westonw/server.nix` on nullrunner.

## Connect

- From nullrunner, use `ssh scar` (user `westonw`). The existing local SSH
  `Host scar` entry uses `tailscale --socket=/run/user/1000/tailscaled.sock nc`
  as its proxy. Use this alias so traffic goes over Tailscale; do not substitute
  a public address or assume the direct-Ethernet address is reachable remotely.
- For a one-off check: `ssh -o BatchMode=yes -o ConnectTimeout=8 scar 'hostname; id -un'`.
  Check the host identity before changing anything. Use `ssh scar` for an
  interactive session, or `ssh scar 'command'` for a bounded remote command.
- If SSH fails, check `tailscale --socket="${XDG_RUNTIME_DIR:-/run/user/1000}/tailscaled.sock" status`
  on nullrunner and inspect `ssh -G scar` for the configured proxy and user.
  Verify the target is online in the tailnet before troubleshooting sshd.
  The plain `tailscale status` command may query a different, inactive system
  daemon on this machine. On another client, first verify its own Tailscale
  connection and SSH configuration; the `scar` alias is specific to nullrunner.

## Work on the host

1. Inspect the relevant NixOS module and the live state before making changes.
   For example, `ssh scar 'systemctl --failed'` or
   `ssh scar 'systemctl status minecraft-server --no-pager'`. Discover the
   actual unit or container name for other services rather than guessing it.
2. Make lasting NixOS/Home Manager changes in the `nixos-config` repository,
   validate with `nix flake check`, and commit with `jj`. A rebuild of scar is
   needed to activate configuration changes; coordinate it with the user when
   a restart or service interruption is involved. Avoid treating live edits to
   generated configuration as the source of truth.
3. Minecraft configuration is in `modules/services/minecraft.nix`. Its world is
   in `/var/lib/minecraft`; stop the server before copying world data for a
   consistent backup. Do not assume Simple's deployment layout or credentials:
   inspect them on the host without printing or storing secrets in the repo.

Keep remote commands scoped to the requested task. Confirm the target and
effects before destructive operations, especially on service data or when
running commands with `sudo`.
