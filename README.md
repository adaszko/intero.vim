A simple [Intero](https://github.com/chrisdone/intero) integration for Vim.

# Usage

Add to your `.vimrc`:

```VimL
augroup my_haskell
    autocmd!

    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>I <Plug>intero_toggle
    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>B <Plug>intero_toggle_stack_build

    autocmd FileType haskell noremap <silent> <buffer> gd :call intero#go_to_definition()<CR>
    autocmd FileType haskell setlocal omnifunc=intero#omnicomplete

    autocmd FileType haskell xnoremap <silent> <buffer> <LocalLeader>t :call intero#type_of_selection()<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>t :call intero#type_at_cursor()<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>i :call intero#send_line(printf(":info %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>k :call intero#send_line(printf(":kind %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>r :call intero#send_line(":reload")<CR>

    " Populates the quickfix list.  Use :copen to see the results
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>R :call intero#uses_at_cursor()<CR>

    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>l :call intero#send_line(printf(":load %s", expand("%")))<CR>
augroup END
```
