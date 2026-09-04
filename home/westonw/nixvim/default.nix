{ config, pkgs, lib, ... }:

{
  imports = [
    ./plugins.nix
    ./lsp.nix
    ./completion.nix
    ./keymaps.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    nixpkgs.source = pkgs.path;

    # Catppuccin Mocha colorscheme
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = false;
        integrations = {
          cmp = true;
          gitsigns = true;
          nvimtree = true;
          telescope = {
            enabled = true;
          };
          treesitter = true;
          which_key = true;
          indent_blankline = {
            enabled = true;
          };
        };
      };
    };

    # Leader key
    globals.mapleader = " ";
    globals.maplocalleader = " ";

    # Editor options
    opts = {
      # Line numbers
      number = true;
      relativenumber = true;

      # Tabs / Indentation
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      smartindent = true;

      # Search
      ignorecase = true;
      smartcase = true;
      hlsearch = true;
      incsearch = true;

      # UI
      termguicolors = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 8;
      sidescrolloff = 8;
      wrap = true;
      showmode = false;
      splitbelow = true;
      splitright = true;

      # Clipboard (system clipboard)
      clipboard = "unnamedplus";

      # Undo
      undofile = true;
      swapfile = false;

      # Performance
      updatetime = 250;
      timeoutlen = 300;

      # Completion
      completeopt = "menuone,noselect";
    };
  };
}
