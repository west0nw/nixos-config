# NixOS configuration

Two NixOS hosts with integrated Home Manager: **nullrunner** (Framework 16 desktop)
and **scar** (headless ASUS server). The lock file pins every input. Updating one
application does not need to update the whole system.

Read [AGENTS.md](AGENTS.md) before editing. The
[September 2026 audit](docs/audit-2026-09-05.md) records the cleanup and remaining limits.

## Where to make a change

| Change | File |
| --- | --- |
| Add an ordinary desktop package | `home/westonw/default.nix` → `home.packages` |
| Configure an application | Its module under `home/westonw/`; import new modules in `default.nix` |
| ChatGPT/Codex desktop and Codex CLI | `home/westonw/codex.nix` |
| OpenCode, Sleev, skills, MCP settings | `home/westonw/opencode/default.nix` |
| Blender binary, addon, and MCP server | `home/westonw/blender.nix` |
| Godot launcher / binary packaging | `home/westonw/godot.nix` / `packages/godot.nix` |
| VPN startup, VPN toggle, torrent interface | `home/westonw/vpn.nix` and `home/westonw/scripts/proton-vpn-*.sh` |
| Wi-Fi / Bluetooth menus | `home/westonw/scripts/waybar-*-menu.sh` |
| Laptop Wi-Fi driver workaround and diagnostics | `hosts/nullrunner/wifi.nix` |
| Panel layout and appearance | `home/westonw/waybar.nix` |
| Shortcuts, monitors, window rules | `home/westonw/hyprland.nix` |
| Wallpaper startup and selection | `home/westonw/wallpaper.nix` |
| Default wallpaper, fonts, system theme | `modules/roles/desktop.nix` |
| Locking and idle behavior | `home/westonw/hyprlock.nix` |
| Editor plugins, language servers, formatters | `home/westonw/nixvim/` |
| Shared system defaults / host hardware policy | `modules/common/` / `hosts/<host>/default.nix` |
| Server services | `modules/services/` and `hosts/scar/default.nix` |

Prefer an existing Home Manager or NixOS application module when it supports the
needed settings. Use a plain package entry when no configuration is needed. Keep
binary packaging, launch flags, icons, and related integrations together; explain
why each workaround exists. Do not replace a working binary with a source build
without checking resource requirements and cache availability.

## Validate and apply

Use Jujutsu for version control. Start with `jj status` to identify existing work.

```bash
# Optional shell with pinned nixfmt, ShellCheck, Node, Python, jj, and ripgrep
nix develop

# Format Nix sources; generated hardware files are excluded
nix fmt
nix fmt -- --check

# Evaluate both hosts, lint shell scripts, check plugin syntax, run regression tests
nix flake check

# Required for package/launcher changes; builds but does not activate anything
nix build --no-link \
  .#nixosConfigurations.nullrunner.config.home-manager.users.westonw.home.activationPackage

# Review only this task's changes before committing
jj diff
jj commit -m "Describe the completed change"
```

`nix flake check` does not build or boot an entire NixOS system. To inspect a larger
build first, use `nix build --dry-run --no-link` with the same attribute. Agents do
not run system switches. The user applies desktop changes with `nrs`.

After changes to PAM, test password and fingerprint authentication while keeping
the existing session open. After changing session startup, verify a fresh login;
reloading Hyprland does not rerun `exec-once` commands.

Do not edit generated files in `~/.config/` to fix a declaratively managed setting.
Home Manager will replace them. Never change either host's `stateVersion` as part
of an update.

## Update applications without broad system churn

| Application | Update mechanism |
| --- | --- |
| Ordinary nixpkgs package | Update `nixpkgs` deliberately; this affects the whole system |
| Codex CLI | `nix flake update nixpkgs-codex` |
| ChatGPT/Codex desktop | `nix flake update llm-agents` |
| OpenCode CLI + desktop | Change the release tag in `flake.nix`, update `nixpkgs-opencode`, then prefetch the matching AppImage and update its hash |
| Sleev CLI | Update the version, tarball URL, and hash in `home/westonw/opencode/default.nix` |
| Godot | Update `packages/godot.nix` version and hashes, then the launcher name in `home/westonw/godot.nix` |
| Blender | Update the archive URL/hash and version-dependent library/Python/addon paths in `home/westonw/blender.nix` |

For OpenCode, follow the complete procedure in [AGENTS.md](AGENTS.md#opencode-packaging).
Its exact release tag does not advance with `nix flake update` alone. The former
`nuo` alias was removed because it suggested an upgrade while leaving the release
unchanged. Nix-owned programs should not update their own immutable executables.

Keep the lock file changes with the configuration change. Avoid updating every
input while diagnosing an unrelated problem: it adds variables to the diagnosis.

## Troubleshooting

### Blender MCP connection

NixOS configures the Blender MCP server for Codex in `/etc/codex/config.toml`,
while Home Manager configures it for OpenCode and installs the shared server from
`home/westonw/blender.nix`. Codex's `~/.codex/config.toml` stays writable so the
desktop model and reasoning selectors can persist changes. Start Blender normally
before asking either agent to use its tools; the addon listens on `localhost:9876`.

### Ember Linear connection

Home Manager provides the Ember checkout's `.codex/config.toml` from
`home/westonw/codex.nix`. After applying the configuration, authenticate once:

```bash
cd ~/coding/web/ember_lighting
codex mcp login linear_ember
```

Select **Ember** on Linear's authorization screen, then restart the Codex task
to load its tools. The existing Proxy plugin connection is separate. Credentials
are stored by Codex outside this repository. Project configuration requires a
trusted checkout; if the checkout moves, update its Home Manager target path.

### Wi-Fi and VPN

Start by distinguishing the Wi-Fi link, internet connectivity, and VPN tunnel:

```bash
nmcli general status
nmcli device status
ip -brief link
iw dev wlp191s0 link
iw dev wlp191s0 station dump
iw dev wlp191s0 get power_save
journalctl -b -u NetworkManager --since '15 minutes ago'
journalctl -b -k --since '15 minutes ago'
journalctl -b -u systemd-suspend.service -u systemd-logind --since '15 minutes ago'
```

NetworkManager uses `INFO` logging on nullrunner so connection transitions are
available after a failure. Proton's log is at
`~/.cache/Proton/VPN/logs/vpn-app.log`; inspect locally and redact account/network
information before sharing logs. The Proton GUI running does not prove a VPN tunnel
is connected. The qBittorrent interface remains `proton0`; verify that interface
against an actual VPN connection before using torrents.

Nullrunner has a temporary single-link workaround for the MT7925's silent Wi-Fi 7
MLO stall. [The investigation](docs/wifi-2026-09-05.md) records the measured
symptoms, scope, activation checks, and removal procedure. Restricting a saved
profile to 5 GHz did **not** disable MLO on this system. Do not treat signal bars
or a high negotiated link rate as proof that packets are flowing. Compare latency
to the local gateway (shown by `nmcli -g IP4.GATEWAY device show wlp191s0`) with
latency to the internet, and record whether a VPN is actually active.

The Wi-Fi menu shows each SSID once, prioritizing a connected access point and then
signal strength. NetworkManager chooses the matching connection/access point.
Select **Open nmtui** for connection management beyond the menu, such as enterprise
or hidden networks. The previous N1/N2 labels were internal menu keys, not network
names or band indicators.

### Applications and desktop services

```bash
# Start an app from a terminal to capture the actual launch error
command -v opencode-desktop chatgpt godot4 blender bwrap
hyprctl configerrors
hyprctl clients -j
systemctl --user --failed
journalctl --user -b -u waybar -u hypridle -u awww
sleev gateway status
```

For blurry apps, inspect the client's `xwayland` flag and fix the app-specific
backend. Preserve Vivaldi's HTTP/HTTPS defaults: the ChatGPT desktop entry otherwise
captures browser sign-in URLs.

Waybar, hypridle, and awww are owned by systemd user services. Do not also add them
to Hyprland `exec-once`. The wallpaper service waits for its socket and uses the
same default image as Stylix; the switcher discovers committed images from the
Nix store rather than relying on a checkout at `~/nixos-config`.

Sleev is enabled and was healthy during the audit. If it becomes unavailable,
OpenCode's configured local route cannot serve requests. Diagnose the gateway first;
the documented switch in `opencode/default.nix` can disable routing if appropriate.
Authentication and gateway state stay outside this repository.

### Scar readiness

Scar evaluates, but its hardware file is a placeholder. It is not ready to deploy
until the target machine has a generated hardware configuration, account/SSH access,
and Minecraft whitelist entries. Do not replace its hardware file from nullrunner.
