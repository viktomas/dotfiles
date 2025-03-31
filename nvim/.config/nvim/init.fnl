;; Setup plugins with minipack
(local minipack (require :plugins.minipack))
(minipack.setup {:verbose true
                 :plugins [{:url "https://github.com/stevearc/oil.nvim.git"
                            :ref :master}
                           {:url "https://github.com/folke/tokyonight.nvim.git"
                            :ref :v4.11.0}
                           {:url "https://github.com/nvim-treesitter/nvim-treesitter.git"
                            :ref :aece1062335a9e856636f5da12d8a06c7615ce8a}
                           {:url "https://github.com/ibhagwan/fzf-lua.git"
                            :ref :a33d382df077563bfd332d9d12942badbd096d2b}
                           {:url "https://github.com/neovim/nvim-lspconfig.git"
                            :ref :0a1ac55d7d4ec2b2ed9616dfc5406791234d1d2b}]})

;; Set colorscheme
(vim.cmd.colorscheme :tokyonight)

;; Setup oil.nvim
(local oil (require :oil))
(oil.setup)
(vim.keymap.set :n "-" :<CMD>Oil<CR> {:desc "Open parent directory"})

;; Set leader key
(set vim.g.mapleader " ")

;; Setup fzf-lua
(local fzf (require :fzf-lua))
(vim.keymap.set :n :<leader>f fzf.files)
(vim.keymap.set :n "//" fzf.live_grep)

;; Window navigation keymaps
(vim.keymap.set :n :<C-h> :<C-w>h)
(vim.keymap.set :n :<C-l> :<C-w>l)
(vim.keymap.set :n :<C-j> :<C-w>j)
(vim.keymap.set :n :<C-k> :<C-w>k)

;; Clipboard keymaps
(vim.keymap.set [:n :v] :<leader>y "\"+y")
(vim.keymap.set [:n :v] :<leader>p "\"+p")

;; Load LSP configuration
(require :plugins.lsp)

;; Setup Treesitter
(local treesitter-configs (require :nvim-treesitter.configs))
(treesitter-configs.setup {:ensure_installed [:lua
                                              :markdown
                                              :markdown_inline
                                              :typescript
                                              :javascript
                                              :go]
                           :sync_install false
                           :auto_install true
                           :highlight {:enable true
                                       :additional_vim_regex_highlighting false}})

;; Load user options
(require :user.options)
