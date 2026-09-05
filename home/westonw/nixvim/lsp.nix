{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.nixvim = {
    plugins = {
      # ── LSP ───────────────────────────────────────────────────────────────────
      lsp = {
        enable = true;

        keymaps = {
          # Go-to keymaps
          lspBuf = {
            "gd" = {
              action = "definition";
              desc = "Go to definition";
            };
            "gD" = {
              action = "declaration";
              desc = "Go to declaration";
            };
            "gi" = {
              action = "implementation";
              desc = "Go to implementation";
            };
            "gr" = {
              action = "references";
              desc = "Go to references";
            };
            "K" = {
              action = "hover";
              desc = "Hover documentation";
            };
            "<leader>ca" = {
              action = "code_action";
              desc = "Code action";
            };
            "<leader>rn" = {
              action = "rename";
              desc = "Rename symbol";
            };
            "<leader>D" = {
              action = "type_definition";
              desc = "Type definition";
            };
          };

          # Diagnostic keymaps
          diagnostic = {
            "[d" = {
              action = "goto_prev";
              desc = "Previous diagnostic";
            };
            "]d" = {
              action = "goto_next";
              desc = "Next diagnostic";
            };
            "<leader>dl" = {
              action = "open_float";
              desc = "Line diagnostics";
            };
          };
        };

        servers = {
          # Nix
          nixd = {
            enable = true;
            settings = {
              formatting.command = [ "nixfmt" ];
            };
          };

          # Rust
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
            settings = {
              checkOnSave = true;
              check.command = "clippy";
            };
          };

          # Python
          basedpyright = {
            enable = true;
          };
          ruff = {
            enable = true;
          };

          # TypeScript / JavaScript
          ts_ls = {
            enable = true;
          };

          # Svelte
          svelte = {
            enable = true;
          };

          # Go
          gopls = {
            enable = true;
          };

          # C/C++
          clangd = {
            enable = true;
          };

          # Lua
          lua_ls = {
            enable = true;
            settings = {
              diagnostics.globals = [ "vim" ];
              workspace.checkThirdParty = false;
            };
          };

          # Bash
          bashls = {
            enable = true;
          };

          # Zig
          # TODO: Re-enable zls once nixpkgs build is fixed.
          # zls = {
          #   enable = true;
          # };

          # Java
          jdtls = {
            enable = true;
          };

          # Dart / Flutter
          dartls = {
            enable = true;
          };

          # Odin
          ols = {
            enable = true;
          };
        };
      };

      # ── Formatting ──────────────────────────────────────────────────────────
      conform-nvim = {
        enable = true;
        autoInstall.enable = true;

        settings = {
          format_on_save = {
            timeout_ms = 2000;
            lsp_format = "fallback";
          };

          formatters_by_ft = {
            nix = [ "nixfmt" ];
            rust = [ "rustfmt" ];
            python = [ "ruff_format" ];
            typescript = [ "prettier" ];
            typescriptreact = [ "prettier" ];
            javascript = [ "prettier" ];
            javascriptreact = [ "prettier" ];
            svelte = [ "prettier" ];
            html = [ "prettier" ];
            css = [ "prettier" ];
            json = [ "prettier" ];
            yaml = [ "prettier" ];
            markdown = [ "prettier" ];
            go = [ "gofmt" ];
            lua = [ "stylua" ];
            bash = [ "shfmt" ];
            sh = [ "shfmt" ];
            c = [ "clang-format" ];
            cpp = [ "clang-format" ];
            zig = [ "zigfmt" ];
            dart = [ "dart_format" ];
            odin = [ "odinfmt" ];
            "_" = [ "trim_whitespace" ];
          };
        };
      };
    };

    # rust-analyzer's check.command uses cargo clippy.
    extraPackages = with pkgs; [ clippy ];
  };
}
