call testEqualAndPosition
call testHighVsEqualOrHigh
call testResidualAndZeroKey
call testMultitrackFileProtect
say 'PASS test_3330_search_key_semantics'
exit 0

testEqualAndPosition:
  media=.FakeMedia~new(.array~of( -
    .IBM370CKDRecord~new(0,0,1,'C1C2C3','11'), -
    .IBM370CKDRecord~new(0,0,2,'C1C2C4','22')))
  dev=.IBM3330Device~new(x2d('0350'),media)
  st=.IBM370Storage~new(65536); st~storeHex(x2d('100'),'C1C2C3')
  p=.IBM370ChannelProgram~new(x2d('0350'),8,'SIO')
  ccw=.IBM370CCW0~new('2900010000000003')
  r=dev~executeCCW(ccw,st,p)
  call assertEq 'equal status', r~unitStatus, x2d('4C')
  call assertEq 'equal record', dev~record, 1
  r=dev~executeCCW(ccw,st,p)
  call assertEq 'repeat advances status', r~unitStatus, x2d('0C')
  call assertEq 'repeat advances record', dev~record, 2
  return

testHighVsEqualOrHigh:
  media=.FakeMedia~new(.array~of(.IBM370CKDRecord~new(0,0,1,'C1C2C3','11')))
  st=.IBM370Storage~new(65536)
  p=.IBM370ChannelProgram~new(x2d('0350'),8,'SIO')
  st~storeHex(x2d('100'),'C1C2C2')
  dev=.IBM3330Device~new(x2d('0350'),media)
  r=dev~executeCCW(.IBM370CCW0~new('4900010000000003'),st,p)
  call assertEq 'HIGH greater',r~unitStatus,x2d('4C')
  st~storeHex(x2d('100'),'C1C2C3')
  dev=.IBM3330Device~new(x2d('0350'),media)
  r=dev~executeCCW(.IBM370CCW0~new('4900010000000003'),st,p)
  call assertEq 'HIGH equal does not match',r~unitStatus,x2d('0C')
  dev=.IBM3330Device~new(x2d('0350'),media)
  r=dev~executeCCW(.IBM370CCW0~new('6900010000000003'),st,p)
  call assertEq 'EOH equal matches',r~unitStatus,x2d('4C')
  return

testResidualAndZeroKey:
  st=.IBM370Storage~new(65536); st~storeHex(x2d('100'),'C1C20000')
  p=.IBM370ChannelProgram~new(x2d('0350'),8,'SIO')
  media=.FakeMedia~new(.array~of(.IBM370CKDRecord~new(0,0,1,'C1C2','11')))
  dev=.IBM3330Device~new(x2d('0350'),media)
  r=dev~executeCCW(.IBM370CCW0~new('2900010000000004'),st,p)
  call assertEq 'short key moved',r~transferred,2
  call assertEq 'short key residual',r~residual,2
  call assertEq 'short key match',r~unitStatus,x2d('4C')
  media=.FakeMedia~new(.array~of(.IBM370CKDRecord~new(0,0,1,'','11')))
  dev=.IBM3330Device~new(x2d('0350'),media)
  r=dev~executeCCW(.IBM370CCW0~new('2900010000000004'),st,p)
  call assertEq 'zero key moved',r~transferred,0
  call assertEq 'zero key residual',r~residual,4
  call assertEq 'zero key normal',r~unitStatus,x2d('0C')
  return

testMultitrackFileProtect:
  media=.FakeMedia~new(.array~of(.IBM370CKDRecord~new(0,0,1,'C1','11')))
  st=.IBM370Storage~new(65536); st~storeHex(x2d('100'),'C1')
  p=.IBM370ChannelProgram~new(x2d('0350'),8,'SIO'); p~setFileMask(x2d('58')); p~setIndexMark(1); p~setIndexMark(0)
  dev=.IBM3330Device~new(x2d('0350'),media)
  /* First compare consumes record 1 and leaves orientation AFTER_KEY. */
  r=dev~executeCCW(.IBM370CCW0~new('2900010000000001'),st,p)
  call assertEq 'setup match',r~unitStatus,x2d('4C')
  r=dev~executeCCW(.IBM370CCW0~new('A900010000000001'),st,p)
  call assertEq 'MT SFM58 unit check',r~unitStatus,x2d('0E')
  call assertEq 'MT SFM58 sense',dev~pendingSenseHex~left(4),'0004'
  return

assertEq:
  use arg label,got,want
  if got<>want then raise syntax 40.900 array(label,'got='got,'want='want)
  return

::class FakeMedia public subclass IBM370CCKDMedia
::method init
  expose recs
  use strict arg a
  recs=a
::method mediaId; return 'FAKE'
::method mediaDigest; return 'FAKE'
::method heads; return 19
::method cylinders; return 404
::method records
  expose recs
  use strict arg cyl,head
  return recs
::method recordByNumber
  expose recs
  use strict arg cyl,head,n
  do r over recs
    if r~record=n then return r
  end
  return .nil

::requires 'IBM370DASD.cls'
::requires 'IBM370Architecture.cls'
