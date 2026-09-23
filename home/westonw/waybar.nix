{
  config,
  pkgs,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors;
  c = colors.withHashtag;
  fonts = config.stylix.fonts;

  # Helper: build "rgba(r, g, b, a)" from a base16 color name and alpha string
  rgba =
    color: alpha:
    "rgba(${colors."${color}-rgb-r"}, ${colors."${color}-rgb-g"}, ${colors."${color}-rgb-b"}, ${alpha})";

  networkMenu = pkgs.writeShellApplication {
    name = "waybar-network-menu";
    runtimeInputs = with pkgs; [
      networkmanager
      wofi
      gawk
      coreutils
      ghostty
    ];
    text = builtins.readFile ./scripts/waybar-network-menu.sh;
  };

  bluetoothMenu = pkgs.writeShellApplication {
    name = "waybar-bluetooth-menu";
    runtimeInputs = with pkgs; [
      bluez
      util-linux
      wofi
      gawk
      coreutils
    ];
    text = builtins.readFile ./scripts/waybar-bluetooth-menu.sh;
  };
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 35;
        spacing = 8;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/notification"
          "cpu"
          "memory"
          "temperature"
          "disk"
          "pulseaudio"
          "custom/bluetooth"
          "custom/network"
          "battery"
        ];

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "0x1";
            "2" = "0x2";
            "3" = "0x3";
            "4" = "0x4";
            "5" = "0x5";
            "6" = "0x6";
            "7" = "0x7";
            "8" = "0x8";
            "9" = "0x9";
          };
          on-click = "activate";
          sort-by-number = true;
        };

        clock = {
          format = "󰥔 {:%H:%M}";
          format-alt = "󰃭 {:%A, %B %d, %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            weeks-pos = "left";
            on-click-right = "mode";
            format = {
              months = "<span color='" + c.base0D + "'><b>{}</b></span>";
              days = "<span color='" + c.base05 + "'>{}</span>";
              weeks = "<span color='" + c.base04 + "'>{}</span>";
              weekdays = "<span color='" + c.base0D + "'>{}</span>";
              today = "<span color='" + c.base08 + "'><b>{}</b></span>";
            };
          };
          on-click = "mode";
        };

        cpu = {
          format = "󰍛 {usage}%";
          interval = 5;
          tooltip = true;
        };

        memory = {
          format = "󰘚 {percentage}%";
          interval = 5;
          tooltip = true;
          tooltip-format = "{used:0.1f}GiB / {total:0.1f}GiB";
        };

        temperature = {
          format = "󰔏 {temperatureC}°C";
          format-critical = "󱃂 {temperatureC}°C";
          critical-threshold = 80;
          interval = 5;
          tooltip = true;
          hwmon-path = "/sys/class/hwmon/hwmon1/temp1_input";
        };

        disk = {
          format = "󰋊 {percentage_used}%";
          path = "/";
          interval = 30;
          tooltip = true;
          tooltip-format = "{used} / {total} ({percentage_used}%)";
        };

        "custom/bluetooth" = {
          format = "{}";
          interval = 5;
          exec = "${bluetoothMenu}/bin/waybar-bluetooth-menu --status";
          on-click = "${bluetoothMenu}/bin/waybar-bluetooth-menu";
        };

        "custom/notification" = {
          format = "{} {icon}";
          format-icons = {
            notification = "󰂚";
            none = "󰂛";
            dnd-notification = "󰂛";
            dnd-none = "󰂛";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
          restart-interval = 1;
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰖁 muted";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "pavucontrol";
        };

        "custom/network" = {
          format = "{}";
          interval = 5;
          exec = "${networkMenu}/bin/waybar-network-menu --status";
          on-click = "${networkMenu}/bin/waybar-network-menu";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          tooltip-format = "{timeTo}";
        };

      };
    };

    # Styling: rounded pill shapes with theme accents
    # Stylix provides the color scheme; we reference it dynamically
    style = lib.mkForce ''
      * {
        font-family: "${fonts.monospace.name}", sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: ${rgba "base00" "0.85"};
        border-bottom: 2px solid ${rgba "base0D" "0.3"};
      }

      #workspaces button {
        font-family: "Orbitron", "${fonts.monospace.name}", sans-serif;
        padding: 0 8px;
        margin: 4px 2px;
        border-radius: 10px;
        color: ${c.base05};
        background: transparent;
        transition: all 0.2s ease;
      }

      #workspaces button.active {
        background: ${rgba "base0D" "0.25"};
        color: ${c.base0D};
      }

      #workspaces button:hover {
        background: ${rgba "base0D" "0.15"};
      }

      #clock,
      #cpu,
      #memory,
      #temperature,
      #disk,
      #pulseaudio,
      #custom-bluetooth,
      #custom-network,
      #battery,
      #custom-notification {
        padding: 0 12px;
        margin: 4px 2px;
        border-radius: 10px;
        background: ${rgba "base01" "0.6"};
        color: ${c.base05};
        transition: all 0.2s ease;
      }

      #clock:hover,
      #cpu:hover,
      #memory:hover,
      #temperature:hover,
      #disk:hover,
      #pulseaudio:hover,
      #custom-bluetooth:hover,
      #custom-network:hover,
      #battery:hover,
      #custom-notification:hover {
        background: ${rgba "base0D" "0.15"};
      }

      #clock {
        color: ${c.base0D};
        font-weight: bold;
      }

      #battery.warning {
        color: ${c.base09};
      }

      #battery.critical {
        color: ${c.base08};
        animation: blink 1s linear infinite;
      }

      #custom-network {
        color: ${c.base05};
      }

      #temperature.critical {
        color: ${c.base08};
        animation: blink 1s linear infinite;
      }

      #disk.warning {
        color: ${c.base09};
      }

      #disk.critical {
        color: ${c.base08};
      }

      #custom-bluetooth {
        color: ${c.base05};
      }

      #custom-notification {
        color: ${c.base05};
      }

      #custom-notification.notification {
        color: ${c.base0A};
      }

      @keyframes blink {
        to {
          color: ${c.base02};
        }
      }
    '';
  };
}
