A simple [Intero](https://github.com/chrisdone/intero) integration for Vim.

# Usage

1) `cd ~/.vim/pack/bundle/start/`

2) `git clone https://github.com/adaszko/intero.vim.git`

3) Add to your `.vimrc`:

```VimL
augroup my_haskell
    autocmd!

    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>I :call intero#toggle()<CR>

    " For use in Spec.hs;  Doesn't do :load automatically
    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>T :call intero#toggle_test()<CR>

    " intero#go_to_definition() accepts normal mode commands to execute after a successful jump
    autocmd FileType haskell noremap <silent> <buffer> gd :call intero#go_to_definition('zz')<CR>
    autocmd FileType haskell setlocal omnifunc=intero#omnicomplete

    autocmd FileType haskell xnoremap <silent> <buffer> <LocalLeader>t :call intero#type_of_selection()<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>t :call intero#type_at_cursor()<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>i :call intero#send_line(printf(":info %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>k :call intero#send_line(printf(":kind %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>r :call intero#send_line(":reload")<CR>
    autocmd FileType haskell xnoremap <silent> <buffer> <LocalLeader>s :call intero#send_selection()<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>s :call intero#send_current_line()<CR>

    " Populates the location list
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>R :call intero#uses_at_cursor()<CR>

    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>l :call intero#send_line(printf(":load %s", expand("%")))<CR>

    function! s:reload_if_intero_running()
        if intero#is_open()
            call intero#send_keys(':reload')
        endif
    endfunction

    " Does :reload on every write of a Haskell buffer, along with clearing the screen.
    autocmd BufWritePost *.hs :call s:reload_if_intero_running()

    autocmd FileType intero nnoremap <silent> <buffer> <CR> :call intero#jump_to_error_at_cursor()<CR>
augroup END
```

4) Build Intero within your stack project: `stack build intero`
5) Open your project file and use `\I` to start the Intero shell (adjust for
   your `<LocalLeader>` setting)


## Tips

Completion and go-to-def smarts work on the last successfully loaded version
of a Haskell module.  If you're in the middle of resolving type errors and
still want to use up-to-date version of your code, you may want to use `:set
-fdefer-type-errors` option, or even define a mapping for it:


```VimL
[...]
autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>d :call intero#send_line(":set -fdefer-type-errors")<CR>
[...]
```

# (Not exhaustive) demo

 * `:reload`, `:kind`, `:type`, go-to-definition

![](gifs/various.gif)

 * `:type-at` (get type of an expression)

![](gifs/type-at.gif)

 * `'omnifunc'` (Vim's `<C-X><C-O>` completion)

![](gifs/omnicompletion.gif)

# Changelog

Breaking changes:
 * 2019-05-26 Added fallback to open web browser in `intero#go_to_definition()`
    * Won't work with anything else than macOS and Google Chrome (porting is trivial)
 * 2019-05-26 Removed `intero#go_to_def_or_open_browser()`
 * 2019-04-13 :uses now populates location list instead of quickfix list
 * 2019-04-13 Removed `intero#stack_build_toggle()`.  `stack build --file-watch` is as usable outside of Vim.

Backward-compatible changes:
 * 2019-05-26 Populate quickfix with GHCi errors on :reload
 * 2019-04-26 Added intero#go_to_def_or_open_browser()
 * 2019-04-22 Quick jumping into error location
 * 2019-04-22 Support e.g. centering after a successful go-to-def
 * 2019-04-22 Support :reloading on a buffer write
