lib=.foreign~load('ffmpeg_avformat.bridge.json')
ri=.foreign~runtimeInfo
if ri~maxArity<>0 then do
  say 'SKIP FFmpeg avformat: dynamic libffi arity unavailable'
  exit 0
end
if lib~version=0 then do
  say 'FAIL avformat_version returned zero'
  exit 1
end
r=lib~open_input(.foreign~out,'tiny.wav',.nil,.nil)
if \r~isA(.ForeignResult) then do
  say 'FAIL avformat_open_input did not return ForeignResult'
  exit 2
end
if r~returnValue<>0 then do
  say 'FAIL avformat_open_input rc='r~returnValue
  exit 3
end
ctx=r~out('context')
if \ctx~isA(.ForeignObject) then do
  say 'FAIL AVFormatContext output not ForeignObject'
  exit 4
end
if ctx~type<>'AVFormatContext' then do
  say 'FAIL context type='ctx~type
  exit 5
end
rc=lib~find_stream_info(ctx,.nil)
if rc<0 then do
  say 'FAIL avformat_find_stream_info rc='rc
  exit 6
end
sig=lib~method('open_input')~signatures[1]
if sig~inputCount<>4 then do
  say 'FAIL open_input signature arity='sig~inputCount
  exit 7
end
if sig~inputs[1]~pointerDepth<>2 then exit 8
if sig~inputs[1]~destructorPointerDepth<>2 then exit 9
ctx~close
lib~close
say 'PASS Foreign Runtime -> FFmpeg avformat open/find/close'
exit 0
::requires '../../rexx/foreign.cls'
