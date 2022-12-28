" cliboard is the default register
" set clipboard=unnamedplus
" vim waits 500ms after I'm finished editing before it tells plugins to do
" their thing (mainly gitgutter)
" PLUGINS #####################################################

let g:vimsyn_embed = 'l'

let g:hardtime_default_on = 1
let g:list_of_normal_keys = ["h", "j", "k", "l", "+", "<UP>", "<DOWN>", "<LEFT>", "<RIGHT>"]

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

augroup openQuickFixAutomatically
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
  autocmd QuickFixCmdPost l*    lwindow
augroup END

let g:toggle_list_no_mappings=1
nnoremap <leader>q :call ToggleQuickfixList()<CR>


" leader s mapped to toggle spell check
nmap <silent> <leader>s :set spell!<CR>

" I don't want to se Ex mode ever again
nnoremap Q :bd<cr>


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MISC KEY MAPS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"air line settings
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1


" copied from https://github.com/nelstrom/vim-visual-star-search
function! s:VSetSearch(cmdtype)
  let temp = @s
  norm! gv"sy
  let @/ = '\V' . substitute(escape(@s, a:cmdtype.'\'), '\n', '\\n', 'g')
  let @s = temp
endfunction

xnoremap * :<C-u>call <SID>VSetSearch('/')<CR>/<C-R>=@/<CR><CR>
xnoremap # :<C-u>call <SID>VSetSearch('?')<CR>?<C-R>=@/<CR><CR>

" Run neoformat on saving a file
"[sbdchd/neoformat: A (Neo)vim plugin for formatting code.](https://github.com/sbdchd/neoformat)
"
" The `undojoin` command will put changes made by Neoformat into the same `undo-block` with the latest preceding change.
" See [Managing Undo History](https://github.com/sbdchd/neoformat#managing-undo-history).
" The catch tweak is from https://github.com/sbdchd/neoformat/issues/134#issuecomment-1034726786
" it fixes the issue when I try to save file after undo
augroup fmt
  autocmd!
  au BufWritePre * try | undojoin | Neoformat | catch /E790/ | Neoformat | endtry
augroup END

