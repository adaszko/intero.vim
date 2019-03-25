if exists("g:intero_loaded") || &compatible || v:version < 700
    finish
endif
let g:intero_loaded = 1

command! InteroToggle :call intero#toggle()<CR>
command! InteroToggleStackBuild :call intero#stack_build_toggle()<CR>

nnoremap <Plug>intero_toggle :<C-U>call intero#toggle()<CR>
nnoremap <Plug>intero_toggle_stack_build :<C-U>call intero#stack_build_toggle()<CR>
