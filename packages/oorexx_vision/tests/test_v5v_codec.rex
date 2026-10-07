/* Exact V5V temporal round-trip. */
a=.VisionSurface~new(4,3,5,26)
b=.VisionSurface~new(4,3,5,26)
do y=0 to 2
  do x=0 to 3
    a~put(x,y,(x+y)//26)
    b~put(x,y,(x+y)//26)
  end
end
b~put(2,1,17); b~timestamp=1

enc=.V5VTemporalCodec~new(.V5VCodecPolicy~new(25,.true,'EXACT_DELTA'))
r0=enc~encodeSurface(a)
r1=enc~encodeSurface(b)
if r0~recordType \== 'KEYFRAME' then do; say 'FAIL keyframe'; exit 1; end
if r1~recordType \== 'DELTA' | r1~changedCount<>1 then do; say 'FAIL delta'; exit 1; end

dec=.V5VTemporalCodec~new
x=dec~decodeRecord(r0)
y=dec~decodeRecord(r1)
if y~packedBytes \== b~packedBytes then do; say 'FAIL round trip'; exit 1; end
say 'PASS exact V5V round trip changed='r1~changedCount
::requires '../src/V5VCodec.cls'
