if exists("g:intero_loaded") || &compatible || v:version < 700
    finish
endif
let g:intero_loaded = 1

command! InteroToggleGHCi :call intero#ghci_toggle()<CR>
command! InteroToggleStackBuild :call intero#stack_build_toggle()<CR>

nnoremap <Plug>intero_toggle_ghci :<C-U>call intero#ghci_toggle()<CR>
nnoremap <Plug>intero_toggle_stack_build :<C-U>call intero#stack_build_toggle()<CR>
