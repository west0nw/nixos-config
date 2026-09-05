{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.nixvim.keymaps = [
    # ── Telescope ───────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>ff";
      action = "<cmd>Telescope find_files<CR>";
      options.desc = "Find files";
    }
    {
      mode = "n";
      key = "<leader>fg";
      action = "<cmd>Telescope live_grep<CR>";
      options.desc = "Live grep";
    }
    {
      mode = "n";
      key = "<leader>fb";
      action = "<cmd>Telescope buffers<CR>";
      options.desc = "Buffers";
    }
    {
      mode = "n";
      key = "<leader>fh";
      action = "<cmd>Telescope help_tags<CR>";
      options.desc = "Help tags";
    }
    {
      mode = "n";
      key = "<leader>fr";
      action = "<cmd>Telescope oldfiles<CR>";
      options.desc = "Recent files";
    }
    {
      mode = "n";
      key = "<leader>fd";
      action = "<cmd>Telescope diagnostics<CR>";
      options.desc = "Diagnostics";
    }

    # ── File Tree ───────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>NvimTreeToggle<CR>";
      options.desc = "Toggle file tree";
    }

    # ── Buffers ─────────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>x";
      action = "<cmd>bdelete<CR>";
      options.desc = "Close buffer";
    }
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>bnext<CR>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>bprevious<CR>";
      options.desc = "Previous buffer";
    }

    # ── Save / Quit ─────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>w";
      action = "<cmd>w<CR>";
      options.desc = "Save file";
    }
    {
      mode = "n";
      key = "<leader>q";
      action = "<cmd>q<CR>";
      options.desc = "Quit";
    }
    {
      mode = "n";
      key = "<leader>Q";
      action = "<cmd>qa!<CR>";
      options.desc = "Force quit all";
    }

    # ── Splits ──────────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>sv";
      action = "<cmd>vsplit<CR>";
      options.desc = "Split vertical";
    }
    {
      mode = "n";
      key = "<leader>sh";
      action = "<cmd>split<CR>";
      options.desc = "Split horizontal";
    }

    # ── Navigate Splits ─────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Move to left split";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Move to lower split";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Move to upper split";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Move to right split";
    }

    # ── Move Lines (visual mode) ────────────────────────────────────────────
    {
      mode = "v";
      key = "J";
      action = ":m '>+1<CR>gv=gv";
      options.desc = "Move selection down";
    }
    {
      mode = "v";
      key = "K";
      action = ":m '<-2<CR>gv=gv";
      options.desc = "Move selection up";
    }

    # ── Clear Search Highlight ──────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>h";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "Clear search highlight";
    }
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "Clear search highlight";
    }

    # ── Trouble ─────────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>xx";
      action = "<cmd>Trouble diagnostics toggle<CR>";
      options.desc = "Diagnostics (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xd";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
      options.desc = "Buffer diagnostics";
    }

    # ── Better paste (don't overwrite register) ─────────────────────────────
    {
      mode = "x";
      key = "<leader>p";
      action = "\"_dP";
      options.desc = "Paste without overwrite";
    }

    # ── Stay centered ───────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<C-d>";
      action = "<C-d>zz";
      options.desc = "Half page down (centered)";
    }
    {
      mode = "n";
      key = "<C-u>";
      action = "<C-u>zz";
      options.desc = "Half page up (centered)";
    }
    {
      mode = "n";
      key = "n";
      action = "nzzzv";
      options.desc = "Next search (centered)";
    }
    {
      mode = "n";
      key = "N";
      action = "Nzzzv";
      options.desc = "Prev search (centered)";
    }

    # ── Format ──────────────────────────────────────────────────────────────
    {
      mode = "n";
      key = "<leader>cf";
      action = "<cmd>lua require('conform').format({ lsp_format = \"fallback\" })<CR>";
      options.desc = "Format file";
    }
  ];
}
