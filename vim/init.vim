call plug#begin('~/.config/nvim/plugged')
 
" color scheme
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'

" git related plugins
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" language related plugins
" Plug 'groenewege/vim-less', { 'for': 'less' }
" Plug 'derekwyatt/vim-scala', { 'for': 'scala' }
" Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
" Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
" Plug 'mxw/vim-jsx', { 'for': 'javascript' }
Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoUpdateBinaries' }
" Plug 'mdempsky/gocode', { 'rtp': 'nvim', 'do': '~/.config/nvim/plugged/gocode/nvim/symlink.sh' }
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }

" file orientation plugins
Plug 'tpope/vim-vinegar'
Plug 'junegunn/fzf'
Plug 'wincent/ferret'
Plug 'sjbach/lusty'

" general code helping plugins
Plug 'tpope/vim-commentary'
Plug 'w0rp/ale'
" Plug 'prettier/vim-prettier', {
"   \ 'do': 'yarn install',
"   \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'yaml', 'html'] }

Plug 'autozimu/LanguageClient-neovim', {
\ 'branch': 'next',
\ 'do': 'bash install.sh',
\ }


call plug#end()

set termguicolors
:colorscheme gruvbox
set background=dark    " Setting dark mode
set hidden
" HELP
:helptags ~/.config/nvim/doc
autocmd BufWritePost ~/.vim/doc/* :helptags ~/.config/nvim/doc

" PLUGINS #####################################################

" Deoplete
let g:deoplete#enable_at_startup = 1
" deoplete tab-complete
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
inoremap <expr><CR> pumvisible() ? "\<c-y>" : "\<CR>"

let b:ale_fixers = {
      \'javascript': ['prettier', 'eslint'],
      \'go': ['golint'],
      \'typescript': ['tslint'],
      \}
let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 0

" Language client
let g:LanguageClient_rootMarkers = {
        \ 'go': ['.git', 'go.mod'],
        \ }

let g:LanguageClient_serverCommands = {
    \ 'javascript': ['~/workspace/javascript-typescript-langserver/lib/language-server-stdio.js'],
    \ 'typescript': ['~/workspace/javascript-typescript-langserver/lib/language-server-stdio.js'],
    \ }

noremap gr :call LanguageClient#textDocument_rename()<CR>

" Prettier
let g:prettier#autoformat = 0
autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.md,*.vue,*.yaml,*.html PrettierAsync

" JavaScript
" TODO: more generic
autocmd Filetype javascript nnoremap <leader>rt :!npm run mocha -- %<cr>


" incremental search and search highlighting
" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

set cursorline
set number

" completion mode for files and scripts
set wildmode=longest:full
" ignore files in file searches
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/node_modules/*,*/bower_components/*,*/target/*,*/vendor/*
let mapleader=" "

" leader s mapped to toggle spell chec
nmap <silent> <leader>s :set spell!<CR>

" I don't want to se Ex mode ever again
nnoremap Q <nop>

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
""""""""""""""""""""""""""""""""""""""""""""""
" MARKDOWN
" """""""""""""""""""""""""""""""""""""""""""
" let g:vim_markdown_folding_disabled=1
" let g:vim_markdown_no_default_key_mappings=1
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" RENAME CURRENT FILE
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function! RenameFile()
"     let old_name = expand('%')
"     let new_name = input('New file name: ', expand('%'), 'file')
"     if new_name != '' && new_name != old_name
"         exec ':saveas ' . new_name
"         exec ':silent !rm ' . old_name
"         redraw!
"     endif
" endfunction
" map <leader>m :call RenameFile()<cr>
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" FZF customisation
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" command! FZFMru call fzf#run({
" \  'source':  reverse(s:all_files()),
" \  'sink':    'e',
" \  'options': '-m -x +s',
" \  'down':    '40%'})

" function! s:all_files()
"   return extend(
"   \ filter(copy(v:oldfiles),
"   \        "v:val !~ 'fugitive:\\|NERD_tree\\|^/tmp/\\|.git/'"),
"   \ map(filter(range(1, bufnr('$')), 'buflisted(v:val)'), 'bufname(v:val)'))
" endfunction

nnoremap <silent> <C-p> :FZF -m<cr>
" nnoremap <silent> <C-e> :FZFMru<cr>
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GO Key maps
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" au FileType go nmap <Leader>e <Plug>(go-rename)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MULTIPURPOSE TAB KEY
" Indent if we're at the beginning of a line. Else, do completion.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function! InsertTabWrapper()
"     let col = col('.') - 1
"     if !col || getline('.')[col - 1] !~ '\k'
"         return "\<tab>"
"     else
"         return "\<c-p>"
"     endif
" endfunction
" inoremap <tab> <c-r>=InsertTabWrapper()<cr>
" inoremap <s-tab> <c-n>

" nnoremap <c-t> :call Eisenhower()<cr>
""""""""""""""""""
" Grep config
""""""""""""""""""""
" open quick fix after grep
" autocmd QuickFixCmdPost *grep* cwindow
" if executable('git')
"   " Note we extract the column as well as the file and line number
"   set grepprg=~/bin/git_grep.sh
"   set grepformat=%f:%l:%c:%m
" endif
" nnoremap K :grep! "\b<C-R><C-W>\b"<CR>:cw<CR><CR>

" disable weird markdown formatting
" let g:vim_markdown_new_list_item_indent = 0

"air line uses powerline fonts
" let g:airline_powerline_fonts = 1

" automatically run neomake
" autocmd! BufWritePost,BufEnter * Neomake
" let g:neomake_javascript_enabled_makers = ['eslint']

" JSX plugin will run on js files
" let g:jsx_ext_required = 0

" function! ToggleErrors()
"     let old_last_winnr = winnr('$')
"     lclose
"     if old_last_winnr == winnr('$')
"     lopen
"     endif
" endfunction
" nnoremap <silent> <C-s> :<C-u>call ToggleErrors()<CR>

" nnoremap <silent> [b :bprevious<CR>
" nnoremap <silent> ]b :bnext<CR>
" nnoremap <silent> [B :bfirst<CR>
" nnoremap <silent> ]B :blast<CR>

" function! Eisenhower()
"   execute "edit ~/.eisenhower/1.md"
"   execute "vs"
"   execute "edit ~/.eisenhower/2.md"
"   execute "split"
"   execute "edit ~/.eisenhower/4.md"
"   execute "wincmd h"
"   execute "split"
"   execute "edit ~/.eisenhower/3.md"
"   execute "wincmd k"
" endfunction
