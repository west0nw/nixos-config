{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  opencode = inputs.nixpkgs-opencode.packages.${pkgs.system}.opencode;
  opencodeVersion = builtins.head (lib.splitString "+" opencode.version);

  # The upstream desktop flake currently fails its Bun version check.
  opencodeDesktop = pkgs.appimageTools.wrapType2 {
    pname = "opencode-desktop";
    version = opencodeVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${opencodeVersion}/opencode-desktop-linux-x86_64.AppImage";
      hash = "sha256-DIDIQ3xK4HoH1ibrAEiye/AOGWiHjpBTibR11ZdbpOE=";
    };
  };

  opencodeDesktopWayland = pkgs.symlinkJoin {
    name = "opencode-desktop-wayland";
    paths = [ opencodeDesktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode-desktop \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-features=WaylandWindowDecorations" \
        --add-flags "--enable-wayland-ime=true"
    '';
  };

  godotWayland = pkgs.symlinkJoin {
    name = "godot-wayland";
    paths = [ pkgs.godot ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/godot4 \
        --set SDL_VIDEODRIVER wayland \
        --add-flags "--display-driver wayland"
    '';
  };
in
{
  imports = [
    # Desktop environment (Phase 5)
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./swaync.nix
    ./hyprlock.nix
    ./spicetify.nix

    # Editor (Phase 6)
    inputs.nixvim.homeModules.nixvim
    ./nixvim
  ];

  home.username = "westonw";
  home.homeDirectory = "/home/westonw";
  home.stateVersion = "25.11";

  # User packages (moved from system configuration)
  home.packages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    cliphist
    grim
    slurp
    swww
    brightnessctl
    hyprshot

    # Audio
    pavucontrol
    playerctl

    # CLI tools
    btop
    curl
    wget
    unzip
    jq
    odin
    godotWayland

    # GUI apps
    thunar
    vesktop
    mission-center
    blender
    libreoffice
    opencodeDesktopWayland

    # Coding agent
    opencode
    codex
  ];

  # OpenCode is updated through the flake input, never its curl-based self-updater.
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
  };

  xdg.desktopEntries."org.godotengine.Godot4.6" = {
    name = "Godot Engine 4.6";
    genericName = "Libre game engine";
    comment = "Multi-platform 2D and 3D game engine with a feature-rich editor";
    exec = "godot4 --display-driver wayland %f";
    icon = "godot";
    terminal = false;
    type = "Application";
    mimeType = [ "application/x-godot-project" ];
    categories = [
      "Development"
      "IDE"
    ];
  };

  xdg.desktopEntries."ai.opencode.desktop" = {
    name = "OpenCode";
    comment = "AI coding agent desktop client";
    exec = "opencode-desktop %U";
    icon = "${inputs.nixpkgs-opencode}/packages/desktop/icons/prod/128x128@2x.png";
    terminal = false;
    type = "Application";
    categories = [ "Development" ];
  };

  # Shell
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs  = "sudo nixos-rebuild switch --flake ~/nixos-config#nullrunner";
      nuo  = "nix flake update nixpkgs-opencode --flake ~/nixos-config";
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings.user = {
      name = "Weston-Wallace";
      email = "weston.wallace@outlook.com";
    };
  };

  # Ghostty terminal (Stylix handles theming)
  programs.ghostty = {
    enable = true;
    settings = {
      cursor-style = "block";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;
      background-opacity = "0.85";
      font-feature = "-calt";
    };
  };

  # Vivaldi Browser
  programs.vivaldi = {
    enable = true;
    commandLineArgs = [
      "--ozone-platform=wayland"
    ];
  };

  # Disable hyprpaper so swww can manage wallpapers
  services.hyprpaper.enable = lib.mkForce false;

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
