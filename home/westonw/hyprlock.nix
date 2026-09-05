{
  config,
  pkgs,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors;
  fonts = config.stylix.fonts;

  # Helper: build "rgba(r, g, b, a)" from a base16 color name and alpha string
  rgba =
    color: alpha:
    "rgba(${colors."${color}-rgb-r"}, ${colors."${color}-rgb-g"}, ${colors."${color}-rgb-b"}, ${alpha})";

  # Helper: build "rgb(hex)" from a base16 color name
  rgb = color: "rgb(${colors.${color}})";
in
{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        grace = 5;
        disable_loading_bar = false;
      };

      background = lib.mkForce [
        {
          monitor = "";
          path = "${config.stylix.image}";
          blur_passes = 3;
          blur_size = 7;
          noise = 0.01;
          brightness = 0.6;
        }
      ];

      input-field = lib.mkForce [
        {
          monitor = "";
          size = "300, 50";
          outline_thickness = 2;

          outer_color = rgba "base0D" "0.6";
          inner_color = rgba "base00" "0.85";
          font_color = rgb "base05";
          check_color = rgba "base0A" "0.6";
          fail_color = rgba "base08" "0.6";

          fade_on_empty = true;
          placeholder_text = "<i>Password...</i>";
          dots_spacing = 0.3;
          dots_center = true;

          position = "0, -80";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        # Time
        {
          monitor = "";
          text = "$TIME";
          color = rgba "base05" "0.9";
          font_size = 72;
          font_family = fonts.monospace.name;

          position = "0, 120";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          monitor = "";
          text = "cmd[update:3600000] date +'%A, %B %d'";
          color = rgba "base04" "0.7";
          font_size = 18;
          font_family = fonts.monospace.name;

          position = "0, 50";
          halign = "center";
          valign = "center";
        }
        # User greeting
        {
          monitor = "";
          text = "Hi, $USER";
          color = rgba "base0D" "0.8";
          font_size = 14;
          font_family = fonts.monospace.name;

          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        # Dim screen after 5 minutes
        {
          timeout = 300;
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        # Lock screen after 10 minutes
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        # Turn off display after 15 minutes
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
