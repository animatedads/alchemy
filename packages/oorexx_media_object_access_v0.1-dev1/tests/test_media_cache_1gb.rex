/* 1 GiB logical source, four distant jumps, repeated window cache hit.
 * No file bytes are allocated and no source download is permitted. */
numeric digits 30
src=.GigabytePatternSource~new
cache=.MediaRangeCacheSource~new(src,4096,3)
a=cache~readAt(1000000010,6)
if a<>'AAAAAA' then call fail 'first remote window incorrect'
before=src~reads
b=cache~readAt(1000000012,4)
if b<>'AAAA' then call fail 'repeat window incorrect'
if src~reads<>before then call fail 'repeat window triggered remote read'
c=cache~readAt(900000010,6)
d=cache~readAt(500000010,6)
if c<>'AAAAAA' | d<>'AAAAAA' then call fail 'non-adjacent jump incorrect'
e=cache~readAt(1000000010,6)
if src~reads<>3 then call fail 'resident block did not produce cache hit'
f=cache~readAt(100000010,6)
if cache~blocksRetained<>3 then call fail 'LRU block cap exceeded'
if cache~bytesFetched>16384 then call fail 'unexpected download volume'
if src~requested<>cache~bytesFetched then call fail 'instrumentation mismatch'
say 'PASS: 1 GiB logical media, hot jumps, repeated-hit, LRU cap; bytes fetched='cache~bytesFetched
exit 0
fail: procedure
  use strict arg reason
  say 'FAIL:' reason
  exit 1
::class GigabytePatternSource subclass MediaByteSource public
::attribute reads get
::attribute requested get
::method init
  expose reads requested
  reads=0; requested=0
::method sourceIdentity
  return 'immutable:one-gigabyte:v1'
::method sizeBytes
  return 1073741824
::method readAt
  expose reads requested
  use strict arg offset,count
  if offset<0 | count>4096 | offset+count>1073741824 then -
    raise syntax 88.900 array('unbounded remote source read',offset,count)
  reads=reads+1; requested=requested+count
  return copies('A',count)
::requires '../src/MediaByteSource.cls'
::requires '../src/MediaRangeCache.cls'
