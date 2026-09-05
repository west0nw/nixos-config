{
  config,
  pkgs,
  lib,
  ...
}:

let
  wallpapersDir = ../../wallpapers;
  wallpaperFiles = lib.filter (
    name: lib.hasSuffix ".png" name || lib.hasSuffix ".jpg" name || lib.hasSuffix ".jpeg" name
  ) (builtins.attrNames (builtins.readDir wallpapersDir));
  wallpaperMenu = pkgs.writeText "wallpaper-menu" (lib.concatStringsSep "\n" wallpaperFiles);
  wallpaperSwitcher = pkgs.writeShellApplication {
    name = "wallpaper-switcher";
    runtimeInputs = with pkgs; [
      awww
      wofi
    ];
    text = ''
      choice=$(wofi --dmenu --prompt "Select Wallpaper" --insensitive --matching fuzzy \
        --width 400 --height 300 < ${wallpaperMenu}) || exit 0
      # dmenu accepts arbitrary input; only accept files from the generated menu.
      case "$choice" in
        ${lib.concatStringsSep "|" (map lib.escapeShellArg wallpaperFiles)})
          awww img "${wallpapersDir}/$choice" \
            --transition-type grow --transition-pos 0.5,0.5 \
            --transition-duration 0.8 --transition-fps 60 --transition-step 45 --filter Nearest
          ;;
      esac
    '';
  };
  wallpaperStartup = pkgs.writeShellApplication {
    name = "wallpaper-startup";
    runtimeInputs = with pkgs; [
      awww
      coreutils
    ];
    text = ''
      # Wait for the daemon socket instead of assuming it is ready after a fixed sleep.
      for _ in $(seq 1 100); do
        if awww query >/dev/null 2>&1; then
          exec awww img ${lib.escapeShellArg (toString config.stylix.image)}
        fi
        sleep 0.1
      done
      echo "awww did not become ready within 10 seconds" >&2
      exit 1
    '';
  };
in
{
  services.hyprpaper.enable = lib.mkForce false;
  services.awww.enable = true;
  systemd.user.services.awww.Service.ExecStartPost = "${wallpaperStartup}/bin/wallpaper-startup";
  wayland.windowManager.hyprland.settings."$wallpaper" =
    "${wallpaperSwitcher}/bin/wallpaper-switcher";
}
