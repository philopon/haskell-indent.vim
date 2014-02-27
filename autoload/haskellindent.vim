if exists('g:loaded_haskellindent')
  finish
endif
let g:loaded_haskellindent = 1

let s:save_cpo = &cpo
set cpo&vim

" content_filetype configuration {{{
let s:content_filetype_haskell =
      \     {
      \       'start': '\[\([a-z_][a-zA-Z0-9_#]*\)|',
      \       'end':   '|\]', 'filetype': '\1',
      \     }

let s:has_context_filetype = 0
silent! let s:has_context_filetype = context_filetype#version()

if s:has_context_filetype
  if exists('g:context_filetype#filetypes.haskell')
    let g:context_filetype#filetypes.haskell =
          \ add(g:context_filetype#filetypes.haskell, s:content_filetype_haskell)
  else 
    let g:context_filetype#filetypes.haskell = [s:content_filetype_haskell]
  endif
endif
"}}}

" Haskell language definition. {{{
let s:find_col_limit = 10

let s:force_toplevels = '^\s*\(\<' . join(['import', 'foreign', 'infix', 'infixl', 'infixr', 'instance', 'deriving instance', 'class', 'module'], '\>\|\<') . '\>\)'

let s:vregex = '[a-z_][a-zA-Z0-9_#]*'
let s:tregex = '[A-Z][a-zA-Z0-9_#]*'
let s:symbol = '!#$%&*+./<=>?@\\^|\-~'
let s:infix  = '\(`[a-zA-Z_][a-zA-Z0-9_#]*`\|[' . s:symbol . ']\+\)'
"}}}

function! s:drop_comment(string) abort "{{{
  return substitute(substitute(a:string, '\s*--.\{-}$', "", 'g'), '\s*{-.\{-}-}\s*', " ", 'g')
endfunction "}}}

function! s:prevnonblank_ (lnum) abort "{{{
  let l:lnum = a:lnum
  while l:lnum > 0
    if s:drop_comment(getline(l:lnum)) !~# '^\s*$'
      return l:lnum
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction "}}}

function! s:debug_print(msg) abort "{{{
  " echo a:msg
endfunction "}}}

function! s:increase_indent(plnum, pline) abort "{{{
  if a:pline =~# '<-\s*\<'
    return match(a:pline, '\<', match(a:pline, '<-') + 2)
  endif

  if a:pline =~# '^\s*\<let\>\s*\<'
    return match(a:pline, '\<', match(a:pline, '\<let\>') + 3) + &shiftwidth
  endif

  return indent(a:plnum) + &shiftwidth
endfunction "}}}

function! s:find_col_previous(regex, lnum, lim) abort "{{{
  let l:lnum = 0
  while l:lnum < a:lim
    let l:line = getline(a:lnum - l:lnum)
    let l:match = match(l:line, a:regex)
    if l:match >= 0
      return l:match
    elseif l:line =~# '^\S'
      return 0
    endif
    let l:lnum += 1
  endwhile
  return -1
endfunction "}}}

function! s:in_do_condition(lnum) abort "{{{
  let l:lnum = a:lnum
  while l:lnum > 0
    let l:line = getline(l:lnum)
    if l:line =~# '\<do\>'
      return 1
    elseif l:line =~# '^\S'
      return 0
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction "}}}

function! haskellindent#indentexpr(lnum) abort "{{{
  let l:cline = getline(a:lnum)
  let l:plnum = s:prevnonblank_(a:lnum - 1)
  let l:pline = getline(l:plnum)

  if 0

  elseif s:has_context_filetype && context_filetype#get().filetype != 'haskell'
    call s:debug_print('In QuasiQuotes.')
    return -1

  elseif l:cline =~# '^\s*->' && l:pline =~# '\(^\s*->\|::\)'
    call s:debug_print('C: type arrow')
    return match(l:pline, '\(->\|::\)')

  elseif l:cline =~# s:force_toplevels
    call s:debug_print('C: reserved top level symbol.')
    return 0

  elseif l:cline =~# '^\s*|'
    call s:debug('C: pipe align.')
    let l:col = s:find_col_previous('\(|\|=\)', a:lnum - 1, s:find_col_limit)
    return l:col ? l:col : &shiftwidth

  elseif l:cline =~# '^\s*' . s:infix && l:pline !~# '^\s*' . s:infix
    call s:debug_print('C: start with infix function.')
    return s:increase_indent(l:plnum, l:pline)

  elseif l:cline =~# '^\s*\<then\>'
    call s:debug_print('C: then')
    let l:indo = s:in_do_condition(a:lnum - 1) ? &shiftwidth : 0
    return s:find_col_previous('\<if\>', a:lnum - 1, s:find_col_limit) + l:indo

  elseif l:cline =~# '^\s*\<else\>'
    call s:debug_print('C: else.')
    return s:find_col_previous('\<then\>', a:lnum - 1, s:find_col_limit)

  elseif l:cline =~# '^\s*,'
    call s:debug_print('C: align comma.')
    return s:find_col_previous('[\[,{]', a:lnum - 1, s:find_col_limit)

  elseif l:cline =~# '^\s*where'
    call s:debug_print('C: where')
    let l:pind = indent(l:plnum)
    return indent(l:plnum) - g:haskell_indent_where_width

  elseif l:pline =~# '\<case\>'
    call s:debug_print('N: case.')
    return indent(l:plnum) + &shiftwidth

  elseif l:pline =~# '^\s*where\s*$'
    call s:debug_print('N: where')
    return indent(l:plnum) + g:haskell_indent_where_width

  elseif l:pline =~# s:force_toplevels || l:pline =~# '^\s*\<\(data\|type\|newtype\)\>'
    call s:debug_print('N: reserved top level synbol.')
    return &shiftwidth

  elseif l:pline =~# '\<do\>\s*\<'
    call s:debug_print('N: align do.')
    return match(l:pline, '\<', match(l:pline, '\<do\>') + 2)

  elseif l:pline =~# '\<do\>\s*$'
    call s:debug_print('N: dropped do.')
    return s:increase_indent(l:plnum, l:pline)

  elseif l:pline =~# '[^' . s:symbol . ']=\s*$'
    call s:debug_print('N: dropped =.')
    return s:increase_indent(l:plnum, l:pline)

  elseif l:pline =~# s:infix . '\s*$' && getline(s:prevnonblank_(l:plnum - 1)) !~# s:infix . '\s*$'
    call s:debug_print('N: dropped infix function')
    return s:increase_indent(l:plnum, l:pline)

  endif
  return -1
endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
