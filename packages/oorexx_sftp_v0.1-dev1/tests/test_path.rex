call assert .SftpPath~canonical('/a/b')=='/a/b','absolute canonical'
call assert .SftpPath~canonical('a/./b')=='/a/b','dot removed'
call assert .SftpPath~canonical('/a/c/../b')=='/a/b','parent normalized'
signal on syntax name trap
x=.SftpPath~canonical('../../etc/passwd')
signal off syntax
call assert .false,'escape should fail'
trap:
  signal off syntax
  call assert .true,'escape rejected'
  say 'PASS test_path'
  exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
