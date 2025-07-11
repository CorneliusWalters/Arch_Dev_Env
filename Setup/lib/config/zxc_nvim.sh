#!/bin/bash
###     file name: zxc_nvim.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zxc_nvim.sh
if [ ! -f ~/.config/nvim/init.lua ]; then

cat > ~/.config/nvim/init.lua << 'EOL'
-- ##--init.lua (Corrected)

-- Set leader key early, as many plugins might use it during setup
vim.g.mapleader = " "

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core preferences that don't depend on plugins
require('preferences')
require('keymaps')

-- Tell lazy.nvim to setup plugins from the 'plugins' module
-- This is where the magic happens.
require('lazy').setup('plugins', {
    -- Optional lazy.nvim global options can go here
    -- checker = { enabled = true },
})

-- Set colorscheme (can also be done in the theme's config)
vim.cmd([[colorscheme kanagawa]])
EOL
else
    print_warning "NVIM_CONF" "Neovim init.lua already exists. Skipping overwrite to preserve user settings."
    print_status "NVIM_CONF" "To update to the latest config, please merge changes manually or remove ~/.config/nvim/init.lua and rerun."
fi


if [ ! -f ~/.config/nvim/preferences.lua ]; then

> ~/.config/nvim/preferences.lua << 'EOL'

-- This file is required by init.lua before plugins are loaded.
-- It's for settings that don't depend on any plugins.

print("Loading core preferences...")

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.autoindent = true
vim.opt.showcmd = true
vim.opt.showmatch = true
vim.opt.wrap = false
EOL

else
    print_warning "NVIM_CONF" "Neovim preferences.lua already exists. Skipping overwrite to preserve user settings."
    print_status "NVIM_CONF" "To update to the latest config, please merge changes manually or remove ~/.config/nvim/preferences.lua and rerun."
fi


if [ ! -f ~/.config/nvim/plugins.lua ]; then

cat > ~/.config/nvim/plugins.lua << 'EOF'
return {
  -- Appearance
  { "rebelot/kanagawa.nvim", priority = 1000 },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("lualine").setup({ theme = "kanagawa" }) end
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("nvim-tree").setup({ view = { side = "right", width = 30 } }) end,
    keys = { 
    { "<leader>e", 
    "<cmd>NvimTreeToggle<CR>", 
    desc = "Toggle NvimTree" } 
    }
  },

  -- LSP, Completion, Snippets
  {
    "neovim/nvim-lspconfig",
    dependencies = { 
    "hrsh7th/nvim-cmp", 
    "hrsh7th/cmp-nvim-lsp", 
    "L3MON4D3/LuaSnip", 
    "saadparwaiz1/cmp_luasnip" 
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      -- Setup servers
      lspconfig.pyright.setup { capabilities = capabilities }
      lspconfig.tsserver.setup { capabilities = capabilities }
      lspconfig.rust_analyzer.setup({}) -- Basic setup is fine
      lspconfig.zls.setup({})           -- Basic setup is fine
      lspconfig.lua_ls.setup {
        capabilities = capabilities,
        settings = { Lua = { diagnostics = { globals = { 'vim' } } } }
      }
      -- Setup completion
      local cmp = require('cmp')
      cmp.setup {
        snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
        sources = cmp.config.sources({ { name = 'nvim_lsp' }, { name = 'luasnip' } }, { { name = 'buffer' } }),
        mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
      }
      -- Setup LSP keymaps
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go to definition" })
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = "Show hover info" })
    end
  },

  -- Fuzzy Finding
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function() require("telescope").setup({}) end,
    keys = {
      { "<leader>ff", function() require('telescope.builtin').find_files() end, desc = "Find files" },
      { "<leader>fg", function() require('telescope.builtin').live_grep() end, desc = "Find by grep" },
    }
  },

  -- Database Support
  { "tpope/vim-dadbod" },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = { 
    "tpope/vim-dadbod", 
    "nvim-lua/plenary.nvim" 
    },
    config = function() vim.g.dadbod_ui_use_nvim_notify = 1 end,
    keys = { { 
    "<leader>db", 
    "<cmd>DBUIToggle<cr>", 
    desc = "DBUI: Toggle" 
    } }
  },

  -- API Testing
  {
    "rest-nvim/rest.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function() require("rest-nvim").setup({}) end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = 
        { 
        "python", 
        "lua", 
        "javascript", 
        "rust", 
        "zig", 
        "sql", 
        "bash" 
        },
        auto_install = true,
        highlight = { enable = true }
      })
    end
  },

  -- Other QoL plugins
  { 
  "lewis6991/gitsigns.nvim", 
  config = function() require('gitsigns').setup() end 
  },
  { "windwp/nvim-autopairs", config = true },
  { "nvim-lua/plenary.nvim" }, -- Explicit dependency

EOF
else
    print_warning "NVIM_CONF" "Neovim plugins.lua already exists. Skipping overwrite to preserve user settings."
    print_status "NVIM_CONF" "To update to the latest config, please merge changes manually or remove ~/.config/nvim/plugins.lua and rerun."
fi

if [ ! -f ~/.config/nvim/keymaps.lua ]; then

cat > ~/.config/nvim/keymaps.lua << 'EOL'
-- Core keymaps that do not depend on any plugins

print("Loading core keymaps...")

-- File operations
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = "Save file" })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = "Quit" })

-- Window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = "Move to left window" })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = "Move to window below" })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = "Move to window above" })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = "Move to right window" })

-- Buffer navigation
vim.keymap.set('n', '<Tab>', ':bnext<CR>', { desc = "Next buffer" })
vim.keymap.set('n', '<S-Tab>', ':bprevious<CR>', { desc = "Previous buffer" })
EOL
else
    print_warning "NVIM_CONF" "Neovim plugins.lua already exists. Skipping overwrite to preserve user settings."
    print_status "NVIM_CONF" "To update to the latest config, please merge changes manually or remove ~/.config/nvim/keymaps.lua and rerun."
fi
