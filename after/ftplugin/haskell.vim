if exists("b:did_intero_after_ftplugin") | finish | endif
let b:did_intero_after_ftplugin = 1


let s:cpo_save = &cpo
set cpo&vim

call intero#ensure_started()

augroup intero.vim
    autocmd!
    autocmd ExitPre * call intero#stop()
augroup END


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:foldmethod=marker
