if exists('g:loaded_haskellindent')
  finish
endif
let g:loaded_haskellindent = 1

let s:save_cpo = &cpo
set cpo&vim

" content_filetype configuration {{{
let s:content_filetype_haskell =
      \  [
      \    {
      \      'start': '\[\([a-z_][a-zA-Z0-9_#]*\)|',
      \      'end':   '|\]', 'filetype': '\1',
      \    }
      \  ]

let s:has_context_filetype = 0
silent! let s:has_context_filetype = context_filetype#version()

if s:has_context_filetype
  if exists('g:context_filetype#filetypes.haskell')
    let g:context_filetype#filetypes.haskell =
          \ g:context_filetype#filetypes.haskell + s:content_filetype_haskell
  else 
    let g:context_filetype#filetypes.haskell = s:content_filetype_haskell
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

function! s:find_col_previous(regex, lnum, top, lim) abort "{{{
  let l:lnum = 0
  while l:lnum < a:lim
    let l:line = getline(a:lnum - l:lnum)
    let l:match = match(l:line, a:regex)
    if l:match >= 0
      return l:match
    elseif l:line =~# '^\s\{' . a:top . '\}\S'
      return 0
    endif
    let l:lnum += 1
  endwhile
  return -1
endfunction "}}}

function! s:in_condition(cond, lnum, top) abort "{{{
  let l:lnum = a:lnum
  while l:lnum > 0
    let l:line = getline(l:lnum)
    if l:line =~# a:cond
      return l:lnum
    elseif l:line =~# '^\s\{' . a:top . '\}\S'
      return 0
    elseif l:line =~# '\<do\>'
      return 0
    endif
    let l:lnum -= 1
  endwhile
  return 0
endfunction "}}}

function s:top_level(lnum) abort "{{{
  let l:lnum = a:lnum
  let l:clevel = indent(a:lnum)
  while l:lnum > 0
    let l:line = getline(l:lnum)
    if l:line =~# '^\S'
      return [l:lnum, 0]
    elseif l:line =~# '^\s*where\s*$'
      return [l:lnum+1, match(getline(l:lnum+1), '\<')]
    elseif l:line =~# '^\s*where\>'
      return [l:lnum, match(l:line, '\<', match(l:line, 'where\>') + 6)]
    elseif l:line =~# '\<case\>.*\<of\>\s*$'
      let l:level =  match(getline(l:lnum+1), '\<')
      if l:clevel < l:level
        return  [l:lnum+1, l:level]
      endif
    endif
    let l:lnum -= 1
  endwhile
endfunction "}}}

function! haskellindent#indentexpr(lnum) abort " {{{
  let l:pline  = s:drop_comment(getline(a:lnum - 1))

  if 0
  elseif l:pline =~# 'where\s*$'
    let l:tllnum = s:top_level(a:lnum - 1)[0]
    let l:tlline = getline(l:tllnum)
    if l:tlline =~# '^module'
      call s:debug_print('next of module where')
      return 0
    elseif l:tlline =~# '^\(data\|instance\|class\)'
      call s:debug_print('next of GADT, class, instance where')
      return &shiftwidth
    else
      call s:debug_print('next of function where$')
      return indent(a:lnum - 1) + g:haskell_indent_where_width
    endif

  elseif l:pline =~# '^\s*where\s\+' . s:vregex
    call s:debug_print('next of function where hoge.')
    let l:top = match(l:pline, '\<', match(l:pline, 'where') + 6)
    return indent(a:lnum) >= l:top ? -1 : l:top

  elseif l:pline =~# '\<case\>.*\<of\>'
    call s:debug_print('next of case of.')
    return indent(a:lnum - 1) + &shiftwidth

  elseif l:pline =~# '^module'
    call s:debug_print('next of module.')
    return &shiftwidth

  elseif l:pline =~# '\<\(do\|of\)\>\s*$' || l:pline =~# '=\s*$'
    call s:debug_print('next of do/of/=.')
    let l:letcond = s:in_condition('\<let\>', a:lnum - 1, s:top_level(a:lnum)[1])
    if l:letcond
      return indent(l:letcond) + 4 + &shiftwidth
    else 
      return indent(a:lnum - 1) + &shiftwidth
    endif

  elseif l:pline =~# '\<let\>'
    call s:debug_print('next of let.')
    if !s:in_condition('\<do\>', a:lnum, 0)
      let l:letcond = match(l:pline, '\(\<\|[(\[]\)', match(l:pline, '\<let\>') + 4)
      let l:ind     = indent(a:lnum)
      return max([l:ind, l:letcond])
    endif

  endif

  """"""""""""""""""""""""""""""""""""""""""""""""

  let l:cline  = getline(a:lnum)
  if 0
  elseif l:cline =~# '^\s*where'
    call s:debug_print('where.')
    return g:haskell_indent_where_width

  elseif l:cline =~# '^\s*then\>'
    call s:debug_print('then.')
    if s:in_condition('\<do\>', a:lnum - 1, 0)
      return s:find_col_previous('\<if\>', a:lnum - 1, 0, 10) + &shiftwidth
    else
      return s:find_col_previous('\<if\>', a:lnum - 1, 0, 10)
    endif

  elseif l:cline =~# '^\s*else\>'
    call s:debug_print('else.')
    return s:find_col_previous('\<then\>', a:lnum - 1, 0, 10)

  elseif l:cline =~# '^\s*in\>'
    call s:debug_print('in.')
    return s:find_col_previous('\<let\>', a:lnum - 1, 0, 10)

  elseif l:pline =~# '::' && l:cline =~# '^\s*\(->\|=>\)'
    call s:debug_print('->, =>.')
    return match(l:pline, '::')

  elseif l:cline =~# '^\s*|'
    call s:debug_print('|')
    let [l:tllnum, l:tlcol] = s:top_level(a:lnum - 1)
    if getline(l:tllnum) =~# '^data\>'
      return s:find_col_previous('[|=]', a:lnum - 1, 0, 10)
    else
      let l:pipe = s:find_col_previous('|', a:lnum - 1, l:tlcol, 10)
      if l:pipe <= 0
        return l:tlcol + &shiftwidth
      else
        return l:pipe
      endif
    endif

  elseif l:cline =~# '^\s*,'
    call s:debug_print(',')
    let [l:ppline, l:ppcol] = searchpairpos('\[', '', '\]', 'bnW')

    if l:ppline && l:ppline != a:lnum
      return l:ppcol - 1
    else 
      let [l:ppline, l:ppcol] = searchpairpos('{', '', '}', 'bnW')
      return l:ppcol - 1
    endif

  elseif l:cline =~# '^\s*\(=\|{ \)'
    call s:debug_print('=,{')
    return indent(a:lnum - 1) + &shiftwidth

  endif

  call s:debug_print('no rule')
  return -1
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
