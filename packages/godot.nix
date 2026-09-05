{ pkgs }:

let
  version = "4.7.1";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "godot-bin";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip";
    hash = "sha256-x/8U/ShHLI1PGTBD3jAnjc9+UkGh3PdWawLiet2qM7o=";
  };

  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/godotengine/godot/${version}-stable/misc/logo/icon.svg";
    hash = "sha256-FEOul0hCuBdl1bUOanKeu/Qeui6eUVqwkZ8upci49HU=";
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    unzip
  ];

  buildInputs = [ pkgs.glibc ];

  # The portable binary loads these by name, so autoPatchelf cannot detect them.
  runtimeDependencies = map pkgs.lib.getLib (
    with pkgs;
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
    license = pkgs.lib.licenses.mit;
    mainProgram = "godot";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
