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
