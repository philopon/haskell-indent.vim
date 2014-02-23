if exists('g:loaded_haskellindent')
  finish
endif
let g:loaded_haskellindent = 1

let s:save_cpo = &cpo
set cpo&vim

function! s:search_back(regex, lnum)
  let l:tmp_lnum = a:lnum
  let l:tmp_line = getline(a:lnum)

  while l:tmp_line !~# a:regex && l:tmp_lnum >= 0
    if l:tmp_line[0] != ' ' && l:tmp_line[0] != '' " top level
      return [-1, '']
    elseif l:tmp_line =~# '\<where\>'
      return [-1, '']
    endif
    let l:tmp_lnum -= 1
    let l:tmp_line = getline(l:tmp_lnum)

  endwhile

  return [l:tmp_lnum, l:tmp_line]
endfunction


function! s:debug_print(num)
  " echo 'Rule ' . a:num
endfunction

function! haskellindent#indentexpr(lnum)
  let l:before = getline(a:lnum - 1)
  let l:prev   = prevnonblank(a:lnum - 1)
  let l:line   = getline(a:lnum)
  let l:indent = indent(a:lnum - 1)

  if l:line =~# '^\s*,'
    call s:debug_print('comma')
    return match(l:prev, '{\|,\|\[')

  elseif l:line =~# '\<in\>'
    call s:debug_print('in')
    return match(s:search_back('\<let\>', a:lnum -1)[1], '\<let\>')

  elseif l:line =~# '^\s*\(|\|deriving\)'
    let peq = match(s:search_back('[|=]', a:lnum - 1)[1], '[|=]')
    call s:debug_print('pipe&deriving: ' . peq)
    if peq > 0
      return peq
    else 
      return &shiftwidth
    endif

  elseif l:line =~# '^\s*->' 
    call s:debug_print('type ->')
    return match(l:prev, '::')

  elseif l:line =~# '\<then\>'
    call s:debug_print('then')
    let [l:iflnum, l:ifline] = s:search_back('\<if\>', a:lnum - 1)
    if l:ifline =~# '->'
      return l:indent + &shiftwidth
    endif

    let l:ifpos = match(l:ifline, '\<if\>')
    if s:search_back('\<do\>', a:lnum - 1)[0] >= 0
      return l:ifpos + &shiftwidth / 2
    else 
      return l:ifpos
    endif

  elseif l:line =~# '\<else\>'
    call s:debug_print('else')
    return match(s:search_back('\<then\>', a:lnum -1)[1], '\<then\>')

  elseif l:line =~# '^\s*\<of\>'
    call s:debug_print('<CR>of')
    return match(l:prev, '\<case\>')

  elseif l:before =~# '^\<module\>'
    call s:debug_print('module')
    return &shiftwidth

  elseif l:before =~# '\<case\>.*\<of\>'
    call s:debug_print('case of')
    return l:indent + &shiftwidth

  elseif l:before =~# '\<of\>'
    call s:debug_print('next of "of"')
    return match(l:before, '\<of\>') + 3

  elseif l:before =~# '\<do\>\s*$'
    call s:debug_print('do<CR>')
    return l:indent + &shiftwidth

  elseif l:before =~# '\<do\>'
    call s:debug_print('do')
    return match(l:before, '\<do\>') + 3

  elseif l:before =~# '\s*\<where\>\s*$'
    call s:debug_print('where hoge')
    return l:indent + &shiftwidth / 2

  elseif l:before =~# '\s*\<where\>.*='
    call s:debug_print('where =')
    return l:indent + 6 + &shiftwidth / 2
    
  elseif l:before =~# '\s*\<where\>'
    call s:debug_print('where$')
    return l:indent + 6

  elseif l:before =~# '=\s*$'
    call s:debug_print('=<CR>')
    return &shiftwidth

    " ぶら下がりラムダ
  elseif l:before =~# '=.*->\s*$'
    call s:debug_print('dropped lambda')
    return match(l:before, '\<', match(l:before, '='))

  elseif l:before =~# '^\<data\>.*='
    call s:debug_print('data =')
    return match(l:before, '=')

  elseif l:before =~# '^\<data\>'
    call s:debug_print('data')
    return &shiftwidth

  elseif l:line =~# '\s*\<where\>'
    call s:debug_print('where')
    return &shiftwidth / 2

  endif

  call s:debug_print('last indent: ' . l:indent)
  if l:indent
    return l:indent
  else 
    return -1
  endif
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
