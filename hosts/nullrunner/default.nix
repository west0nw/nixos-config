{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./wifi.nix
    ../../modules/common/base.nix
    ../../modules/common/user-westonw.nix
    ../../modules/roles/desktop.nix
  ];

  # Keep shared MCP defaults declarative without making Codex's writable user
  # preferences immutable. The user profile supplies both executables.
  environment.etc."codex/config.toml".source =
    (pkgs.formats.toml { }).generate "codex-system-config"
      {
        mcp_servers.blender = {
          command = "/etc/profiles/per-user/westonw/bin/blender-mcp";
          enabled = true;
          env = {
            BLENDER_MCP_HOST = "localhost";
            BLENDER_MCP_PORT = "9876";
            BLENDER_PATH = "/etc/profiles/per-user/westonw/bin/blender";
          };
        };
      };

  # Use the official binary to avoid memory-heavy local Godot builds.
  nixpkgs.overlays = [
    (final: _: { godot = import ../../packages/godot.nix { pkgs = final; }; })
  ];

  # Use the latest kernel - recommended for AI 300 series
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Sleev downloads its gateway as a conventional dynamically linked Linux binary.
  programs.nix-ld.enable = true;

  # Keep large parallel builds from exhausting RAM and taking down the desktop session.
  zramSwap.enable = true;
  nix.settings.cores = 8;
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;

  networking.hostName = "nullrunner";

  # Harbor and Pier require the Docker CLI and Compose semantics for local
  # benchmark environments. Keep the daemon off until a benchmark requests it.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # Load amdgpu early for both GPUs
  hardware.amdgpu.initrd.enable = true;

  # User
  users.users.westonw.extraGroups = [
    "docker"
    "video"
    "lp"
    "plugdev"
  ];

  # Don't change this ever
  system.stateVersion = "25.11";
}
