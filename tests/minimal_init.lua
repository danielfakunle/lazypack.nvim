local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local plenary_path = root .. '/.deps/plenary.nvim'

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(plenary_path)

vim.cmd.packadd('plenary.nvim')
