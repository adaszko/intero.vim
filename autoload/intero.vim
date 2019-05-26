function! intero#warning(msg) " {{{
    echohl WarningMsg
    echo 'intero.vim:' a:msg
    echohl None
endfunction " }}}
function! intero#error(msg) " {{{
    echohl ErrorMsg
    echo 'intero.vim:' a:msg
    echohl None
endfunction " }}}
function! intero#show_intero_not_running_error() " {{{
    call intero#error('Please start Intero first')
endfunction " }}}
function! intero#safe_system(command) " {{{
    let result = system(a:command)
    if v:shell_error != 0
        throw printf('intero#safe_system: Nonzero exit code: %d', v:shell_error)
    endif
    return result
endfunction " }}}
function! intero#safe_systemlist(command) " {{{
    let result = systemlist(a:command)
    if v:shell_error != 0
        throw printf('intero#safe_systemlist: Nonzero exit code: %d', v:shell_error)
    endif
    return result
endfunction " }}}

function! intero#callback(channel, message) " {{{
    if exists('t:intero_service_port') && t:intero_service_port
        return
    endif

    let lines = split(a:message, "\r")

    if exists('t:intero_previous_truncated_line')
        let lines[0] = t:intero_previous_truncated_line . lines[0]
    endif

    let last = lines[-1]
    if last[strlen(last)-1] != ""
        let t:intero_previous_truncated_line = lines[-1]
        call remove(lines, -1)
    endif

    for line in lines
        let port = matchstr(line, '\vIntero-Service-Port: \zs\d+\ze')
        if len(port) > 0
            let t:intero_service_port = port
            return
        endif
    endfor
endfunction " }}}
function! intero#close_callback(channel) " {{{
    call intero#close()
endfunction " }}}
function! intero#exit_callback(job, exit_status) " {{{
    call intero#close()
endfunction " }}}
function! intero#ghci_open(command) " {{{
    let options = {
        \ 'term_finish': 'close',
        \ 'stoponexit':  'quit',
        \ 'term_kill':   'quit',
        \ 'vertical':    1,
        \ 'norestore':   1,
        \ 'callback':    function('intero#callback'),
        \ 'exit_cb':     function('intero#exit_callback'),
        \ 'close_cb':    function('intero#close_callback'),
        \ }

    return term_start(a:command, options)
endfunction " }}}
function! intero#open(command) " {{{
    if intero#is_open()
        call intero#warning("GHCi is already running")
        return
    endif

    let t:intero_ghci_buffer = intero#ghci_open(a:command)
    call setbufvar(t:intero_ghci_buffer, '&bufhidden', 'hide')
    call setbufvar(t:intero_ghci_buffer, "&filetype", "intero")
    wincmd p
endfunction " }}}
function! intero#close() " {{{
    if !exists('t:intero_ghci_buffer')
        let t:intero_ghci_buffer = 0
    endif
    if t:intero_ghci_buffer == 0 || !bufloaded(t:intero_ghci_buffer)
        return
    endif

    if exists('t:intero_service_port')
        unlet t:intero_service_port
    endif

    if exists('t:intero_service_channel')
        unlet t:intero_service_channel
    endif

    execute printf('silent bdelete! %d', t:intero_ghci_buffer)
    unlet t:intero_ghci_buffer
endfunction " }}}
function! intero#is_open() " {{{
    return exists('t:intero_ghci_buffer') && t:intero_ghci_buffer != 0 && bufloaded(t:intero_ghci_buffer)
endfunction " }}}
function! intero#toggle() " {{{
    if intero#is_open() && bufwinnr(t:intero_ghci_buffer) == -1
        execute 'vertical' 'sbuffer' t:intero_ghci_buffer
    elseif intero#is_open()
        call intero#close()
    else
        call intero#open('stack ghci --with-ghc intero')
    endif
endfunction " }}}

function! intero#toggle_test() " {{{
    if intero#is_open()
        call intero#close()
    else
        call intero#open('stack ghci --with-ghc intero --test --no-load')
    endif
endfunction " }}}

function! intero#find_regex(regex) " {{{
    let [buffer, line, column, offset] = getpos('.')
    call setpos('.', [buffer, 1, 1, 0])
    let [module_line_number, _] = searchpos(a:regex)
    let module_line = getline(module_line_number)
    let match = matchstr(module_line, a:regex)
    call setpos('.', [buffer, line, column, offset])
    return match
endfunction " }}}
function! intero#get_module_name() " {{{
    let module_name = intero#find_regex('\v^\s*module\s+\zs\S+\ze\s+where')
    if module_name != ''
        return module_name
    endif

    let module = expand("%:t:r")
    if module == 'Spec'
        return 'Main'
    endif
    return module
endfunction " }}}

function! intero#send_keys(keys) " {{{
    if !exists('t:intero_ghci_buffer')
        let t:intero_ghci_buffer = 0
    endif
    if t:intero_ghci_buffer == 0 || !bufloaded(t:intero_ghci_buffer)
        throw 'intero#intero-not-running'
    endif
    call term_sendkeys(t:intero_ghci_buffer, a:keys)
endfunction " }}}
function! intero#do_send_line(string) " {{{
    let line = printf("%s\<c-m>", a:string)
    return intero#send_keys(line)
endfunction " }}}
function! intero#send_line(string) " {{{
    try
        return intero#do_send_line(a:string)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
    endtry
endfunction " }}}
function! intero#send_selection() range " {{{
    let selection = intero#get_selection()
    let lines = split(selection, "\n")
    try
        if len(lines) == 0
            return
        elseif len(lines) == 1
            call intero#do_send_line(lines[0])
        else
            call intero#do_send_line(":{")
            for line in lines
                call intero#do_send_line(line)
            endfor
            call intero#do_send_line(":}")
        endif
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
    endtry
endfunction " }}}
function! intero#send_current_line() " {{{
    let line = getline(".")
    let without_initial_whitespace = substitute(line, '\v^\s+', '', '')
    try
        return intero#do_send_line(without_initial_whitespace)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
    endtry
endfunction " }}}
function! intero#type_at(start_line, start_col, end_line, end_col, label) " {{{
    let module = intero#get_module_name()
    let command = printf(":type-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#do_send_line(command)
endfunction " }}}
function! intero#type_at_cursor() " {{{
    let [_, line, col, _] = getpos(".")
    let label = expand("<cword>")
    try
        call intero#type_at(line, col, line, col, label)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
        return
    endtry
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

    try
        call intero#type_at(start_line, start_col, end_line, end_col, label)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
        return
    endtry
endfunction " }}}
function! intero#send_service_line(line) " {{{
    if !exists('t:intero_service_port')
        throw 'intero#intero-not-running'
    endif

    if !exists('t:intero_service_channel') || exists('t:intero_service_channel') && ch_status(t:intero_service_channel) != 'open'
        let addr = printf('localhost:%s', t:intero_service_port)
        let options = {'mode': 'nl'}
        let t:intero_service_channel = ch_open(addr, options)
    endif

    let message = printf("%s\r\n", a:line)
    call ch_sendraw(t:intero_service_channel, message)
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
    let module = intero#get_module_name()
    let command = printf("loc-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    let resp = ch_read(t:intero_service_channel)
    return intero#parse_loc_at_resp(resp)
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

function! intero#jump_to(pos) " {{{
    " Save current cursor position in the jumplist so that <C-O> works
    normal m'

    let buffer = bufnr(a:pos['file'])
    if buffer < 0
        execute printf("edit %s", a:pos['file'])
        let buffer = bufnr(a:pos['file'])
    endif
    execute printf("buffer %s", buffer)
    call setpos(".", [buffer, a:pos['start_line'], a:pos['start_col'], 0])
endfunction " }}}
function! intero#get_ghc_version() " {{{
    let output = intero#safe_system('stack ghc -- --version')
    let ghc_version = matchstr(output, '\vversion \zs[0-9.]+\ze')
    return ghc_version
endfunction " }}}
function! intero#get_arch() " {{{
    let lines = intero#safe_systemlist('stack --version')
    let arch = matchstr(lines[0], '\v^[0-9.]+ \zs\S+\ze')
    return arch
endfunction " }}}
function! intero#go_to_definition(...) " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    try
        let pos = intero#loc_at(lnum, col, lnum, col, label)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
        return
    endtry

    if has_key(pos, 'file') && has_key(pos, 'start_line') && has_key(pos, 'start_col')
        call intero#jump_to(pos)

        for normal_command in a:000
            execute printf('normal %s', normal_command)
        endfor
        return
    endif

    try
        let loc_at_raw = intero#parse_loc_at_raw(pos['raw'])
    catch /^intero#parse_loc_at_raw: Unable to parse/
        call intero#warning(pos['raw'])
        return
    endtry

    " Fallback to haddock source view

    " file:///Users/adaszko/repos/funnel/.stack-work/install/x86_64-osx/lts-11.8/8.2.2/doc/reddit-0.2.3.0/src/Reddit.Types.Post.html#PostID
    let resolver = intero#get_stack_resolver()
    let ghc_version = intero#get_ghc_version()
    let arch = intero#get_arch()
    let local_path = printf('%s/.stack-work/install/%s-osx/%s/%s/doc/%s-%s/src/%s.html',
        \ getcwd(),
        \ arch,
        \ resolver,
        \ ghc_version,
        \ loc_at_raw['name'],
        \ loc_at_raw['version'],
        \ loc_at_raw['file_name'])

    if filereadable(local_path)
        let local_url = printf("file://%s#%s", local_path, label)
        call intero#open_url(local_url)
        return
    endif

    " e.g. https://www.stackage.org/haddock/lts-11.22/base-4.10.1.0/src/GHC-Base.html#Maybe
    let online_url = printf("https://www.stackage.org/haddock/%s/%s-%s/src/%s.html#%s",
        \ resolver,
        \ loc_at_raw['name'],
        \ loc_at_raw['version'],
        \ loc_at_raw['file_name'],
        \ label)

    call intero#open_url(online_url)
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
            throw printf('intero#parse-error: %s', line)
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
    let module = intero#get_module_name()
    let command = printf("uses %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    return intero#slurp_resp(t:intero_service_channel)
endfunction " }}}
function! intero#uses_at_cursor() " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let resp = intero#uses(lnum, col, lnum, col, label)
    try
        let refs = intero#parse_uses(resp, label)
        call setloclist(0, refs)
    catch /^intero#parse-error:/
        echo resp[0]
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
        call setloclist(0, refs)
    catch /^intero#parse-error:/
        echo resp[0]
    endtry
endfunction " }}}

function! intero#complete_at(start_line, start_col, end_line, end_col, prefix) " {{{
    let module = intero#get_module_name()
    let command = printf("complete-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:prefix)
    call intero#send_service_line(command)
    return intero#slurp_resp(t:intero_service_channel)
endfunction " }}}
function! intero#omnicomplete_find_start() " {{{
    let line_under_cursor = getline('.')

    if match(strpart(line_under_cursor, col('.') - 2), '\v^\k+') < 0
        return col('.') - 1
    endif

    let prefix_start_column = col('.') - 2
    while prefix_start_column > 0 && match(strpart(line_under_cursor, prefix_start_column - 1), '\v^\k+') == 0
        let prefix_start_column -= 1
    endwhile
    return prefix_start_column
endfunction " }}}
function! intero#omnicomplete_get_completions(base) " {{{
    let module = intero#get_module_name()
    let [_, lnum, col, _] = getpos(".")
    let completions = intero#complete_at(lnum, col, lnum, col, a:base)
    return completions
endfunction " }}}
function! intero#omnicomplete(findstart, base) " {{{
    if a:findstart == 1
        return intero#omnicomplete_find_start()
    else
        return intero#omnicomplete_get_completions(a:base)
    endif
endfunction " }}}

function! intero#get_user_completions(base) " {{{
    let extensions = intero#safe_systemlist("stack ghc -- --supported-extensions")
    let matching = filter(extensions, printf('v:val =~ "^%s"', escape(a:base, '"')))
    return matching
endfunction " }}}
function! intero#completefunc(findstart, base) " {{{
    if a:findstart == 1
        return intero#omnicomplete_find_start()
    else
        return intero#get_user_completions(a:base)
    endif
endfunction " }}}

function! intero#all_types() " {{{
    call intero#send_service_line("all-types")
    return ch_read(t:intero_service_channel)
endfunction " }}}

function! intero#jump_to_error_at_cursor() " {{{
    let [_, line_number, _, _] = getpos(".")
    while line_number > 0
        let current_line = getline(line_number)
        if len(current_line) == 0
            break
        endif

        let groups = matchlist(current_line, '\v([^:]+):(\d+):(\d+): ')
        if len(groups) == 0
            let line_number -= 1
            continue
        endif

        let [_, filename, line, column, _, _, _, _, _, _] = groups
        let buffer = bufnr(filename)
        let pos = [buffer, str2nr(line), str2nr(column), 0]
        let window = bufwinnr(buffer)
        execute window . 'wincmd w'
        call setpos(".", pos)
        return
    endwhile
    call intero#warning('No location found at cursor')
endfunction " }}}

function! intero#open_url(url) " {{{
    if has('mac')
        " This is the only way to make URL #anchors work
        let browser_path = expand('~/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome')
        if !filereadable(browser_path)
            throw 'intero#open_url: Chrome browser not found'
        endif
    else
        call s:warning('Unknown OS')
        return
    endif

    let command = printf('%s %s', shellescape(browser_path), shellescape(a:url))
    let output = system(command)
    if v:shell_error != 0
        call intero#error(printf("Got exit code while trying to open URL: %d\n%s", v:shell_error, output))
        return
    endif
endfunction " }}}
function! intero#parse_loc_at_raw(loc_at_raw) " {{{
    " api-builder-0.15.0.0-B46fXHQp6RBAaFzgx6paUc:Network.API.Builder.Error
    " base:GHC.Base
    let loc_at_components = matchlist(a:loc_at_raw, '^\v([^:]+):(.*)$')
    if len(loc_at_components) == 0
        throw printf('intero#parse_loc_at_raw: Unable to parse: %s', a:loc_at_raw)
    endif
    let [_, package_spec, module, _, _, _, _, _, _, _] = loc_at_components

    let package_spec_components = matchlist(package_spec, '\v^(.+)-([0-9.]+)-([a-zA-Z0-9]+)$')
    if len(package_spec_components) > 0
        " api-builder-0.15.0.0-B46fXHQp6RBAaFzgx6paUc
        let [_, package_name, package_version, _, _, _, _, _, _, _] = package_spec_components
        let file_name = module
        let result = {
            \ 'name': package_name,
            \ 'version': package_version,
            \ 'file_name': file_name,
            \ }
        return result
    endif

    " base
    let package_name = package_spec
    let matching_packages = intero#safe_systemlist(printf("stack ls dependencies --include-base --external | grep '^%s\ [0-9.]*$'", package_name))
    if len(matching_packages) == 0
        call intero#error(printf("Dependency not found: %s", package_name))
        return
    endif
    if len(matching_packages) > 1
        call intero#error(printf("Ambiguous dependency reference: %s", package_name))
        return
    endif
    let package_version = matchstr(matching_packages[0], printf('^%s \zs[0-9.]*\ze$', package_name))
    let file_name = substitute(module, '\.', '-', 'g')
    let result = {
        \ 'name': package_name,
        \ 'version': package_version,
        \ 'file_name': file_name,
        \}
    return result
endfunction " }}}
function! intero#get_stack_resolver() " {{{
    " Use readfile() here instead of grep
    let matching_lines = intero#safe_systemlist("egrep '^[ \t]*resolver\s*:\s*' stack.yaml")
    if len(matching_lines) == 0
        throw 'intero#get_stack_resolver: No resolved found'
    endif
    if len(matching_lines) > 1
        throw 'intero#get_stack_resolver: Ambiguous resolver specification'
    endif
    let resolver = matchstr(matching_lines[0], '\v^\s*resolver\s*:\s*\zs.*\ze$')
    return resolver
endfunction " }}}

" vim:foldmethod=marker
