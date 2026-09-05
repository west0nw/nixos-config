{
  config,
  pkgs,
  lib,
  ...
}:

let
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
  home.packages = [ godotWayland ];

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

}
