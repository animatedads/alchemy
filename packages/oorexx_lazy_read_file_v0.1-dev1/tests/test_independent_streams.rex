parse source . . here
fixture=filespec('location',here)||'lazy-independent.bin'
call stream fixture,'c','open write replace'
call charout fixture,'abcdefghijklmnopqrstuvwxyz'
call stream fixture,'c','close'

a=.LazyReadFile~new(fixture,8)
b=.LazyReadFile~new(fixture,8)
call assertEq 'abcdefgh',a~read(8),'a first read'
call assertEq 'qrstuvwx',b~loadPartial(16,8),'b independent absolute read'
a~close
call assertEq 'ijklmnop',b~loadPartial(8,8),'b remains open after a closes'
b~close
call SysFileDelete fixture
say 'PASS test_independent_streams'
exit 0

assertEq: procedure
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label expected actual; exit 1; end
  return

::requires '../src/LazyReadFile.cls'
