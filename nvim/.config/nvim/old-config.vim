" call plug#begin('~/.config/nvim/plugged')
 
" " color scheme
" Plug 'morhetz/gruvbox'
" Plug 'vim-airline/vim-airline'

" " git related plugins
" Plug 'tpope/vim-fugitive'
" Plug 'airblade/vim-gitgutter'
" " Plug 'neoclide/coc.nvim', {'tag': '*', 'do': { -> coc#util#install()}}
" " CocInstall coc-tsserver coc-gocode

" " language related plugins
" Plug 'sheerun/vim-polyglot'
" Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
" " https://github.com/neovim/nvim-lspconfig
" Plug 'neovim/nvim-lspconfig'

" " Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
" " Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
" " Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoUpdateBinaries' }

" " file orientation plugins
" Plug 'tpope/vim-vinegar'
" Plug 'justinmk/vim-sneak'
" Plug 'tpope/vim-surround'
" Plug 'junegunn/fzf'
" Plug 'junegunn/fzf.vim'
" Plug 'milkypostman/vim-togglelist'
" " Plug 'pgr0ss/vim-github-url'

" " Autocomplete
" " https://github.com/hrsh7th/nvim-cmp
" Plug 'hrsh7th/cmp-nvim-lsp'
" Plug 'hrsh7th/cmp-buffer'
" Plug 'hrsh7th/cmp-path'
" Plug 'hrsh7th/cmp-cmdline'
" Plug 'hrsh7th/nvim-cmp'
" Plug 'hrsh7th/vim-vsnip'
" " general code helping plugins
" Plug 'tpope/vim-commentary'
" Plug 'w0rp/ale'
" Plug 'prettier/vim-prettier', {
"   \ 'do': 'yarn install',
"   \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'vue', 'yaml', 'html'] }



" call plug#end()

let mapleader=" "
set termguicolors
:colorscheme gruvbox
set background=dark    " Setting dark mode
" cliboard is the default register
" set clipboard=unnamedplus
" x doesn't write to default cliboard
noremap x "_x
" vim waits 500ms after I'm finished editing before it tells plugins to do
" their thing (mainly gitgutter)
set updatetime=500
set hidden
" PLUGINS #####################################################

:set completeopt=longest,menuone

let g:vimsyn_embed = 'l'

set completeopt=menu,menuone,noselect


let b:ale_fixers = {
      \'javascript': ['prettier', 'eslint'],
      \'typescript': ['tslint'],
      \}
"\'go': ['golint'],
" let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 0

let g:prettier#quickfix_enabled = 0

" Prettier
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.vue,*.yaml,*.html PrettierAsync

" JavaScript
" TODO: more generic
" autocmd Filetype javascript nnoremap <leader>rt :!npm run mocha -- %<cr>

set grepprg=ag\ --nogroup\ --nocolor

augroup openQuickFixAutomatically
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
  autocmd QuickFixCmdPost l*    lwindow
augroup END

nnoremap [q :cprev<cr>
nnoremap ]q :cnext<cr>

let g:toggle_list_no_mappings=1
nnoremap <leader>q :call ToggleQuickfixList()<CR>

nnoremap <leader><leader> :<c-p><cr>
" incremental search and search highlighting
" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

set cursorline
set number

" completion mode for files and scripts
set wildmode=longest:full
" ignore files in file searches
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/node_modules/*,*/bower_components/*,*/target/*,*/vendor/*

" leader s mapped to toggle spell check
nmap <silent> <leader>s :set spell!<CR>
set spell

" I don't want to se Ex mode ever again
nnoremap Q :bd<cr>

"Indent parameters
" https://stackoverflow.com/questions/1878974/redefine-tab-as-4-spaces
set autoindent
set expandtab
set shiftwidth=2
set tabstop=4

" Backup and undo config taken from https://begriffs.com/posts/2019-07-19-history-use-vim.html
" Protect changes between writes. Default values of
" updatecount (200 keystrokes) and updatetime
" (4 seconds) are fine
set swapfile
set directory^=~/.vim/swap//

" protect against crash-during-write
set writebackup
" but do not persist backup after successful write
set nobackup
" use rename-and-write-new method whenever safe
set backupcopy=auto
" patch required to honor double slash at end
if has("patch-8.1.0251")
	" consolidate the writebackups -- not a big
	" deal either way, since they usually get deleted
	set backupdir^=~/.vim/backup//
end
" persist the undo tree for each file
set undofile
set undodir^=~/.vim/undo//
set undolevels=1000
set undoreload=10000

"more natural split opening
set splitbelow
set splitright


" Enable mouse
set mouse=a
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" FZF customisation
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

nnoremap <silent> <C-p> :FZF -m<cr>
nnoremap <silent> gb :Buffers<cr>
nnoremap <silent> // :History/<cr>
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MISC KEY MAPS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Move around splits with <c-hjkl>
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

"  move text and rehighlight -- vim tip_id=224 
vnoremap > ><CR>gv 
vnoremap < <<CR>gv 

"air line settings
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1

nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> [B :bfirst<CR>
nnoremap <silent> ]B :blast<CR>

" copied from https://github.com/nelstrom/vim-visual-star-search
function! s:VSetSearch(cmdtype)
  let temp = @s
  norm! gv"sy
  let @/ = '\V' . substitute(escape(@s, a:cmdtype.'\'), '\n', '\\n', 'g')
  let @s = temp
endfunction

xnoremap * :<C-u>call <SID>VSetSearch('/')<CR>/<C-R>=@/<CR><CR>
xnoremap # :<C-u>call <SID>VSetSearch('?')<CR>?<C-R>=@/<CR><CR>

