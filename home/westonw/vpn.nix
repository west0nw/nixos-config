{
  config,
  pkgs,
  lib,
  ...
}:

let
  vpnToggle = pkgs.writeShellApplication {
    name = "proton-vpn-toggle";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      procps
      coreutils
      proton-vpn
    ];
    text = builtins.readFile ./scripts/proton-vpn-toggle.sh;
  };
  protonVpnAutostart = pkgs.writeShellApplication {
    name = "proton-vpn-autostart";
    runtimeInputs = with pkgs; [
      jq
      coreutils
      proton-vpn
    ];
    text = builtins.readFile ./scripts/proton-vpn-autostart.sh;
  };
in
{
  home.packages = with pkgs; [
    proton-vpn
    qbittorrent
  ];

  wayland.windowManager.hyprland.settings = {
    vpn._var = "${vpnToggle}/bin/proton-vpn-toggle";
  };
  wayland.windowManager.hyprland.extraConfig = ''
    hl.on("hyprland.start", function()
      hl.exec_cmd("${protonVpnAutostart}/bin/proton-vpn-autostart")
    end)
  '';

  # The client must stay bound to the VPN interface, including when the VPN is down.
  xdg.configFile."qBittorrent/qBittorrent.conf".text = ''
    [BitTorrent]
    Session\InterfaceName=proton0

    [Preferences]
    General\ConfirmOnExit=true
  '';
}
