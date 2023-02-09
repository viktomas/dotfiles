
local lv = require 'link-visitor'
vim.keymap.set('n', 'gx', lv.link_under_cursor, {desc = "link-visitor: link_under_cursor"})
