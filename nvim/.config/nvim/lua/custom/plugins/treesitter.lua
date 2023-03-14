return {
  'nvim-treesitter/nvim-treesitter',
  dependencies = {'nvim-treesitter/nvim-treesitter-textobjects', 'HiPhish/nvim-ts-rainbow2'},
  build = ':TSUpdate',
  config = function()
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

      textobjects = {
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            ["]m"] = "@function.outer",
            ["]]"] = { query = "@class.outer", desc = "Next class start" },
            --
            -- You can use regex matching and/or pass a list in a "query" key to group multiple queires.
            ["]o"] = "@loop.*",
            -- ["]o"] = { query = { "@loop.inner", "@loop.outer" } }
            --
            -- You can pass a query group to use query from `queries/<lang>/<query_group>.scm file in your runtime path.
            -- Below example nvim-treesitter's `locals.scm` and `folds.scm`. They also provide highlights.scm and indent.scm.
            ["]s"] = { query = "@scope", query_group = "locals", desc = "Next scope" },
            ["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
          },
          goto_next_end = {
            ["]M"] = "@function.outer",
            ["]["] = "@class.outer",
          },
          goto_previous_start = {
            ["[m"] = "@function.outer",
            ["[["] = "@class.outer",
          },
          goto_previous_end = {
            ["[M"] = "@function.outer",
            ["[]"] = "@class.outer",
          },
          -- Below will go to either the start or the end, whichever is closer.
          -- Use if you want more granular movements
          -- Make it even more gradual by adding multiple queries and regex.
          -- goto_next = {
            --   ["]d"] = "@conditional.outer",
            -- },
            -- goto_previous = {
              --   ["[d"] = "@conditional.outer",
              -- }
            },
          },

          rainbow = {
            enable = true,
            -- list of languages you want to disable the plugin for
            -- disable = { "jsx", "cpp" },
            -- Which query to use for finding delimiters
            query = 'rainbow-parens',
            -- Highlight the entire buffer all at once
            strategy = require 'ts-rainbow.strategy.global',
          }

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
            end
          }
