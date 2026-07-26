{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  codex = inputs.nixpkgs-codex.legacyPackages.${pkgs.system}.codex;
  opencode = inputs.nixpkgs-opencode.packages.${pkgs.system}.opencode;
  opencodeVersion = builtins.head (lib.splitString "+" opencode.version);
  sleevEnabled = true;
  sleev = pkgs.stdenvNoCC.mkDerivation {
    pname = "sleev";
    version = "1.6.7";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/sleev-linux-x64/-/sleev-linux-x64-1.6.7.tgz";
      hash = "sha256-ZanhuXZpM/TNvoJzFaRM7oKvS0XE3HlkMM4BBqjTyFE=";
    };

    sourceRoot = "package";

    installPhase = ''
      runHook preInstall

      install -Dm755 bin/sleev $out/bin/sleev

      runHook postInstall
    '';
  };
  blender =
    let
      runtimeLibs = with pkgs; [
        stdenv.cc.cc.lib
        alsa-lib
        dbus
        libjack2
        libpulseaudio
        libglvnd
        libice
        libsm
        libx11
        libxext
        libxfixes
        libxi
        libxkbcommon
        libxrender
        wayland
      ];
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "blender-bin";
      version = "5.2.0";

      # download.blender.org uses a Cloudflare browser challenge; use an official mirror.
      src = pkgs.fetchurl {
        url = "https://mirrors.ocf.berkeley.edu/blender/release/Blender5.2/blender-5.2.0-linux-x64.tar.xz";
        hash = "sha256-lvbBgaMPSVBgeDnchNQqNUslDYoCMbCYtZt7xpw1HEg=";
      };

      nativeBuildInputs = with pkgs; [
        makeWrapper
        patchelf
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p $out/{bin,libexec}
        cp -a . $out/libexec/blender

        patchelf \
          --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
          $out/libexec/blender/blender
        patchelf \
          --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
          $out/libexec/blender/5.2/python/bin/python3.13

        makeWrapper $out/libexec/blender/blender $out/bin/blender \
          --prefix LD_LIBRARY_PATH : \
            "$out/libexec/blender/lib:${lib.makeLibraryPath runtimeLibs}"

        install -Dm644 blender.desktop $out/share/applications/blender.desktop
        install -Dm644 blender.svg \
          $out/share/icons/hicolor/scalable/apps/blender.svg

        runHook postInstall
      '';

      dontStrip = true;
    };

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

  blenderMcpSource = pkgs.fetchzip {
    url = "https://projects.blender.org/lab/blender_mcp/archive/v1.0.0.tar.gz";
    hash = "sha256-nt+sHozi+epJdu6GXcWGd33C9uewN+Ao8WP9Y2upPQc=";
  };

  blenderMcp = pkgs.python3Packages.buildPythonApplication {
    pname = "blender-mcp";
    version = "1.0.0";
    pyproject = true;
    src = "${blenderMcpSource}/mcp";
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = with pkgs.python3Packages; [
      docutils
      mcp
      pyyaml
    ];
    pythonImportsCheck = [ "blmcp" ];
  };

  blenderMcpEnable = pkgs.writeText "enable-blender-mcp.py" ''
    import addon_utils

    addon_utils.enable("bl_ext.user_default.mcp", default_set=True, persistent=True)
  '';

  blenderWithMcp = pkgs.symlinkJoin {
    name = "blender-with-mcp";
    paths = [ blender ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/blender \
        --add-flags "--online-mode" \
        --add-flags "--python ${blenderMcpEnable}"
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
    gh
    odin
    godotWayland

    # GUI apps
    thunar
    vesktop
    mission-center
    blenderWithMcp
    libreoffice
    opencodeDesktopWayland

    # Coding agent
    opencode
    codex
    sleev
  ];

  # OpenCode is updated through the flake input, never its curl-based self-updater.
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON (
    {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = false;
      agent.explore = {
        model = "openai/gpt-5.6-terra";
        variant = "low";
      };
      mcp.blender = {
        type = "local";
        command = [ "${blenderMcp}/bin/blender-mcp" ];
        enabled = true;
        env = {
          BLENDER_MCP_HOST = "localhost";
          BLENDER_MCP_PORT = "9876";
          BLENDER_PATH = "${blenderWithMcp}/bin/blender";
        };
      };
    }
    // lib.optionalAttrs sleevEnabled {
      compaction.prune = false;
      provider.openai.options = {
        baseURL = "http://127.0.0.1:17321";
        headers = {
          sleeve-provider = "codex";
          sleeve-harness = "opencode";
        };
      };
    }
  );

  xdg.configFile."blender/5.2/extensions/user_default/mcp" = {
    source = "${blenderMcpSource}/addon/blender_mcp_addon";
    recursive = true;
  };

  xdg.configFile."opencode/AGENTS.md".source = ./opencode/AGENTS.md;

  xdg.desktopEntries."org.godotengine.Godot4.7" = {
    name = "Godot Engine 4.7.1";
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
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#nullrunner";
      nuo = "nix flake update nixpkgs-opencode --flake ~/nixos-config";
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

  # Disable hyprpaper so swww can manage wallpapers
  services.hyprpaper.enable = lib.mkForce false;

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
