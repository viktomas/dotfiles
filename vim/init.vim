call plug#begin('~/.config/nvim/plugged')
 
" color scheme
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'

" git related plugins
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" language related plugins
Plug 'sheerun/vim-polyglot'
" Plug 'groenewege/vim-less', { 'for': 'less' }
" Plug 'derekwyatt/vim-scala', { 'for': 'scala' }
" Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
" Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
" Plug 'mxw/vim-jsx', { 'for': 'javascript' }
Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoUpdateBinaries' }
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }

" file orientation plugins
Plug 'tpope/vim-vinegar'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'milkypostman/vim-togglelist'
Plug 'pgr0ss/vim-github-url'

" general code helping plugins
Plug 'tpope/vim-commentary'
Plug 'w0rp/ale'
Plug 'prettier/vim-prettier', {
  \ 'do': 'yarn install',
  \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'yaml', 'html'] }

Plug 'autozimu/LanguageClient-neovim', {
\ 'branch': 'next',
\ 'do': 'bash install.sh',
\ }


call plug#end()

let mapleader=" "
set termguicolors
:colorscheme gruvbox
set background=dark    " Setting dark mode
" cliboard is the default register
set clipboard=unnamedplus
" x doesn't write to default cliboard
noremap x "_x
" vim waits 500ms after I'm finished editing before it tells plugins to do
" their thing (mainly gitgutter)
set updatetime=500
set hidden
" HELP
:helptags ~/.config/nvim/doc
autocmd BufWritePost ~/.vim/doc/* :helptags ~/.config/nvim/doc
" autocmd BufRead,BufNewFile *.hbs setlocal filetype=hbs
" Polyglot don't set jsx as default for all javascript
" potential problem when working with REACT again
let g:jsx_ext_required = 1
" let g:polyglot_disabled = ['go']
" PLUGINS #####################################################

" Deoplete
let g:deoplete#enable_at_startup = 1
" deoplete tab-complete
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
inoremap <expr><CR> pumvisible() ? "\<c-y>" : "\<CR>"

let b:ale_fixers = {
      \'javascript': ['prettier', 'eslint'],
      \'typescript': ['tslint'],
      \}
" let g:ale_fix_on_save = 1
" \'go': ['golint'],
let g:ale_completion_enabled = 0

" Language client
let g:LanguageClient_rootMarkers = {
        \ 'javascript': ['package.json'],
        \ }
        " \ 'go': ['.git', 'go.mod'],

let g:LanguageClient_serverCommands = {
    \ 'javascript': ['~/workspace/javascript-typescript-langserver/lib/language-server-stdio.js'],
    \ 'javascript.jsx': ['~/workspace/javascript-typescript-langserver/lib/language-server-stdio.js'],
    \ 'typescript': ['~/workspace/javascript-typescript-langserver/lib/language-server-stdio.js'],
    \ }
" \ 'go': ['go-langserver'],

let g:prettier#quickfix_enabled = 0
noremap gr :call LanguageClient#textDocument_rename()<CR>

" Prettier
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.md,*.vue,*.yaml,*.html PrettierAsync

" JavaScript
" TODO: more generic
autocmd Filetype javascript nnoremap <leader>rt :!npm run mocha -- %<cr>

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

" incremental search and search highlighting
" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

set cursorline
set number

" completion mode for files and scripts
set wildmode=longest:full
" ignore files in file searches
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/node_modules/*,*/bower_components/*,*/target/*,*/vendor/*

" leader s mapped to toggle spell chec
nmap <silent> <leader>s :set spell!<CR>

" I don't want to se Ex mode ever again
nnoremap Q :bd<cr>

"Ident parameters
" https://stackoverflow.com/questions/1878974/redefine-tab-as-4-spaces
set autoindent
set expandtab
set shiftwidth=2
set tabstop=4

" Don't make backups at all
set nobackup
set nowritebackup

"more natural split opening
set splitbelow
set splitright

" Persistend undo
set undofile
set undodir=~/.config/nvim/undo
set undolevels=1000
set undoreload=10000

" Enable mouse
set mouse=a
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" FZF customisation
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! FZFMru call fzf#run({
\  'source':  reverse(s:all_files()),
\  'sink':    'e',
\  'options': '-m -x +s',
\  'down':    '40%'})

command! -bang -nargs=* FZFGrep
  \ call fzf#vim#grep(
  \   'ag --nogroup --nocolor --column '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0,
  \ )

function! s:all_files()
  return extend(
  \ filter(copy(v:oldfiles),
  \        "v:val !~ 'fugitive:\\|NERD_tree\\|^/tmp/\\|.git/'"),
  \ map(filter(range(1, bufnr('$')), 'buflisted(v:val)'), 'bufname(v:val)'))
endfunction

nnoremap <silent> <C-p> :FZF -m<cr>
nnoremap <silent> <C-e> :FZFMru<cr>
nnoremap <silent> <C-f> :FZFGrep! 
" nnoremap gf :call fzf#run({'sink': 'e', 'options': '-q '.shellescape(expand('<cword>')), 'down': '~40%'})<cr>
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MISC KEY MAPS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Move around splits with <c-hjkl>
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l
" nnoremap <leader><leader> <c-^> TODO: this alternate file might be useful
" clear search buffer when hitting enter (except for when in quickfix buffer)
:nnoremap <expr> <CR> (&buftype is# "quickfix" ? "<CR>" : ":\:nohlsearch<cr>\n")

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

