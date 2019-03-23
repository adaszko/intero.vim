function! s:warning(msg) " {{{
    echohl WarningMsg
    echo 'intero.vim:' a:msg
    echohl None
endfunction " }}}
function! s:error(msg) " {{{
    echohl ErrorMsg
    echo 'markdown:' a:msg
    echohl None
endfunction " }}}
function! s:stack_build_open() " {{{
    if s:stack_build_is_open()
        echo "Stack build is already running"
        return
    endif
    let options = {
                \ 'term_finish': 'close',
                \ 'stoponexit': 'quit',
                \ 'term_kill': 'quit',
                \ 'vertical': 1,
                \ 'norestore': 1,
                \ }
    let g:haskell_stack_build_buffer = term_start('stack build --file-watch --fast', options)
    execute "normal \<c-w>p"
endfunction " }}}
function! s:stack_build_close() " {{{
    if !exists('g:haskell_stack_build_buffer')
        let g:haskell_stack_build_buffer = 0
    endif
    if g:haskell_stack_build_buffer == 0 || !bufloaded(g:haskell_stack_build_buffer)
        return
    endif
    execute printf('silent bdelete! %d', g:haskell_stack_build_buffer)
    let g:haskell_stack_build_buffer = 0
endfunction " }}}
function! s:stack_build_is_open() " {{{
    return exists('g:haskell_stack_build_buffer') && g:haskell_stack_build_buffer != 0 && bufloaded(g:haskell_stack_build_buffer)
endfunction " }}}
function! intero#stack_build_toggle() " {{{
    if s:stack_build_is_open()
        call s:stack_build_close()
    else
        call s:stack_build_open()
    endif
endfunction " }}}
function! s:ghci_open() " {{{
    if s:haskell_ghci_is_open()
        call s:warning("GHCi is already running")
        return
    endif

    let options = {
                \ 'term_finish': 'close',
                \ 'stoponexit': 'quit',
                \ 'term_kill': 'quit',
                \ 'vertical': 1,
                \ 'norestore': 1,
                \ }
    let g:intero_ghci_buffer = term_start('stack ghci --with-ghc intero', options)
    execute "normal \<c-w>p"
endfunction " }}}
function! s:ghci_close() " {{{
    if !exists('g:intero_ghci_buffer')
        let g:intero_ghci_buffer = 0
    endif
    if g:intero_ghci_buffer == 0 || !bufloaded(g:intero_ghci_buffer)
        return
    endif
    execute printf('silent bdelete! %d', g:intero_ghci_buffer)
    let g:intero_ghci_buffer = 0
endfunction " }}}
function! s:haskell_ghci_is_open() " {{{
    return exists('g:intero_ghci_buffer') && g:intero_ghci_buffer != 0 && bufloaded(g:intero_ghci_buffer)
endfunction " }}}
function! intero#ghci_toggle() " {{{
    if s:haskell_ghci_is_open()
        call s:ghci_close()
    else
        call s:ghci_open()
    endif
endfunction " }}}
function! intero#send_line(string) " {{{
    if !exists('g:intero_ghci_buffer')
        let g:intero_ghci_buffer = 0
    endif
    if g:intero_ghci_buffer == 0 || !bufloaded(g:intero_ghci_buffer)
        call s:error('Please start GHCi first')
        return
    endif
    let line = printf("%s\<c-m>", a:string)
    call term_sendkeys(g:intero_ghci_buffer, line)
endfunction " }}}
function! intero#type_at(start_line, start_col, end_line, end_col, label) " {{{
    let module = expand("%:t:r")
    let command = printf(":type-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_line(command)
endfunction " }}}
function! intero#type_at_cursor() " {{{
    let [_, line, col, _] = getpos(".")
    let label = expand("<cword>")
    call intero#type_at(line, col, line, col, label)
endfunction " }}}
function! intero#get_selection() range " {{{
    let reg_save = getreg('"')
    let regtype_save = getregtype('"')
    let cb_save = &clipboard
    set clipboard&
    normal! ""gvy
    let selection = getreg('"')
    call setreg('"', reg_save, regtype_save)
    let &clipboard = cb_save
    return selection
endfunction " }}}
function! intero#type_of_selection() " {{{
    let [_, start_line, start_col, _] = getpos("'<")
    let [_, end_line, end_col, _] = getpos("'>")
    let selection = intero#get_selection()
    call intero#type_at(start_line, start_col, end_line, end_col, selection)
endfunction " }}}
function! intero#loc_at_cursor() " {{{
    let module = expand("%:t:r")
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let command = printf(":loc-at %s %d %d %d %d %s", module, lnum, col, lnum, col, label)
    call intero#send_line(command)
endfunction " }}}
function! intero#uses_at_cursor() " {{{
    let module = expand("%:t:r")
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let command = printf(":uses %s %d %d %d %d %s", module, lnum, col, lnum, col, label)
    call intero#send_line(command)
endfunction " }}}
function! intero#all_types() " {{{
    let module = expand("%:t:r")
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let command = printf(":all-types", module, lnum, col, lnum, col, label)
    call intero#send_line(command)
endfunction " }}}
function! intero#complete_at_cursor() " {{{
    let module = expand("%:t:r")
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let command = printf(":complete-at %s %d %d %d %d %s", module, lnum, col, lnum, col, label)
    call intero#send_line(command)
endfunction " }}}


" vim:foldmethod=marker
