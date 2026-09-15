/* Fixture path is supplied by run.sh.  It is sparse, so the test validates
 * >32-bit offsets without allocating or writing five GiB of physical data. */
use arg fixture
numeric digits 20
if fixture='' then do; say 'FAIL missing fixture'; exit 2; end

f=.LazyReadFile~new(fixture,1048576)
expected=5*1024*1024*1024+123
call assertEq expected,f~sizeBytes,'exact >5GiB size'

/* Sentinels are deliberately placed around 4GiB and the physical EOF. */
call assertEq 'FOUR_GIB',f~loadPartial(4294967296+17,8),'read beyond 4GiB'
call assertEq 'FIVE_GIB',f~loadPartial(5368709120+37,8),'read beyond 5GiB'
call assertEq 'TAIL',f~loadPartial(expected-4,4),'read final bytes'

f~seek(5368709120+37)
call assertEq 'FIVE_GIB',f~read(8),'cursor beyond 5GiB'
call assertEq 5368709120+45,f~tell,'exact large cursor'

f~release
call assertEq 0,f~cachedBytes,'release after large offset'
f~close
say 'PASS test_sparse_5g'
exit 0

assertEq: procedure
  numeric digits 20
  use arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

::requires '../src/LazyReadFile.cls'
