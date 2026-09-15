media=.FakeMedia~new(.array~of( -
  .IBM370CKDRecord~new(0,0,1,'AA','1111'), -
  .IBM370CKDRecord~new(0,0,2,'BB','2222')))
dev=.IBM3330Device~new(x2d('350'),media)
st=.IBM370Storage~new(65536)
p=.IBM370ChannelProgram~new(x2d('350'),8,'SIO'); p~setFileMask(x2d('58'))
ccw=.IBM370CCW0~new('9200010000000008')
r=dev~executeCCW(ccw,st,p)
call ae 'record1 status',r~unitStatus,x2d('0C'); call ae 'record1',dev~record,1
r=dev~executeCCW(ccw,st,p)
call ae 'record2 status',r~unitStatus,x2d('0C'); call ae 'record2',dev~record,2
r=dev~executeCCW(ccw,st,p)
call ae 'EOT file protect status',r~unitStatus,x2d('0E')
call ae 'EOT file protect sense',dev~pendingSenseHex~left(4),'0004'
say 'PASS test_3330_mt_read_count_file_mask'
exit 0
ae: use arg l,g,w; if g<>w then raise syntax 40.900 array(l,'got='g,'want='w); return
::class FakeMedia public subclass IBM370CCKDMedia
::method init; expose recs; use strict arg a; recs=a
::method mediaId; return 'FAKE'
::method mediaDigest; return 'FAKE'
::method heads; return 19
::method cylinders; return 404
::method records; expose recs; use strict arg c,h; return recs
::method recordByNumber; expose recs; use strict arg c,h,n; do r over recs; if r~record=n then return r; end; return .nil
::requires 'IBM370DASD.cls'
::requires 'IBM370Architecture.cls'
