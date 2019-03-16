As simple as it gets [Intero](https://github.com/chrisdone/intero) integration for Vim.

# Usage

Add to your `.vimrc`:

```
augroup my_haskell
    autocmd!

    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>B <Plug>intero_toggle_stack_build
    autocmd FileType haskell nmap <silent> <buffer> <LocalLeader>I <Plug>intero_toggle_ghci

    autocmd FileType haskell xnoremap <silent> <buffer> <LocalLeader>t "*y:call intero#send_line(printf(":type %s", @*))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>t :call intero#send_line(printf(":type %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>i :call intero#send_line(printf(":info %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>k :call intero#send_line(printf(":kind %s", expand("<cword>")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>r :call intero#send_line(":reload")<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>l :call intero#send_line(printf(":load %s", expand("%")))<CR>
    autocmd FileType haskell nnoremap <silent> <buffer> <LocalLeader>q :call intero#send_line(":quit")<CR>
augroup END
```
