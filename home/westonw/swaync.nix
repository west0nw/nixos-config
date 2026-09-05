{
  config,
  pkgs,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors;
  c = colors.withHashtag;

  rgba =
    color: alpha:
    "rgba(${colors."${color}-rgb-r"}, ${colors."${color}-rgb-g"}, ${colors."${color}-rgb-b"}, ${alpha})";
in
{
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-margin-left = 10;
      notification-2fa-action = true;
      notification-inline-replies = false;
      notification-icon-size = 48;
      notification-body-image-height = 160;
      notification-body-image-width = 200;
      timeout = 5;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = false;
      control-center-width = 380;
      control-center-height = 600;
      notification-window-width = 380;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;

      widgets = [
        "title"
        "notifications"
        "mpris"
        "volume"
        "dnd"
      ];

      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        mpris = {
          image-size = 80;
          blur = true;
        };
        volume = {
          label = "󰕾";
        };
      };
    };

    style = lib.mkForce ''
      * {
        font-family: "${config.stylix.fonts.monospace.name}";
        font-size: 13px;
        font-weight: 500;
      }

      .notification-row {
        background: transparent;
        margin: 6px 10px;
        border-radius: 12px;
      }

      .notification {
        background: ${rgba "base00" "0.95"};
        border: 2px solid ${rgba "base0D" "0.4"};
        border-radius: 12px;
        padding: 12px;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
      }

      .notification-content {
        background: transparent;
      }

      .notification-action {
        background: ${rgba "base01" "0.6"};
        color: ${c.base05};
        border-radius: 8px;
        margin: 4px;
        padding: 6px 12px;
        transition: all 0.2s ease;
      }

      .notification-action:hover {
        background: ${rgba "base0D" "0.25"};
      }

      .close-button {
        background: ${rgba "base08" "0.8"};
        color: ${c.base00};
        border-radius: 50%;
        padding: 4px;
        margin: 4px;
        transition: all 0.2s ease;
      }

      .close-button:hover {
        background: ${c.base08};
      }

      .summary {
        color: ${c.base0D};
        font-weight: 700;
        font-size: 15px;
      }

      .body {
        color: ${c.base05};
        margin-top: 4px;
      }

      .time {
        color: ${c.base03};
        font-size: 11px;
        margin-top: 2px;
      }

      .control-center {
        background: ${rgba "base00" "0.95"};
        border: 2px solid ${rgba "base0D" "0.4"};
        border-radius: 16px;
        padding: 16px;
        box-shadow: 0 8px 16px rgba(0, 0, 0, 0.3);
      }

      .widget-title {
        font-size: 18px;
        font-weight: 700;
        color: ${c.base0D};
        padding-bottom: 12px;
        border-bottom: 1px solid ${rgba "base03" "0.3"};
        margin-bottom: 12px;
      }

      .widget-title button {
        background: ${rgba "base08" "0.8"};
        color: ${c.base00};
        border-radius: 8px;
        padding: 6px 12px;
        font-size: 12px;
        transition: all 0.2s ease;
      }

      .widget-title button:hover {
        background: ${c.base08};
      }

      .widget-dnd {
        background: ${rgba "base01" "0.6"};
        border-radius: 8px;
        padding: 10px;
        margin-top: 8px;
        color: ${c.base05};
      }

      .widget-dnd > switch {
        background: ${rgba "base03" "0.4"};
        border-radius: 12px;
      }

      .widget-dnd > switch:checked {
        background: ${rgba "base0D" "0.6"};
      }

      .widget-volume {
        background: ${rgba "base01" "0.6"};
        border-radius: 8px;
        padding: 10px;
        margin-top: 8px;
      }

      .widget-mpris {
        background: ${rgba "base01" "0.6"};
        border-radius: 12px;
        padding: 12px;
        margin-top: 8px;
      }

      .widget-mpris-player {
        background: transparent;
      }

      .widget-mpris-title {
        color: ${c.base0D};
        font-weight: 700;
      }

      .widget-mpris-artist {
        color: ${c.base04};
      }

      .widget-mpris-album-art {
        border-radius: 8px;
      }

      .widget-buttons-grid {
        margin-top: 8px;
      }

      .widget-buttons-grid > button {
        background: ${rgba "base01" "0.6"};
        border-radius: 8px;
        margin: 4px;
        padding: 8px;
        transition: all 0.2s ease;
      }

      .widget-buttons-grid > button:hover {
        background: ${rgba "base0D" "0.25"};
      }
    '';
  };
}
