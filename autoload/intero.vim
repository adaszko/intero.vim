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
function! intero#toggle() " {{{
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
    call ch_sendraw(g:intero_service_channel, message)
endfunction " }}}
function! intero#parse_loc_at_resp(resp) " {{{
    " e.g. /Users/adaszko/repos/playground/app/Main.hs:(25,16)-(25,17)
    let elements = matchlist(a:resp, '\v([^:]*):\((\d+),(\d+)\)-\((\d+),(\d+)\)')
    if len(elements) == 0
        let result = {
            \ 'raw': a:resp,
            \ }
    else
        let [_, file, start_line, start_col, end_line, end_col, _, _, _, _] = elements
        let result = {
            \ 'raw':        a:resp,
            \ 'file':       file,
            \ 'start_line': start_line,
            \ 'start_col':  start_col,
            \ 'end_line':   end_line,
            \ 'end_col':    end_col,
            \ }
    endif
    return result
endfunction " }}}
function! intero#loc_at(start_line, start_col, end_line, end_col, label) " {{{
    let module = expand("%:t:r")
    let command = printf("loc-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    let resp = ch_read(g:intero_service_channel)
    return intero#parse_loc_at_resp(resp)
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
function! intero#go_to_definition() " {{{
    let pos = intero#loc_at_cursor()

    if has_key(pos, 'file') && has_key(pos, 'start_line') && has_key(pos, 'start_col')
        let buffer = bufnr(pos['file'])
        call setpos(".", [buffer, pos['start_line'], pos['start_col'], 0])
    else
        echo pos['raw']
    endif
endfunction " }}}

function! intero#parse_uses(lines, label) " {{{
    let result = []

    if len(a:lines) == 0
        return result
    endif

    let filename_from_module_name = {}

    for line in a:lines
        let elements = matchlist(line, '\v([^:]*):\((\d+),(\d+)\)-\((\d+),(\d+)\)')

        if len(elements) == 0
            throw printf('intero#parse_uses:parse_error: %s', line)
        endif

        let [_, filename, start_line, start_col, end_line, end_col, _, _, _, _] = elements

        if filereadable(filename)
            let module_name = fnamemodify(filename, ':t:r')
            let filename_from_module_name[module_name] = filename
            continue
        else
            let filename = filename_from_module_name[filename]
        endif

        let partial = {
            \ 'filename': filename,
            \ 'lnum':     start_line,
            \ 'col':      start_col,
            \ 'text':     a:label,
            \ }
        let result = add(result, partial)
    endfor

    return result
endfunction " }}}
function! intero#slurp_resp(channel) " {{{
    let lines = []
    while ch_status(a:channel) == 'open'
        let line = ch_read(a:channel)
        if len(line) == 0
            continue
        endif
        let lines = add(lines, line)
    endwhile
    return lines
endfunction " }}}
function! intero#uses(start_line, start_col, end_line, end_col, label) " {{{
    let module = expand("%:t:r")
    let command = printf("uses %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    return intero#slurp_resp(g:intero_service_channel)
endfunction " }}}
function! intero#uses_at_cursor() " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let resp = intero#uses(lnum, col, lnum, col, label)
    try
        let refs = intero#parse_uses(resp, label)
        call setqflist(refs)
    catch /^intero#parse_uses:parse_error/
        echo 'raised'
        echo resp
    endtry
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

    let refs = intero#uses(start_line, start_col, end_line, end_col, label)
    try
        let refs = intero#parse_uses(resp, label)
        call setqflist(refs)
    catch /^intero#parse_uses:parse_error/
        echo resp
    endtry
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

function! intero#all_types() " {{{
    call intero#send_service_line("all-types")
    return ch_read(g:intero_service_channel)
endfunction " }}}

" vim:foldmethod=marker
