text = .SecurityCanonical~field('A','B')
call assertEqual 4,text~length,'canonical field uses A=B plus one newline byte'
call assertEqual '0A',c2x(text~right(1)),'canonical separator is real LF byte'
call assertTrue pos('\\n',text) = 0,'canonical text does not contain literal backslash-n'
say 'PASS test_canonical_newlines'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffect.cls'
