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
      {
        "<leader>e",
        "<cmd>NvimTreeToggle<CR>",
        desc = "Toggle NvimTree"
      }
    }
  },
  -- Formatter
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        -- Use prettier for most web stuff
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
      },
      -- format on save
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
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
      { "<leader>fg", function() require('telescope.builtin').live_grep() end,  desc = "Find by grep" },
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
}
