{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/user-westonw.nix
    ../../modules/roles/desktop.nix
  ];

  # Nixpkgs has not yet packaged the 4.7.1 patch release. Use the official
  # binary because compiling Godot locally exceeds this machine's memory.
  nixpkgs.overlays = [
    (
      final: _:
      let
        version = "4.7.1";
      in
      {
        godot = final.stdenvNoCC.mkDerivation {
          pname = "godot-bin";
          inherit version;

          src = final.fetchurl {
            url = "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip";
            hash = "sha256-x/8U/ShHLI1PGTBD3jAnjc9+UkGh3PdWawLiet2qM7o=";
          };

          icon = final.fetchurl {
            url = "https://raw.githubusercontent.com/godotengine/godot/${version}-stable/misc/logo/icon.svg";
            hash = "sha256-FEOul0hCuBdl1bUOanKeu/Qeui6eUVqwkZ8upci49HU=";
          };

          nativeBuildInputs = with final; [
            autoPatchelfHook
            unzip
          ];

          buildInputs = [ final.glibc ];

          # The portable binary loads these by name, so autoPatchelf cannot detect them.
          runtimeDependencies = map final.lib.getLib (
            with final;
            [
              alsa-lib
              dbus
              fontconfig
              libdecor
              libGL
              libpulseaudio
              libx11
              libxcursor
              libxext
              libxfixes
              libxi
              libxinerama
              libxkbcommon
              libxrandr
              libxrender
              speechd-minimal
              udev
              vulkan-loader
              wayland
            ]
          );

          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/bin"
            unzip -p "$src" Godot_v${version}-stable_linux.x86_64 > "$out/bin/godot"
            chmod 0755 "$out/bin/godot"
            ln -s godot "$out/bin/godot4"

            install -Dm644 "$icon" \
              "$out/share/icons/hicolor/scalable/apps/godot.svg"

            runHook postInstall
          '';

          meta = {
            description = "Godot game engine, official prebuilt binary";
            homepage = "https://godotengine.org/";
            license = final.lib.licenses.mit;
            mainProgram = "godot";
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ final.lib.sourceTypes.binaryNativeCode ];
          };
        };
      }
    )
  ];

  # Use the latest kernel - recommended for AI 300 series
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Keep large parallel builds from exhausting RAM and taking down the desktop session.
  zramSwap.enable = true;
  nix.settings.cores = 8;
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;

  networking.hostName = "nullrunner";
  networking.networkmanager.enable = true;

  # Load amdgpu early for both GPUs
  hardware.amdgpu.initrd.enable = true;

  # User
  users.users.westonw.extraGroups = [
    "video"
    "lp"
    "plugdev"
  ];

  # Don't change this ever
  system.stateVersion = "25.11";
}
