
" let g:ale_fixers = {
"       \'javascript': ['prettier', 'eslint'],
"       \'sh': ['shellcheck'],
"       \}
" let g:ale_completion_enabled = 0
" let g:ale_use_neovim_diagnostics_api = 1
" let g:ale_virtualtext_cursor = 'disabled' " this disables ALE virtual text and relies solely on diagnostics API

augroup openQuickFixAutomatically
  autocmd!
  autocmd QuickFixCmdPost [^l]* cwindow
  autocmd QuickFixCmdPost l*    lwindow
augroup END

let g:toggle_list_no_mappings=1

nnoremap <leader>q :call ToggleQuickfixList()<CR>

nnoremap Q :bd<cr>


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MISC KEY MAPS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" copied from https://github.com/nelstrom/vim-visual-star-search
function! s:VSetSearch(cmdtype)
  let temp = @s
  norm! gv"sy
  let @/ = '\V' . substitute(escape(@s, a:cmdtype.'\'), '\n', '\\n', 'g')
  let @s = temp
endfunction

xnoremap * :<C-u>call <SID>VSetSearch('/')<CR>/<C-R>=@/<CR><CR>
xnoremap # :<C-u>call <SID>VSetSearch('?')<CR>?<C-R>=@/<CR><CR>
