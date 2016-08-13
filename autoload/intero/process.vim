"""""""""""
" Process:
"
" This file contains functions for working with the Intero process. This
" includes ensuring that Intero is installed, starting/killing the
" process, and hiding/showing the REPL.
"""""""""""

function! intero#process#ensure_installed()
    " This function ensures that intero is installed. If `stack` exits with a
    " non-0 exit code, that means it failed to find the executable.
    "
    " TODO: Verify that we have a version of intero that the plugin can work
    " with.
    if (!executable('stack'))
        echom "Stack is required for Intero."
    endif

    let l:version = system('stack exec --verbosity silent -- intero --version')
    if v:shell_error
        echom "Intero not installed."
        execute "! stack build intero"
    endif
endfunction

function! intero#process#start()
    " Starts an intero terminal buffer, initially only occupying a small area.
    " Returns the intero buffer id.
    if !exists('g:intero_buffer_id')
        let g:intero_buffer_id = s:start_buffer(10)
    endif
    call intero#repl#send(':set prompt "Intero> "')
    call intero#repl#send(":set -fbyte-code")
    call intero#repl#send("import qualified System.IO as ISIO")
    call intero#repl#send("ISIO.hSetBuffering ISIO.stdout ISIO.LineBuffering")
    call intero#repl#send('"SETUPCOMPLETE"')
    augroup close_intero
        autocmd!
        autocmd VimLeave * call intero#repl#send(":quit")
        autocmd VimLeavePre * InteroKill
        autocmd VimLeave * InteroKill
        autocmd VimLeavePre * call jobstop(g:intero_job_id)
        autocmd VimLeave * call jobstop(g:intero_job_id)
    augroup END
    return g:intero_buffer_id
endfunction

function! intero#process#kill()
    " Kills the intero buffer, if it exists.
    if exists('g:intero_buffer_id')
        exe 'bd! ' . g:intero_buffer_id
        unlet g:intero_buffer_id
    else
        echo "No Intero process loaded."
    endif
endfunction

function! intero#process#hide()
    " Hides the current buffer without killing the process.
    silent! call s:hide_buffer()
endfunction

function! intero#process#open()
    " Opens the Intero REPL. If the REPL isn't currently running, then this
    " creates it. If the REPL is already running, this is a noop. Returns the
    " window ID.
    let l:intero_win = intero#util#get_intero_window()
    if l:intero_win != -1
        return l:intero_win
    elseif exists('g:intero_buffer_id')
        let l:current_window = winnr()
        silent! call s:open_window(10)
        exe 'silent! buffer ' . g:intero_buffer_id
        normal! G
        exe 'silent! ' . l:current_window . 'wincmd w'
    else
        call intero#process#start()
        return intero#process#open()
    endif
endfunction

""""""""""
" Private:
""""""""""

function! s:term_buffer(job_id, data, event)
    " let g:intero_last_response = intero#repl#get_last_response()
endfunction

function! s:on_response()
    let l:mode = mode()

    if ! (exists('g:intero_should_echo') && g:intero_should_echo)
        return
    endif

    if l:mode =~ "c" || l:mode =~ "t"
        return
    endif

    let l:current_response = intero#repl#get_last_response()

    if !exists('s:previous_response')
        let s:previous_response = l:current_response
    endif
    
    if l:current_response != s:previous_response
        let s:previous_response = l:current_response
        for r in s:previous_response
            echom r
        endfor
        echo join(s:previous_response, "\n")
        let g:intero_should_echo = 0
    endif
endfunction

function! s:start_buffer(height)
    " Starts an Intero REPL in a split below the current buffer. Returns the
    " ID of the buffer.
    " exe 'below ' . a:height . ' split'
    below new
""    terminal! stack ghci --with-ghc intero
    let g:intero_job_id = termopen(['stack', 'ghci', '--with-ghc', 'intero'], s:callbacks)
    set bufhidden=hide
    set noswapfile
    set hidden
    let l:buffer_id = bufnr('%')
    let g:intero_job_id = b:terminal_job_id
    quit
    call feedkeys("\<ESC>")
    " call timer_start(100, 's:on_response', {'repeat':-1})
    return l:buffer_id
endfunction

function s:handle_exit(job_id, lines, event)
    echom join(a:lines, "\r")
endfunction

function s:handle_stderr(job_id, lines, event)
    echom join(a:lines, "\r")
endfunction

function s:handle_stdout(job_id, lines, event)
    " Ok so basically, we want to have a few different states:
    " 1. we are loading -- display lines! sure why not
    " 2. we are not loading -- don't display the prompt
    echom join(a:lines, "\r")
endfunction

let s:callbacks = {
    \ 'on_stdout': function('s:handle_stdout'),
    \ 'on_stderr': function('s:handle_stderr'),
    \ 'on_exit': function('s:handle_exit'),
    \ }

function! s:open_window(height)
    " Opens a window of a:height and moves it to the very bottom.
    exe 'below ' . a:height . ' split'
    normal! <C-w>J
endfunction

function! s:hide_buffer()
    " This closes the Intero REPL buffer without killing the process.
    let l:window_number = intero#util#get_intero_window()
    if l:window_number > 0
        exec 'silent! ' . l:window_number . 'wincmd c'
    endif
endfunction
