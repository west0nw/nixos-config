{
  config,
  pkgs,
  lib,
  ...
}:

let
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
  home.packages = [
    blenderWithMcp
    blenderMcp
  ];

  xdg.configFile."blender/5.2/extensions/user_default/mcp" = {
    source = "${blenderMcpSource}/addon/blender_mcp_addon";
    recursive = true;
  };

  programs.opencode.settings.mcp.blender = {
    type = "local";
    command = [ "${blenderMcp}/bin/blender-mcp" ];
    enabled = true;
    environment = {
      BLENDER_MCP_HOST = "localhost";
      BLENDER_MCP_PORT = "9876";
      BLENDER_PATH = "${blenderWithMcp}/bin/blender";
    };
  };

}
