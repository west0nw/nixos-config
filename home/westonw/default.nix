{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Desktop environment
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./swaync.nix
    ./hyprlock.nix
    ./spicetify.nix
    ./wallpaper.nix
    ./vpn.nix

    # Applications with custom packaging or integration
    ./blender.nix
    ./codex.nix
    ./godot.nix
    ./opencode

    # Editor
    inputs.nixvim.homeModules.nixvim
    ./nixvim
  ];

  home.username = "westonw";
  home.homeDirectory = "/home/westonw";
  home.stateVersion = "25.11";

  # User packages
  home.packages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    cliphist
    grim
    slurp
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
    gh
    odin
    lean4
    python3
    uv

    # GUI apps
    thunar
    vesktop
    mission-center
    libreoffice

  ];

  # ChatGPT advertises itself as an HTTP handler, so keep OAuth links opening
  # in the browser rather than looping back into the app.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/opencode" = "ai.opencode.desktop.desktop";
      "x-scheme-handler/codex" = "chatgpt.desktop";
    };
  };

  # Shell
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#nullrunner";
      python = "python3";
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings.user = {
      name = "west0nw";
      email = "west0nw@pm.me";
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

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
