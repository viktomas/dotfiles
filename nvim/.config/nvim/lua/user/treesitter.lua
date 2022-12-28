require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all"
  ensure_installed = { "javascript", "typescript", "ruby", "go" },

  -- Automatically install missing parsers when entering buffer
  auto_install = true,

  highlight = {
    -- `false` will disable the whole extension
    enable = true,

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}

-- folding with tree-sitter
-- -------------------------
-- https://www.jmaguire.tech/posts/treesitter_folding/
-- This is partially broken thanks to telescope
-- see issue https://github.com/nvim-telescope/telescope.nvim/issues/559
-- and https://github.com/nvim-telescope/telescope.nvim/issues/699
-- UNCOMENT FOLLOWING LINES IF Telescope ever fixes the issue
-- vim.opt.foldmethod = "expr"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"

-- workaraound for telescope issue https://github.com/nvim-telescope/telescope.nvim/issues/559#issuecomment-1074076011
-- vim.api.nvim_create_autocmd('BufRead', {
--    callback = function()
--       vim.api.nvim_create_autocmd('BufWinEnter', {
--          once = true,
--          command = 'normal! zx zR'
--       })
--    end
-- })

-- this is my rewrite of the following autocmd
-- autocmd BufReadPost,FileReadPost * normal zR
-- it should unfold everything when opening a file
-- it doesn't work, probably thanks to telescope
-- vim.api.nvim_create_autocmd(
--   {'BufReadPost', 'FileReadPost'},
--   { command = 'normal zR' }
-- )
