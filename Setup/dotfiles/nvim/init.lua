-- ##--init.lua

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

-- Set colorscheme
vim.cmd([[colorscheme kanagawa]])
