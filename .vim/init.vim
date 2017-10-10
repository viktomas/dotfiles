call plug#begin('~/.vim/plugged')

" git related plugins
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" language related plugins
Plug 'groenewege/vim-less', { 'for': 'less' }
Plug 'derekwyatt/vim-scala', { 'for': 'scala' }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'mxw/vim-jsx', { 'for': 'javascript' }
Plug 'fatih/vim-go', { 'for': 'go' }

" file orientation plugins
Plug 'tpope/vim-vinegar'
Plug 'ctrlpvim/ctrlp.vim'

" general code helping plugins
Plug 'tpope/vim-unimpaired'
Plug 'SirVer/ultisnips'
Plug 'Valloric/YouCompleteMe'
Plug 'neomake/neomake'
Plug 'bling/vim-airline'

" color schemes
Plug 'w0ng/vim-hybrid'
Plug 'altercation/vim-colors-solarized'
" Plug 'gilgigilgil/anderson.vim'

call plug#end()

" let's try it without my first vim command
"inoremap jj <ESC>

"molokai color scheme
"set t_Co=256
set background=dark
let $COLORTERM='xterm-256color'
colorscheme hybrid
syntax enable

set nocompatible      " We're running Vim, not Vi!
filetype on           " Enable filetype detection
filetype indent on    " Enable filetype-specific indenting
filetype plugin on    " Enable filetype-specific plugins

" incremental search and search highlighting
set incsearch
set hlsearch
" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

set cursorline
set number

" double exclamation mark means I'll write it as a root
cnoremap w!! w !sudo tee >/dev/null %

" use emacs-style tab completion when selecting files, etc
set wildmode=longest,list
" make tab completion for files/buffers act like bash
set wildmenu
" ignore files in file searches
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*/node_modules/*,*/bower_components/*,*/target/*,*/atlas_thin/*
let mapleader=","

" leader s mapped to toggle spell chec
nmap <silent> <leader>s :set spell!<CR>

" I don't want to se that motherfu*king Ex mode ever again
nnoremap Q <nop>
""""""" Retarded OSX """"""""
" make backspace work like most other apps
set backspace=indent,eol,start
" mouse in vim
set mouse=a
""""""" EO Retarded OSX """""""

"Ident parameters
set autoindent
set expandtab
set shiftwidth=2
set softtabstop=2

" Don't make backups at all
set nobackup
set nowritebackup
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp

"more natural split opening
set splitbelow
set splitright

" Persistend undo
set undofile
set undodir=~/.vim/undo
set undolevels=1000
set undoreload=10000
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CUSTOM AUTOCMDS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
augroup vimrcEx
" Clear all autocmds in the group
  autocmd!
  autocmd FileType text setlocal textwidth=78
" Jump to last cursor position unless it's invalid or in an event handler
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \ exe "normal g`\"" |
    \ endif

  autocmd BufRead *.markdown set ai formatoptions=tcroqn2 comments=n:&gt;

""""""""""""""""""""""""""""""""""""""""""""""
" MARKDOWN
" """""""""""""""""""""""""""""""""""""""""""
let g:vim_markdown_folding_disabled=1
let g:vim_markdown_no_default_key_mappings=1
augroup END
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" RENAME CURRENT FILE
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! RenameFile()
    let old_name = expand('%')
    let new_name = input('New file name: ', expand('%'), 'file')
    if new_name != '' && new_name != old_name
        exec ':saveas ' . new_name
        exec ':silent !rm ' . old_name
        redraw!
    endif
endfunction
map <leader>m :call RenameFile()<cr>
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MISC KEY MAPS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <leader>y "*y
map <leader>p "*p
" Move around splits with <c-hjkl>
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l
" Insert a hash rocket with <c-l>
imap <c-l> <space>=><space>
nnoremap <leader><leader> <c-^>
" clear search buffer when hitting enter (except for when in quickfix buffer)
:nnoremap <expr> <CR> (&buftype is# "quickfix" ? "<CR>" : ":\:nohlsearch<cr>\n")

"  move text and rehighlight -- vim tip_id=224 
vnoremap > ><CR>gv 
vnoremap < <<CR>gv 

nmap gf <C-P><C-\>w
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MULTIPURPOSE TAB KEY
" Indent if we're at the beginning of a line. Else, do completion.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <tab> <c-r>=InsertTabWrapper()<cr>
inoremap <s-tab> <c-n>

""""""""""""""""""
" Grep config
""""""""""""""""""""
" open quick fix after grep
autocmd QuickFixCmdPost *grep* cwindow
if executable('git')
  " Note we extract the column as well as the file and line number
  set grepprg=~/bin/git_grep.sh
  set grepformat=%f:%l:%c:%m
endif
nnoremap K :grep! "\b<C-R><C-W>\b"<CR>:cw<CR><CR>

" disable weird markdown formatting
let g:vim_markdown_new_list_item_indent = 0

"air line uses powerline fonts
let g:airline_powerline_fonts = 1

" automatically run neomake
autocmd! BufWritePost,BufEnter * Neomake
let g:neomake_javascript_enabled_makers = ['eslint']

" JSX plugin will run on js files
let g:jsx_ext_required = 0

function! ToggleErrors()
    let old_last_winnr = winnr('$')
    lclose
    if old_last_winnr == winnr('$')
    lopen
    endif
endfunction
nnoremap <silent> <C-s> :<C-u>call ToggleErrors()<CR>

nnoremap <silent> [b :bprevious<CR>
nnoremap <silent> ]b :bnext<CR>
nnoremap <silent> [B :bfirst<CR>
nnoremap <silent> ]B :blast<CR>
