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

function! s:in_do_notation(lnum)
  return s:search_back('\<do\>', a:lnum - 1)[0] >= 0
endfunction

function! s:in_where(lnum)
  let [l:lnum_cr, l:line_cr] = s:search_back('\<where\>\s*$', a:lnum - 1)
  echo getline(nextnonblank(l:lnum_cr + 1))
  if l:lnum_cr >= 0
    return match(getline(nextnonblank(l:lnum_cr + 1)), '\S')
  else
    let [l:lnum, l:line] = s:search_back('\<where\>\s*\S\+', a:lnum)
    if l:lnum >= 0
      return match(l:line, '\S', match(l:line, '\<where\>') + 5)
    else 
      return -1
    endif
  endif
endfunction

function! s:top_level(lnum)
  let l:lnum = a:lnum
  while l:lnum >= 0
    let l:line = getline(l:lnum)
    if l:line =~# '^\S'
      return l:lnum
    endif
    let l:lnum -= 1
  endwhile
endfunction

function! s:debug_print(num)
  echo 'Rule ' . a:num
endfunction

function! haskellindent#indentexpr(lnum)
  let l:before   = getline(a:lnum - 1)
  let l:line     = getline(a:lnum)
  let l:indent   = indent(a:lnum - 1)

  if l:line =~# '^\s*,'
    call s:debug_print('comma')
    return match(l:before, '{\|,\|\[')

  elseif l:line =~# '^\s*)'
    call s:debug_print('close )')
    return match(s:search_back('(', a:lnum -1)[1], '(')

  elseif l:line =~# '\<in\>'
    call s:debug_print('in')
    return match(s:search_back('\<let\>', a:lnum -1)[1], '\<let\>')

  elseif l:line =~# '^\s*\<deriving\>\s\+\<instance\>'
    call s:debug_print('deriving instance')
    return 0

  elseif l:line =~# '^\s*\(|\|deriving\)'
    if getline(s:top_level(a:lnum)) =~# '^\<data\>'
      let peq = match(s:search_back('[|=]', a:lnum - 1)[1], '[|=]')
      call s:debug_print('pipe&deriving: ' . peq)
      if peq > 0
        return peq
      else 
        return &shiftwidth
      endif
    endif

  elseif l:line =~# '^\s*->' 
    call s:debug_print('type ->')
    return match(l:before, '::')

  elseif l:line =~# '\<then\>'
    call s:debug_print('then')
    let [l:iflnum, l:ifline] = s:search_back('\<if\>', a:lnum - 1)
    if l:ifline =~# '->'
      return l:indent + &shiftwidth
    endif

    let l:ifpos = match(l:ifline, '\<if\>')
    if s:in_do_notation(a:lnum)
      return l:ifpos + &shiftwidth / 2
    else 
      return l:ifpos
    endif

  elseif l:line =~# '\<else\>'
    call s:debug_print('else')
    return match(s:search_back('\<then\>', a:lnum -1)[1], '\<then\>')

  elseif l:line =~# '^\s*\<of\>'
    call s:debug_print('<CR>of')
    return match(l:before, '\<case\>')

  elseif l:line =~# '^\s*{' && l:before =~# '^\<data\>'
    call s:debug_print("data X<CR>{")
    return &shiftwidth

  elseif l:before =~# '\S\+\s*\<where\>'
    let l:top = getline(s:top_level(a:lnum))
    if l:top =~# '^\<module\>'
      call s:debug_print('next of module where')
      return 0
    elseif l:top =~# '^\(\<instance\>\|\<class\>\)'
      call s:debug_print('next of instance/class where')
      return &shiftwidth
    endif

  elseif l:line =~# '^\s*\<module\>'
    call s:debug_print("module")
    return 0

  elseif l:before =~# '^\s*\<let\>.*=\s*$'
    call s:debug_print('let =<CR>')
    return match(l:before, '\<', match(l:before, '\<let\>') + 3) + &shiftwidth

  elseif l:before =~# '^\s*\<module\>'
    call s:debug_print('next of module')
    return &shiftwidth

  elseif l:before =~# '\<case\>.*\<of\>'
    call s:debug_print('case of')
    return l:indent + &shiftwidth

  elseif l:before =~# '::\s*$'
    call s:debug_print('next of ::')
    return &shiftwidth

  elseif l:before =~# '\<of\>'
    call s:debug_print('next of "of"')
    return match(l:before, '\<of\>') + 3

  elseif l:before =~# '\<do\>\s*$'
    call s:debug_print('do<CR>')
    return l:indent + &shiftwidth

  elseif l:before =~# '\<do\>'
    call s:debug_print('do')
    return match(l:before, '\<do\>') + 3

  elseif l:before =~# '=\s*$'
    let l:in_where = s:in_where(a:lnum)
    call s:debug_print('=<CR> where level: ' . l:in_where)
    if l:in_where >= 0
      return l:in_where + &shiftwidth
    else 
      return &shiftwidth
    endif

  elseif l:before =~# '^\s*\<where\>\s*$'
    call s:debug_print('where hoge')
    return l:indent + &shiftwidth / 2

  elseif l:before =~# '^\s*\<where\>'
    call s:debug_print('where$')
    return l:indent + 6

  elseif l:before =~# '\.*->\s*$'
    call s:debug_print('dropped lambda')
    if s:in_do_notation(a:lnum)
      return match(l:before, '\<', match(l:before, '=')) + &shiftwidth
    else 
      return match(l:before, '\<', match(l:before, '='))
    endif

  elseif l:before =~# '^\<data\>.*='
    call s:debug_print('data =')
    return match(l:before, '=')

  elseif l:before =~# '^\<data\>'
    call s:debug_print('data')
    return &shiftwidth

  elseif l:line =~# '^\s*\<where\>'
    call s:debug_print('where')
    return &shiftwidth / 2

  endif

  call s:debug_print('no rule')
  return -1

endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
