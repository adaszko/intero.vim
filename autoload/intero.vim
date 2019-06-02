function! intero#info(...) " {{{
    echomsg call(function('printf'), a:000)
endfunction " }}}
function! intero#error(...) " {{{
    echohl ErrorMsg
    echomsg call(function('printf'), a:000)
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

function! intero#strip_terminal_control_codes(line) " {{{
    let line = substitute(a:line, "\x00", '', 'g')
    " let line = substitute(line, "\x1b\[[0-9;]*m", '', 'g')
    let line = substitute(line, "\x1b\[[0-9;]*[a-zA-Z]", '', 'g')
    let line = substitute(line, "\x1b\[?1h", '', 'g')
    let line = substitute(line, "\x1b\[?1l", '', 'g')
    let line = substitute(line, "\x1b=", '', 'g')
    let line = substitute(line, "\x1b>", '', 'g')
    let line = substitute(line, "\n", '', 'g')
    return line
endfunction " }}}
function! intero#callback(channel, message) " {{{
    let raw_lines = split(a:message, "\r")

    if exists('g:intero_previous_truncated_line')
        let raw_lines[0] = g:intero_previous_truncated_line . raw_lines[0]
    endif

    let last = raw_lines[-1]
    if last[strlen(last)-1] != ""
        let g:intero_previous_truncated_line = raw_lines[-1]
        call remove(raw_lines, -1)
    endif

    for raw_line in raw_lines
        let line = intero#strip_terminal_control_codes(raw_line)

        let port = matchstr(line, '\vIntero-Service-Port: \zs\d+\ze')
        if port != ''
            let g:intero_service_port = port
        endif

        let ok_modules_loaded = matchstr(line, '\vOk, modules loaded: .*')
        if ok_modules_loaded != ''
            call intero#info("%s", ok_modules_loaded)
        endif

        let failed_modules_loaded = matchstr(line, '\vFailed, modules loaded: .*')
        if failed_modules_loaded != ''
            call intero#error("%s", failed_modules_loaded)
            execute 'cc 1'
        endif

        let location = intero#parse_ghc_location(line)
        if location != {}
            call setqflist([location], 'a')
        else
            if len(getqflist()) == 0
                " Do not add garbage at the start of the quickfix list
                continue
            end
            call setqflist([{'text': line}], 'a')
        endif
    endfor
endfunction " }}}
function! intero#close_callback(channel) " {{{
    call intero#stop()
endfunction " }}}
function! intero#exit_callback(job, exit_status) " {{{
    call intero#stop()
endfunction " }}}
function! intero#ghci_open(command) " {{{
    let options = {
        \ 'term_finish': 'close',
        \ 'stoponexit':  'quit',
        \ 'term_kill':   'quit',
        \ 'vertical':    1,
        \ 'norestore':   1,
        \ 'hidden':      1,
        \ 'callback':    function('intero#callback'),
        \ 'exit_cb':     function('intero#exit_callback'),
        \ 'close_cb':    function('intero#close_callback'),
        \ }

    let buffer = term_start(a:command, options)
    if buffer == 0
        throw 'intero#ghci_open: Failed to start terminal'
    endif
    return buffer
endfunction " }}}
function! intero#start_with(command) " {{{
    if intero#is_running()
        call intero#error("GHCi is already running")
        return
    endif

    let g:intero_buffer = intero#ghci_open(a:command)
    call setbufvar(g:intero_buffer, '&bufhidden', 'hide')
    call setbufvar(g:intero_buffer, "&filetype", "intero")
    wincmd p
endfunction " }}}
function! intero#is_intero_usable() " {{{
    let stack_command = 'stack --version'
    call system(stack_command)
    if v:shell_error != 0
        call intero#error('`%s` failed with exit code %d; Please install Stack first', stack_command, v:shell_error)
        return 0
    endif

    let intero_command = 'stack exec intero -- --version'
    call system(intero_command)
    if v:shell_error != 0
        call intero#error('`%s` failed with exit code %d; Please do `stack build intero` first', intero_command, v:shell_error)
        return 0
    endif

    return 1
endfunction " }}}
function! intero#start() " {{{
    if !intero#is_intero_usable()
        return
    endif
    call intero#start_with('stack ghci --with-ghc intero')
endfunction " }}}
function! intero#ensure_started() " {{{
    if intero#is_running()
        return
    endif
    call intero#start()
endfunction " }}}
function! intero#start_test() " {{{
    if !intero#is_intero_usable()
        return
    endif
    call intero#start_with('stack ghci --with-ghc intero --test --no-load')
endfunction " }}}
function! intero#stop() " {{{
    if exists('g:intero_service_port')
        unlet g:intero_service_port
    endif

    if exists('g:intero_service_channel')
        if ch_status(g:intero_service_channel) == 'open'
            call ch_close(g:intero_service_channel)
        endif
        unlet g:intero_service_channel
    endif

    if exists('g:intero_buffer')
        if bufloaded(g:intero_buffer)
            execute printf('silent bdelete! %d', g:intero_buffer)
        endif
        unlet g:intero_buffer
    endif
endfunction " }}}
function! intero#is_running() " {{{
    return exists('g:intero_buffer') && bufloaded(g:intero_buffer)
endfunction " }}}
function! intero#is_visible() " {{{
    return intero#is_running() && bufwinnr(g:intero_buffer) != -1
endfunction " }}}
function! intero#toggle() " {{{
    if intero#is_running() && !intero#is_visible()
        execute 'vertical' 'sbuffer' g:intero_buffer
    elseif intero#is_running()
        call intero#stop()
    else
        call intero#start()
    endif
endfunction " }}}

function! intero#toggle_test() " {{{
    if intero#is_running()
        call intero#stop()
    else
        call intero#start_test()
    endif
endfunction " }}}

function! intero#find_regex(regex) " {{{
    let [buffer, line, column, offset] = getpos('.')
    try
        call setpos('.', [buffer, 1, 1, 0])
        let [module_line_number, _] = searchpos(a:regex)
        let module_line = getline(module_line_number)
        let match = matchstr(module_line, a:regex)
        return match
    finally
        call setpos('.', [buffer, line, column, offset])
    endtry
    return ''
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

function! intero#do_send_keys(keys) " {{{
    if !intero#is_running()
        throw 'intero#intero-not-running'
    endif
    call term_sendkeys(g:intero_buffer, a:keys)
endfunction " }}}
function! intero#send_keys(keys) " {{{
    try
        call intero#do_send_keys(a:keys)
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
    endtry
endfunction " }}}
function! intero#do_send_line(string) " {{{
    let line = printf("%s\<c-m>", a:string)
    return intero#do_send_keys(line)
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
function! intero#get_type_at(start_line, start_col, end_line, end_col, label) " {{{
    let module = intero#get_module_name()
    let command = printf(":type-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    let resp = intero#service_command(command)
    if resp == []
        return ''
    endif
    let first_line = intero#strip_trailing_whitespace(resp[0])
    let remaining_lines = map(resp[1:], 'intero#strip_leading_whitespace(v:val)')
    let all_lines = [first_line] + remaining_lines
    return join(all_lines)
endfunction " }}}
function! intero#strip_leading_whitespace(str) " {{{
    return substitute(a:str, '\v^\s*', '', '')
endfunction " }}}
function! intero#strip_trailing_whitespace(str) " {{{
    return substitute(a:str, '\v\s*$', '', '')
endfunction " }}}
function! intero#type_at_cursor() " {{{
    let [_, line, col, _] = getpos(".")
    let label = expand("<cword>")
    try
        if intero#is_visible()
            call intero#type_at(line, col, line, col, label)
        else
            let resp = intero#get_type_at(line, col, line, col, label)
            if resp == ''
                call intero#error("%s :: ???", label)
            else
                call intero#info("%s", resp)
            endif
        endif
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
        if intero#is_visible()
            call intero#type_at(start_line, start_col, end_line, end_col, label)
        else
            redraw
            let resp = intero#get_type_at(start_line, start_col, end_line, end_col, label)
            if resp == ''
                call intero#error("%s :: ???", label)
            else
                call intero#info("%s", resp)
            endif
        endif
    catch /^intero#intero-not-running$/
        call intero#show_intero_not_running_error()
        return
    endtry
endfunction " }}}
function! intero#send_service_line(line) " {{{
    if !exists('g:intero_service_port')
        throw 'intero#intero-not-running'
    endif

    if !exists('g:intero_service_channel') || exists('g:intero_service_channel') && ch_status(g:intero_service_channel) != 'open'
        let addr = printf('localhost:%s', g:intero_service_port)
        let options = {'mode': 'nl'}
        let g:intero_service_channel = ch_open(addr, options)
    endif

    let message = printf("%s\r\n", a:line)
    call ch_sendraw(g:intero_service_channel, message)
endfunction " }}}
function! intero#service_command(command) " {{{
    call intero#send_service_line(a:command)
    return intero#slurp_resp(g:intero_service_channel)
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
    let command = printf(":loc-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    let resp = ch_read(g:intero_service_channel, {'timeout': 1000})
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
        call intero#error(pos['raw'])
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
        let line = ch_read(a:channel, {'timeout': 1000})
        if len(line) == 0
            continue
        endif
        let lines = add(lines, line)
    endwhile
    return lines
endfunction " }}}
function! intero#uses(start_line, start_col, end_line, end_col, label) " {{{
    let module = intero#get_module_name()
    let command = printf(":uses %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:label)
    call intero#send_service_line(command)
    return intero#slurp_resp(g:intero_service_channel)
endfunction " }}}
function! intero#uses_at_cursor() " {{{
    let [_, lnum, col, _] = getpos(".")
    let label = expand("<cword>")
    let resp = intero#uses(lnum, col, lnum, col, label)
    try
        let refs = intero#parse_uses(resp, label)
        call setloclist(0, refs)
        call intero#info("Populated location list with %d items", len(refs))
    catch /^intero#parse-error:/
        call intero#error(resp[0])
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
        call intero#info("Populated location list with %d items", len(refs))
    catch /^intero#parse-error:/
        call intero#error(resp[0])
    endtry
endfunction " }}}

function! intero#complete_at(start_line, start_col, end_line, end_col, prefix) " {{{
    let module = intero#get_module_name()
    let command = printf("complete-at %s %d %d %d %d %s", module, a:start_line, a:start_col, a:end_line, a:end_col, a:prefix)
    call intero#send_service_line(command)
    return intero#slurp_resp(g:intero_service_channel)
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

function! intero#parse_ghc_location(line) " {{{
    let components = matchlist(a:line, '\v(/[^:]+):(\d+):(\d+): error:')
    if len(components) == 0
        return {}
    endif
    let [_, filename, line, column, _, _, _, _, _, _] = components
    let result = {
        \ 'filename': filename,
        \ 'lnum': str2nr(line),
        \ 'col': str2nr(column),
        \ 'type': 'E',
        \ }
    return result
endfunction " }}}

function! intero#jump_to_error_at_cursor() " {{{
    let [_, line_number, _, _] = getpos(".")
    while line_number > 0
        let current_line = getline(line_number)
        if len(current_line) == 0
            break
        endif

        let location = intero#parse_ghc_location(current_line)
        if location == {}
            let line_number -= 1
            continue
        endif

        let position = {
            \ 'file': location['filename'],
            \ 'start_line': location['lnum'],
            \ 'start_col': location['col']
            \ }
        let buffer = bufnr(filename)
        let window = bufwinnr(buffer)
        execute window . 'wincmd w'
        call intero#jump_to(position)
        return
    endwhile
    call intero#error('No location found at cursor')
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
        call intero#error("Got exit code while trying to open URL: %d\n%s", v:shell_error, output)
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
        call intero#error("Dependency not found: %s", package_name)
        return
    endif
    if len(matching_packages) > 1
        call intero#error("Ambiguous dependency reference: %s", package_name)
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

function! intero#reload() " {{{
    call setqflist([], 'r')
    call intero#send_line(":reload")
endfunction " }}}
function! intero#clear_screen_reload() " {{{
    call setqflist([], 'r')
    call intero#send_keys(':reload')
endfunction " }}}

" vim:foldmethod=marker
