function! intero#warning(msg) " {{{
    echohl WarningMsg
    echo 'intero.vim:' a:msg
    echohl None
endfunction " }}}
function! intero#error(msg) " {{{
    echohl ErrorMsg
    echo 'markdown:' a:msg
    echohl None
endfunction " }}}

function! intero#stack_build_open() " {{{
    if intero#stack_build_is_open()
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
function! intero#stack_build_close() " {{{
    if !exists('g:haskell_stack_build_buffer')
        let g:haskell_stack_build_buffer = 0
    endif
    if g:haskell_stack_build_buffer == 0 || !bufloaded(g:haskell_stack_build_buffer)
        return
    endif
    execute printf('silent bdelete! %d', g:haskell_stack_build_buffer)
    let g:haskell_stack_build_buffer = 0
endfunction " }}}
function! intero#stack_build_is_open() " {{{
    return exists('g:haskell_stack_build_buffer') && g:haskell_stack_build_buffer != 0 && bufloaded(g:haskell_stack_build_buffer)
endfunction " }}}
function! intero#stack_build_toggle() " {{{
    if intero#stack_build_is_open()
        call intero#stack_build_close()
    else
        call intero#stack_build_open()
    endif
endfunction " }}}

function! intero#callback(channel, message) " {{{
    if exists('g:intero_service_port') && g:intero_service_port
        return
    endif

    let lines = split(a:message, "\r")

    if exists('g:intero_previous_truncated_line')
        let lines[0] = g:intero_previous_truncated_line . lines[0]
    endif

    let last = lines[-1]
    if last[strlen(last)-1] != ""
        let g:intero_previous_truncated_line = lines[-1]
        call remove(lines, -1)
    endif

    for line in lines
        let port = matchstr(line, '\vIntero-Service-Port: \zs\d+\ze')
        if len(port) > 0
            let g:intero_service_port = port
            return
        endif
    endfor
endfunction " }}}
function! intero#open() " {{{
    if intero#is_open()
        call intero#warning("GHCi is already running")
        return
    endif

    let options = {
    \ 'term_finish': 'close',
    \ 'stoponexit': 'quit',
    \ 'term_kill': 'quit',
    \ 'vertical': 1,
    \ 'norestore': 1,
    \ 'callback': function('intero#callback'),
    \ }
    let g:intero_ghci_buffer = term_start('stack ghci --with-ghc intero', options)
    execute "normal \<c-w>p"
endfunction " }}}
function! intero#close() " {{{
    if !exists('g:intero_ghci_buffer')
        let g:intero_ghci_buffer = 0
    endif
    if g:intero_ghci_buffer == 0 || !bufloaded(g:intero_ghci_buffer)
        return
    endif

    if exists('g:intero_service_port')
        unlet g:intero_service_port
    endif

    if exists('g:intero_service_channel')
        unlet g:intero_service_channel
    endif

    execute printf('silent bdelete! %d', g:intero_ghci_buffer)
    unlet g:intero_ghci_buffer
endfunction " }}}
function! intero#is_open() " {{{
    return exists('g:intero_ghci_buffer') && g:intero_ghci_buffer != 0 && bufloaded(g:intero_ghci_buffer)
endfunction " }}}
function! intero#ghci_toggle() " {{{
    if intero#is_open()
        call intero#close()
    else
        call intero#open()
    endif
endfunction " }}}
function! intero#send_line(string) " {{{
    if !exists('g:intero_ghci_buffer')
        let g:intero_ghci_buffer = 0
    endif
    if g:intero_ghci_buffer == 0 || !bufloaded(g:intero_ghci_buffer)
        call intero#error('Please start GHCi first')
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
function! intero#type_of_selection() range " {{{
    let [_, start_line, start_col, _] = getpos("'<")
    let [_, end_line, end_col, _] = getpos("'>")
    let selection = intero#get_selection()

    if a:firstline == a:lastline
        let label = selection
    else
        let lines = split(selection, "\n")
        let label = printf("%s...", lines[0])
    endif

    call intero#type_at(start_line, start_col, end_line, end_col, label)
endfunction " }}}
function! intero#send_service_line(line) " {{{
    if !exists('g:intero_service_port')
        call intero#error('Please start Intero first')
        return
    endif

    if !exists('g:intero_service_channel') || exists('g:intero_service_channel') && ch_status(g:intero_service_channel) != 'open'
        let addr = printf('localhost:%s', g:intero_service_port)
        let options = {'mode': 'nl'}
        let g:intero_service_channel = ch_open(addr, options)
    endif

    let message = printf("%s\r\n", a:line)
    echomsg 'Sent command: ' . message
    call ch_sendraw(g:intero_service_channel, message)
endfunction " }}}
function! intero#loc_at(start_line, start_col, end_line, end_col, label) " {{{
    let module = expand("%:t:r")
    let command = printf("loc-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    let read = ch_read(g:intero_service_channel)
    echomsg 'Read response: ' . read
    return read
endfunction " }}}
function! intero#loc_at_cursor() " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    return intero#loc_at(lnum, col, lnum, col, label)
endfunction " }}}
function! intero#loc_of_selection() range " {{{
    let [_, start_line, start_col, _] = getpos("'<")
    let [_, end_line, end_col, _] = getpos("'>")
    let selection = intero#get_selection()

    if a:firstline == a:lastline
        let label = selection
    else
        let lines = split(selection, "\n")
        let label = printf("%s...", lines[0])
    endif

    return intero#loc_at(start_line, start_col, end_line, end_col, label)
endfunction " }}}
function! intero#uses(start_line, start_col, end_line, end_col, label) " {{{
    let module = expand("%:t:r")
    let command = printf(":uses %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    return ch_read(g:intero_service_channel)
endfunction " }}}
function! intero#uses_at_cursor() " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    return intero#uses(lnum, col, lnum, col, label)
endfunction " }}}
function! intero#uses_of_selection() range " {{{
    let [_, start_line, start_col, _] = getpos("'<")
    let [_, end_line, end_col, _] = getpos("'>")
    let selection = intero#get_selection()

    if a:firstline == a:lastline
        let label = selection
    else
        let lines = split(selection, "\n")
        let label = printf("%s...", lines[0])
    endif

    return intero#uses(start_line, start_col, end_line, end_col, label)
endfunction " }}}
function! intero#all_types() " {{{
    call intero#send_service_line("all-types")
    return ch_read(g:intero_service_channel)
endfunction " }}}
function! intero#complete_at(start_line, start_col, end_line, end_col) " {{{
    let module = expand("%:t:r")
    let label = expand("<cword>")
    let command = printf(":complete-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, label)
    call intero#send_line(command)
    return ch_read(g:intero_service_channel)
endfunction " }}}
function! intero#complete_at_cursor() " {{{
    let module = expand("%:t:r")
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    return intero#complete_at(lnum, col, lnum, col, label)
endfunction " }}}
function! intero#complete_selection() range " {{{
    let [_, start_line, start_col, _] = getpos("'<")
    let [_, end_line, end_col, _] = getpos("'>")
    let selection = intero#get_selection()

    if a:firstline == a:lastline
        let label = selection
    else
        let lines = split(selection, "\n")
        let label = printf("%s...", lines[0])
    endif

    return intero#complete_at(start_line, start_col, end_line, end_col, label)
endfunction " }}}

" vim:foldmethod=marker
