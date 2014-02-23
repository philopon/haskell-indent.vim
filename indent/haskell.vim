
if exists('b:did_indent')
  finish
endif

setlocal autoindent
setlocal indentexpr=haskellindent#indentexpr(v:lnum) 
setlocal indentkeys=!^F,o,O,0},0,,0\|,0=where,0=deriving,0=then,0=else,0=of,0=->,0{
setlocal shiftwidth=4 
setlocal softtabstop=4

let b:undo_indent = 'setlocal '.join([
      \ 'autoindent<',
      \ 'indentexpr<',
      \ 'indentkeys<',
      \ 'shiftwidth<',
      \ 'softtabstop<',
      \ ])

let b:did_indent = 1
