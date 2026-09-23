{
  config,
  pkgs,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors;
  lua = lib.generators.mkLuaInline;
  bind = keys: dispatcher: flags: {
    _args = [
      keys
      (lua dispatcher)
      flags
    ];
  };
  run = command: "hl.dsp.exec_cmd(${builtins.toJSON command})";
  runLua = command: "hl.dsp.exec_cmd(${command})";

  powerMenu = pkgs.writeShellScript "power-menu" ''
    choice=$(echo -e "Shutdown\nReboot\nCancel" | wofi --dmenu --prompt "Power Menu" --width 300 --height 200)

    case "$choice" in
      Shutdown)
        confirm=$(echo -e "Yes\nNo" | wofi --dmenu --prompt "Shutdown?" --width 200 --height 150)
        [ "$confirm" = "Yes" ] && systemctl poweroff
        ;;
      Reboot)
        confirm=$(echo -e "Yes\nNo" | wofi --dmenu --prompt "Reboot?" --width 200 --height 150)
        [ "$confirm" = "Yes" ] && systemctl reboot
        ;;
    esac
  '';

  screenshotRegion = pkgs.writeShellApplication {
    name = "screenshot-region";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      libnotify
      slurp
      wl-clipboard
    ];
    text = builtins.readFile ./scripts/screenshot-region.sh;
  };

in
{
  # Stylix still emits dotted Hyprlang color keys for its Lua target.
  # Keep its palette while rendering colors in Hyprland's native Lua shape.
  stylix.targets.hyprland.enable = false;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    settings = {
      terminal._var = "ghostty";
      menu._var = "wofi --show drun";
      power._var = "${powerMenu}";
      screenshotRegion._var = "${screenshotRegion}/bin/screenshot-region";

      # ── Monitors ────────────────────────────────────────────────────────────────
      monitor = [
        {
          output = "eDP-2";
          mode = "2560x1600@165";
          position = "2560x0";
          scale = 1.25;
        }
        {
          output = "DP-5";
          mode = "2560x1440@240";
          position = "0x0";
          scale = 1;
        }
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        }
      ];

      # ── Appearance and input ───────────────────────────────────────────────────
      config = {
        input = {
          kb_layout = "us";
          kb_variant = "dvorak";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = true;
            tap_to_click = true;
            drag_lock = 1;
            disable_while_typing = false;
            scroll_factor = 0.25;
          };
        };
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          col = {
            active_border = {
              colors = [
                "rgba(${colors.base07}ee)"
                "rgba(${colors.base0D}ee)"
              ];
              angle = 45;
            };
            inactive_border = "rgba(${colors.base03}aa)";
          };
          layout = "dwindle";
          allow_tearing = false;
        };
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 7;
            passes = 3;
            new_optimizations = true;
            xray = false;
          };
          shadow = {
            enabled = true;
            range = 15;
            render_power = 3;
            color = "rgba(${colors.base00}99)";
          };
          dim_inactive = true;
          dim_strength = 0.1;
        };
        group = {
          col = {
            border_inactive = "rgb(${colors.base03})";
            border_active = "rgb(${colors.base0D})";
            border_locked_active = "rgb(${colors.base0C})";
          };
          groupbar = {
            text_color = "rgb(${colors.base05})";
            col = {
              active = "rgb(${colors.base0D})";
              inactive = "rgb(${colors.base03})";
            };
          };
        };
        cursor.no_hardware_cursors = 1;
        animations.enabled = true;
        dwindle.preserve_split = true;
        master.new_status = "master";
        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          key_press_enables_dpms = true;
          mouse_move_enables_dpms = true;
          enable_swallow = true;
          swallow_regex = "^(ghostty|alacritty|kitty|foot)$";
          background_color = "rgb(${colors.base00})";
        };
      };

      # ── Animations ──────────────────────────────────────────────────────────────
      curve = map (entry: { _args = entry; }) [
        [
          "easeOutQuint"
          {
            type = "bezier";
            points = [
              [
                0.22
                1
              ]
              [
                0.36
                1
              ]
            ];
          }
        ]
        [
          "easeInOutCubic"
          {
            type = "bezier";
            points = [
              [
                0.65
                0
              ]
              [
                0.35
                1
              ]
            ];
          }
        ]
        [
          "linear"
          {
            type = "bezier";
            points = [
              [
                0
                0
              ]
              [
                1
                1
              ]
            ];
          }
        ]
        [
          "almostLinear"
          {
            type = "bezier";
            points = [
              [
                0.5
                0.5
              ]
              [
                0.75
                1.0
              ]
            ];
          }
        ]
        [
          "quick"
          {
            type = "bezier";
            points = [
              [
                0.15
                0
              ]
              [
                0.1
                1
              ]
            ];
          }
        ]
        [
          "popinBouncy"
          {
            type = "bezier";
            points = [
              [
                0.34
                1.56
              ]
              [
                0.64
                1
              ]
            ];
          }
        ]
        [
          "easeOutBack"
          {
            type = "bezier";
            points = [
              [
                0.34
                1.56
              ]
              [
                0.64
                1
              ]
            ];
          }
        ]
      ];
      animation =
        map
          (
            entry:
            {
              leaf = builtins.elemAt entry 0;
              enabled = true;
              speed = builtins.elemAt entry 1;
              bezier = builtins.elemAt entry 2;
            }
            // lib.optionalAttrs (builtins.length entry > 3) { style = builtins.elemAt entry 3; }
          )
          [
            [
              "global"
              10
              "default"
            ]
            [
              "border"
              5.39
              "easeOutQuint"
            ]
            [
              "windows"
              4.79
              "easeOutQuint"
            ]
            [
              "windowsIn"
              4.1
              "easeOutQuint"
              "popin 87%"
            ]
            [
              "windowsOut"
              1.49
              "linear"
              "popin 87%"
            ]
            [
              "fadeIn"
              1.73
              "almostLinear"
            ]
            [
              "fadeOut"
              1.46
              "almostLinear"
            ]
            [
              "fade"
              3.03
              "quick"
            ]
            [
              "layers"
              3.81
              "easeOutQuint"
            ]
            [
              "layersIn"
              2.8
              "easeOutBack"
              "popin 60%"
            ]
            [
              "layersOut"
              1.0
              "easeOutQuint"
              "popin 60%"
            ]
            [
              "fadeLayersIn"
              1.79
              "almostLinear"
            ]
            [
              "fadeLayersOut"
              1.39
              "almostLinear"
            ]
            [
              "workspaces"
              1.94
              "almostLinear"
              "fade"
            ]
            [
              "workspacesIn"
              1.21
              "almostLinear"
              "fade"
            ]
            [
              "workspacesOut"
              1.94
              "almostLinear"
              "fade"
            ]
          ];

      workspace_rule = [
        {
          workspace = "special:scratchpad";
          on_created_empty = "ghostty";
        }
        { workspace = "special:vpn"; }
      ];

      # ── Keybindings ─────────────────────────────────────────────────────────────
      bind = [
        (bind "SUPER + Return" (runLua "terminal") { })
        (bind "SUPER + B" (run "vivaldi") { })
        (bind "SUPER + Space" (runLua "menu") { })
        (bind "SUPER + W" "hl.dsp.window.close()" { })
        (bind "SUPER + SHIFT + E" "hl.dsp.exit()" { })
        (bind "SUPER + SHIFT + V" (run "cliphist list | wofi --dmenu | cliphist decode | wl-copy") { })
        (bind "SUPER + SHIFT + P" (runLua "power") { })
        (bind "SUPER + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'' { })
        (bind "SUPER + V" ''hl.dsp.window.float({ action = "toggle" })'' { })
        (bind "SUPER + P" "hl.dsp.window.pseudo()" { })
        (bind "SUPER + S" ''hl.dsp.layout("togglesplit")'' { })
        (bind "SUPER + H" ''hl.dsp.focus({ direction = "l" })'' { })
        (bind "SUPER + L" ''hl.dsp.focus({ direction = "r" })'' { })
        (bind "SUPER + K" ''hl.dsp.focus({ direction = "u" })'' { })
        (bind "SUPER + J" ''hl.dsp.focus({ direction = "d" })'' { })
        (bind "SUPER + SHIFT + H" ''hl.dsp.window.move({ direction = "l" })'' { })
        (bind "SUPER + SHIFT + L" ''hl.dsp.window.move({ direction = "r" })'' { })
        (bind "SUPER + SHIFT + K" ''hl.dsp.window.move({ direction = "u" })'' { })
        (bind "SUPER + SHIFT + J" ''hl.dsp.window.move({ direction = "d" })'' { })
        (bind "SUPER + mouse_down" ''hl.dsp.focus({ workspace = "e+1" })'' { })
        (bind "SUPER + mouse_up" ''hl.dsp.focus({ workspace = "e-1" })'' { })
        (bind "SUPER + Escape" (run "hyprlock") { })
        (bind "SUPER + SHIFT + W" (runLua "wallpaper") { })
        (bind "Print" (run "hyprshot -m output -o ~/Pictures/Screenshots/") { })
        (bind "SHIFT + Print" (runLua "screenshotRegion") { })
        (bind "CTRL + Print" (run "hyprshot -m window --clipboard-only") { })
        (bind "CTRL + SHIFT + Print" (run "hyprshot -m output --clipboard-only") { })
        (bind "SUPER + grave" ''hl.dsp.workspace.toggle_special("scratchpad")'' { })
        (bind "SUPER + SHIFT + grave" ''hl.dsp.window.move({ workspace = "special:scratchpad" })'' { })
        (bind "SUPER + CTRL + V" (runLua "vpn") { })
        (bind "SUPER + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (bind "SUPER + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
        (bind "XF86AudioMute" (run "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
          locked = true;
          repeating = true;
        })
        (bind "XF86AudioLowerVolume" (run "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") {
          locked = true;
          repeating = true;
        })
        (bind "XF86AudioRaiseVolume" (run "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") {
          locked = true;
          repeating = true;
        })
        (bind "XF86AudioPrev" (run "playerctl previous") {
          locked = true;
          repeating = true;
        })
        (bind "XF86AudioPlay" (run "playerctl play-pause") {
          locked = true;
          repeating = true;
        })
        (bind "XF86AudioNext" (run "playerctl next") {
          locked = true;
          repeating = true;
        })
        (bind "XF86MonBrightnessDown" (run "brightnessctl set 5%-") {
          locked = true;
          repeating = true;
        })
        (bind "XF86MonBrightnessUp" (run "brightnessctl set 5%+") {
          locked = true;
          repeating = true;
        })
      ]
      ++ builtins.concatLists (
        map (n: [
          (bind "SUPER + ${toString n}" "hl.dsp.focus({ workspace = ${toString n} })" { })
          (bind "SUPER + SHIFT + ${toString n}" "hl.dsp.window.move({ workspace = ${toString n} })" { })
        ]) (lib.range 1 9)
      );

      # ── Window rules ────────────────────────────────────────────────────────────
      window_rule = [
        {
          match.class = "^(pavucontrol)$";
          float = true;
        }
        {
          match.class = "^(nm-connection-editor)$";
          float = true;
        }
        {
          match.class = "^(blueman-manager)$";
          float = true;
        }
        {
          match.class = "^(proton\\.vpn\\.app\\.gtk)$";
          workspace = "special:vpn silent";
        }
        {
          match.class = "^(proton\\.vpn\\.app\\.gtk)$";
          float = true;
        }
        {
          match = {
            class = "^(thunar)$";
            title = "^(File Operation Progress)$";
          };
          float = true;
        }
        {
          match.title = "^(Open File)$";
          float = true;
        }
        {
          match.title = "^(Save As)$";
          float = true;
        }
        {
          match.title = "^(Confirm to replace files)$";
          float = true;
        }
        {
          match.title = "^(Picture-in-Picture)$";
          float = true;
        }
        {
          match.title = "^(Picture-in-Picture)$";
          pin = true;
        }
      ];

      # Clipboard history starts only when a new session begins.
      on = {
        _args = [
          "hyprland.start"
          (lua ''
            function()
              hl.exec_cmd("wl-paste --type text --watch cliphist store")
              hl.exec_cmd("wl-paste --type image --watch cliphist store")
            end
          '')
        ];
      };
    };
  };
}
