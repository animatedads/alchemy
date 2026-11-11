/* Real MP4 production adapter comparison, ooRexx 5.3 r13196.
 * Requires resident source and native in-process codec package moa_h264.
 * Compare canonical MediaFile/MediaMp4Track mapping against independently
 * qualified test-only direct AVC parser on the SAME 1080p original.
 * No output pixels, user media or source hashes are published.
 * Usage: rexx test_mp4_production_h264.rex /resident/video.mp4
 */
numeric digits 30
parse arg localOriginal
if localOriginal='' then do
  say 'BLOCKED: supply locally resident MP4 original as argument'
  exit 2
end
src=.MediaLocalByteSource~new(localOriginal)
movie=.MediaFile~openMp4(src)
if movie~layout<>'MOVIE' then call fail 'unsupported MP4 layout'
production=.MediaMp4H264Frames~new(movie)
control=.MediaMp4AvcAccess~new(src)
if production~track~kind<>'vide' then call fail 'production chose non-video track'
call compareSeek 90000*5
call compareSeek 90000*30
call compareSeek 90000*60
src~close
say 'PASS: canonical MP4 media-track sample mapping, 3 real H264 seeks, exact RGB24 match'
exit 0

compareSeek: procedure expose production control
  use strict arg ticks
  target=production~frameAt(ticks,4194304,240)
  reference=control~frameAt(ticks,4194304,240)
  if target==.nil | reference==.nil then call fail 'missing decoded frame at '||ticks
  if target~presentationTicks<>reference~presentationTicks then -
    call fail 'presentation-time disagreement at '||ticks
  if target~width<>reference~width | target~height<>reference~height then -
    call fail 'decoded dimensions disagree at '||ticks
  if target~pixels<>reference~pixels then -
    call fail 'decoded RGB24 pixels disagree at '||ticks
  if production~readBytesLast>4194304 then -
    call fail 'compressed-source budget exceeded at '||ticks
  if target~presentationTicks<ticks then -
    call fail 'returned frame before requested presentation time'
  if target~presentationTicks-ticks>9000 then -
    call fail 'seek exceeded 100ms requested frame tolerance'
  say 'QUALIFIED_CANDIDATE' ticks 'PTS='target~presentationTicks -
    'sourceBytes='production~readBytesLast 'referenceBytes='control~frameReadBytes
  return

fail: procedure
  use strict arg reason
  say 'FAIL:' reason
  exit 1

::requires '../src/MediaByteSource.cls'
::requires '../src/MediaLocalByteSource.cls'
::requires '../src/Mp4File.cls'
::requires '../src/MediaMp4H264Frames.cls'
::requires 'support/MediaMp4AvcAccess.cls'
