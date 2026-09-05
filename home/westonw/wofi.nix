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
in
{
  programs.wofi = {
    enable = true;

    settings = {
      width = 500;
      height = 350;
      show = "drun";
      prompt = "Search...";
      allow_markup = true;
      insensitive = true;
      matching = "fuzzy";
      term = "ghostty";
    };

    # Theme-aware styling with rounded corners
    style = lib.mkForce ''
      window {
        margin: 0;
        border: 2px solid ${rgba "base0D" "0.4"};
        border-radius: 12px;
        background-color: ${rgba "base00" "0.92"};
        font-family: "${fonts.monospace.name}", sans-serif;
        font-size: 14px;
      }

      #input {
        margin: 8px;
        padding: 8px 12px;
        border: none;
        border-radius: 8px;
        background-color: ${c.base01};
        color: ${c.base05};
        font-size: 14px;
      }

      #input:focus {
        border: 2px solid ${c.base0D};
      }

      #inner-box {
        margin: 0 8px 8px 8px;
        border-radius: 8px;
        background-color: transparent;
      }

      #outer-box {
        margin: 0;
        padding: 0;
      }

      #scroll {
        margin: 0;
      }

      #entry {
        padding: 6px 12px;
        border-radius: 8px;
        color: ${c.base05};
      }

      #entry:selected {
        background-color: ${rgba "base0D" "0.2"};
        color: ${c.base0D};
      }

      #text {
        margin: 0 4px;
      }

      #entry image {
        margin-right: 8px;
      }
    '';
  };
}
