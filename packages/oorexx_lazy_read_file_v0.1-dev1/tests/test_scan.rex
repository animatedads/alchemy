use arg fixture
numeric digits 20
f=.LazyReadFile~new(fixture,8388608)
total=0
blocks=0
do while \f~eof
  data=f~nextBlock
  total+=data~length
  blocks+=1
  /* A real consumer processes DATA here and then overwrites it next loop. */
end
call assertEq f~sizeBytes,total,'scan byte count'
call assertTrue f~blocksLoaded<=blocks+1,'one load per sequential block'
f~release
call assertEq 0,f~cachedBytes,'scan release'
f~close
say 'PASS test_scan bytes='total 'blocks='blocks
exit 0

assertEq: procedure
  numeric digits 20
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label expected actual; exit 1; end
  return
assertTrue: procedure
  use arg value,label
  if \value then do; say 'FAIL' label; exit 1; end
  return

::requires '../src/LazyReadFile.cls'
