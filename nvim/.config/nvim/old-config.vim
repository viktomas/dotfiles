let mapleader=" "
:colorscheme gruvbox
set background=dark    " Setting dark mode
" cliboard is the default register
" set clipboard=unnamedplus
" x doesn't write to default cliboard
noremap x "_x
" vim waits 500ms after I'm finished editing before it tells plugins to do
" their thing (mainly gitgutter)
" PLUGINS #####################################################


let g:vimsyn_embed = 'l'


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


" leader s mapped to toggle spell check
nmap <silent> <leader>s :set spell!<CR>

" I don't want to se Ex mode ever again
nnoremap Q :bd<cr>


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

