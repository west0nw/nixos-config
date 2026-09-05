{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.nixvim.plugins = {
    # ── Fuzzy Finder ────────────────────────────────────────────────────────────
    telescope = {
      enable = true;
      settings.defaults = {
        file_ignore_patterns = [
          "node_modules"
          ".git/"
          "target/"
        ];
        layout_strategy = "horizontal";
        layout_config = {
          horizontal = {
            preview_width = 0.55;
          };
        };
      };
    };

    # ── File Browser ──────────────────────────────────────────────────────────
    nvim-tree = {
      enable = true;
      settings = {
        filters.dotfiles = false;
        view = {
          width = 35;
          side = "left";
        };
        renderer = {
          group_empty = true;
          icons.show = {
            file = true;
            folder = true;
            folder_arrow = true;
            git = true;
          };
        };
        git = {
          enable = true;
          ignore = false;
        };
      };
    };

    # ── Status Line ───────────────────────────────────────────────────────────
    lualine = {
      enable = true;
      settings.options = {
        theme = "catppuccin";
        section_separators = {
          left = "";
          right = "";
        };
        component_separators = {
          left = "";
          right = "";
        };
      };
    };

    # ── Buffer Line ───────────────────────────────────────────────────────────
    bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        offsets = [
          {
            filetype = "NvimTree";
            text = "Explorer";
            highlight = "Directory";
            separator = true;
          }
        ];
      };
    };

    # ── Git ────────────────────────────────────────────────────────────────────
    gitsigns = {
      enable = true;
      settings = {
        current_line_blame = true;
        current_line_blame_opts.delay = 500;
        signs = {
          add = {
            text = "▎";
          };
          change = {
            text = "▎";
          };
          delete = {
            text = "";
          };
          topdelete = {
            text = "";
          };
          changedelete = {
            text = "▎";
          };
        };
      };
    };

    # ── Keybinding Hints ──────────────────────────────────────────────────────
    which-key = {
      enable = true;
    };

    # ── Editing ───────────────────────────────────────────────────────────────
    nvim-autopairs.enable = true;
    nvim-surround.enable = true;
    comment.enable = true;

    # ── Indentation Guides ────────────────────────────────────────────────────
    indent-blankline = {
      enable = true;
      settings.scope = {
        enabled = true;
        show_start = true;
      };
    };

    # ── Syntax Highlighting ───────────────────────────────────────────────────
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        ensure_installed = [
          "nix"
          "rust"
          "python"
          "typescript"
          "javascript"
          "tsx"
          "go"
          "c"
          "cpp"
          "lua"
          "bash"
          "zig"
          "java"
          "dart"
          "svelte"
          "html"
          "css"
          "json"
          "yaml"
          "toml"
          "markdown"
          "markdown_inline"
          "vim"
          "vimdoc"
          "query"
          "regex"
          "odin"
        ];
      };
    };

    # ── Diagnostics List ──────────────────────────────────────────────────────
    trouble = {
      enable = true;
    };

    # ── TODO Comments ─────────────────────────────────────────────────────────
    todo-comments = {
      enable = true;
    };

    # ── LSP Progress ──────────────────────────────────────────────────────────
    fidget = {
      enable = true;
    };

    # ── File Icons ────────────────────────────────────────────────────────────
    web-devicons.enable = true;
  };
}
