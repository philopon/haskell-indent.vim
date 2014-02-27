if exists('b:did_indent')
  finish
endif

setlocal autoindent
setlocal indentexpr=haskellindent#indentexpr(v:lnum) 
setlocal indentkeys=!^F,o,O,<space>,0=where
setlocal shiftwidth=4
setlocal softtabstop=4


let g:haskell_indent_where_width = max([1, &shiftwidth / 2])

let b:undo_indent = 'setlocal '.join([
      \ 'autoindent<',
      \ 'indentexpr<',
      \ 'indentkeys<',
      \ 'shiftwidth<',
      \ 'softtabstop<',
      \ ])

let b:did_indent = 1
