parse source . . here
root=filespec('location',here)||'..'
fixture=filespec('location',here)||'lazy-basic.bin'
call stream fixture,'c','open write replace'
call charout fixture,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
call stream fixture,'c','close'

f=.LazyReadFile~new(fixture,8)
call assertEq 36,f~sizeBytes,'size'
call assertEq 0,f~tell,'initial cursor'
call assertEq '0123',f~loadPartial(0,4),'absolute read'
call assertEq 0,f~tell,'absolute read leaves cursor'
call assertEq 8,f~cachedBytes,'aligned cache size'
call assertEq 0,f~cachedOffset,'first cache offset'
loads=f~blocksLoaded
call assertEq '4567',f~loadPartial(4,4),'same-block read'
call assertEq loads,f~blocksLoaded,'cache hit avoids reload'
call assertTrue f~cacheHits>0,'cache hit counted'

call assertEq '01234567',f~read(8),'cursor read'
call assertEq 8,f~tell,'cursor advanced'
call assertEq '89ABCDEF',f~read(8),'cross-aligned cursor read'
call assertEq 16,f~tell,'cursor advanced again'

f~seek(34)
call assertEq 'YZ',f~read(8),'EOF truncates bounded read'
call assertTrue f~eof,'EOF'
call assertEq '',f~read(8),'read at EOF'

f~seek(7)
call assertEq '7',f~byteAt(7),'byteAt'
f~release
call assertEq 0,f~cachedBytes,'release drops retained data'
call assertEq -1,f~cachedOffset,'release drops cache position'

f~rewind
f~skip(10)
call assertEq 10,f~tell,'skip'
call assertEq 'A',f~read(1),'read after skip'

f~close
call assertFalse f~opened,'closed'
call stream fixture,'c','close'
call SysFileDelete fixture
say 'PASS test_basic'
exit 0

assertEq: procedure
  use arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return
assertTrue: procedure
  use arg value,label
  if \value then do; say 'FAIL' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value then do; say 'FAIL' label; exit 1; end
  return

::requires '../src/LazyReadFile.cls'
