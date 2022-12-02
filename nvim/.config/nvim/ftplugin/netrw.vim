" this snippet is taken from https://github.com/smancill/Vim_config/commit/f35be7543162159739af7613af44c61721b6076e
" workaround for netrw buffers resisting :bd https://github.com/tpope/vim-vinegar/issues/13#issuecomment-47133890
autocmd FileType netrw setl bufhidden=wipe
" setlocal bufhidden=delete

if !exists("*s:BDeleteNetrw")
  function! s:BDeleteNetrw()
    for i in range(bufnr('$'), 1, -1)
      if buflisted(i)
        if getbufvar(i, 'netrw_browser_active') == 1
          silent exe 'bdelete ' . i
        endif
      endif
    endfor
  endfunction
endif

augroup netrw_buffergator
  autocmd! * <buffer>
  autocmd BufLeave <buffer> call s:BDeleteNetrw()
augroup END

