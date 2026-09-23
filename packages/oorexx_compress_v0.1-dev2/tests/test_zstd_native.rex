/* Pure ooRexx Zstandard bootstrap-profile qualification. */
numeric digits 80
codec = .Compress~new
failures = 0

if d2x(codec~xxh64(''),16) \== 'EF46DB3751D8E999' then call fail 'XXH64 empty-input vector failed'
if d2x(codec~xxh64('hello'),16) \== '26C7827D889F6DA3' then call fail 'XXH64 hello vector failed'

/* Checksummed ordinary Raw and RLE frames. */
do data over .array~of('hello zstandard', copies('Z',4096))
  frame = codec~zstd(data,'AUTO',.true)
  if codec~unzstd(frame) \== data then call fail 'checksummed Zstandard round trip failed at length ' || length(data)
end

/* FCS representation boundaries and multi-block transition. */
sizes = .array~of(0,1,17,255,256,65791,65792,131072,131073)
do n over sizes
  data = copies('x',n)
  frame = codec~zstd(data,'RAW',.false)
  if codec~unzstd(frame) \== data then call fail 'FCS/boundary round trip failed at length ' || n
end

/* RLE block path over more than one 128 KiB block. */
rleData = copies('R',200000)
rleFrame = codec~zstd(rleData,'RLE',.false)
if codec~unzstd(rleFrame) \== rleData then call fail 'multi-block RLE round trip failed'
if length(rleFrame) >= 100 then call fail 'RLE frame unexpectedly large: ' || length(rleFrame)

/* Concatenated standard frames. */
cat = codec~zstd('alpha','RAW',.false) || codec~zstd('beta','RAW',.false)
if codec~unzstd(cat) \== 'alphabeta' then call fail 'concatenated frame decode failed'

/* Skippable frames may occur alone or between standard frames. */
skip = le32(x2d('184D2A50')) || le32(5) || 'HELLO'
if codec~unzstd(skip) \== '' then call fail 'skippable-only stream did not decode to empty content'
mixed = codec~zstd('left','RAW',.false) || skip || codec~zstd('right','RAW',.false)
if codec~unzstd(mixed) \== 'leftright' then call fail 'skippable mixed stream decode failed'


/* Frame-header standards edges: unused bit is ignored; reserved bit is fatal. */
baseFrame = codec~zstd('header-edge','RAW',.false)
unusedFrame = overlay(bitor(substr(baseFrame,5,1),'10'x),baseFrame,5,1)
if codec~unzstd(unusedFrame) \== 'header-edge' then call fail 'frame unused bit was interpreted instead of ignored'
reservedFrame = overlay(bitor(substr(baseFrame,5,1),'08'x),baseFrame,5,1)
if \mustReject(codec,reservedFrame) then call fail 'reserved frame-header bit was accepted'

/* Reserved block type 3 must be rejected. Empty native frame has block header at byte 7. */
emptyFrame = codec~zstd('','RAW',.false)
reservedBlock = overlay('07'x,emptyFrame,7,1)
if \mustReject(codec,reservedBlock) then call fail 'reserved Zstandard block type 3 was accepted'

/* A non-zero Dictionary_ID is an explicit native capability boundary. */
dictFrame = x2c('28B52FFD') || '21'x || '01'x || '00'x || '01'x || '00'x || '00'x
if \mustReject(codec,dictFrame) then call fail 'non-zero Zstandard Dictionary_ID was accepted without a dictionary'

/* Corrupt the content checksum only. */
valid = codec~zstd('checksum-target','RAW',.true)
bad = overlay(bitxor(substr(valid,length(valid),1),'01'x),valid,length(valid),1)
if \mustReject(codec,bad) then call fail 'content-checksum corruption was accepted'

if failures = 0 then do
  say 'PASS native Zstandard bootstrap-profile qualification'
  say 'xxh64_empty=EF46DB3751D8E999'
  say 'rle_input_bytes=' length(rleData) 'rle_frame_bytes=' length(rleFrame)
  exit 0
end
say 'FAIL count=' failures
exit 1

fail: procedure expose failures
  parse arg message
  failures += 1
  say 'FAIL:' message
  return

mustReject: procedure
  use strict arg codec, bytes
  signal on syntax name rejected
  ignored = codec~unzstd(bytes)
  return .false
rejected:
  return .true

le32: procedure
  use strict arg n
  numeric digits 80
  out=''
  do 4
    out ||= d2c(n // 256,1)
    n = n % 256
  end
  return out

::requires '../src/Compress.cls'
