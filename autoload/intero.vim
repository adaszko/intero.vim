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
    let g:haskell_ghci_buffer = term_start('stack exec intero', options)
    execute "normal \<c-w>p"
endfunction " }}}
function! s:ghci_close() " {{{
    if !exists('g:haskell_ghci_buffer')
        let g:haskell_ghci_buffer = 0
    endif
    if g:haskell_ghci_buffer == 0 || !bufloaded(g:haskell_ghci_buffer)
        return
    endif
    execute printf('silent bdelete! %d', g:haskell_ghci_buffer)
    let g:haskell_ghci_buffer = 0
endfunction " }}}
function! s:haskell_ghci_is_open() " {{{
    return exists('g:haskell_ghci_buffer') && g:haskell_ghci_buffer != 0 && bufloaded(g:haskell_ghci_buffer)
endfunction " }}}
function! intero#ghci_toggle() " {{{
    if s:haskell_ghci_is_open()
        call s:ghci_close()
    else
        call s:ghci_open()
    endif
endfunction " }}}
function! intero#send_line(string) " {{{
    if !exists('g:haskell_ghci_buffer')
        let g:haskell_ghci_buffer = 0
    endif
    if g:haskell_ghci_buffer == 0 || !bufloaded(g:haskell_ghci_buffer)
        call s:error('Please start GHCi first')
        return
    endif
    let line = printf("%s\<c-m>", a:string)
    call term_sendkeys(g:haskell_ghci_buffer, line)
endfunction " }}}


" vim:foldmethod=marker
