/* V5VCodec.cls
 * ooRexx Vision v0.1-dev15
 *
 * V5V is a processable-video codec: preserve useful observation and remove
 * redundant representation.  This baseline is lossless relative to the
 * encoded VisionSurface.
 */

::class V5VCodecPolicy public
::method init
  expose keyFrameInterval exactSurface temporalMode
  use strict arg keyFrameInterval=25, exactSurface=.true, temporalMode='EXACT_DELTA'
  if \datatype(keyFrameInterval,'W') | keyFrameInterval < 1 then raise syntax 40.900 array('keyFrameInterval must be >= 1')
::attribute keyFrameInterval
::attribute exactSurface
::attribute temporalMode

::class V5VFrameRecord public
::method init
  expose sequence timestamp recordType payload changedCount
  use strict arg sequence,timestamp,recordType,payload,changedCount=0
::attribute sequence get
::attribute timestamp get
::attribute recordType get
::attribute payload get
::attribute changedCount get

::class V5VTemporalCodec public
::method init
  expose policy previous sequence
  use strict arg policy=.nil
  if policy == .nil then policy=.V5VCodecPolicy~new
  previous=.nil; sequence=0
::attribute policy get

::method reset
  expose previous sequence
  previous=.nil; sequence=0
  return self

::method encodeSurface
  expose policy previous sequence
  use strict arg surface
  if \policy~exactSurface then raise syntax 40.900 array('dev15 only admits EXACT_SURFACE encoding')
  timestamp=surface~timestamp
  if previous == .nil then
    record=.V5VFrameRecord~new(sequence,timestamp,'KEYFRAME',surface,surface~width*surface~height)
  else if sequence//policy~keyFrameInterval=0 then
    record=.V5VFrameRecord~new(sequence,timestamp,'KEYFRAME',surface,surface~width*surface~height)
  else do
    /* VisionSurfaceDelta is constructed directly; dev14 incorrectly called a
       nonexistent ~between factory. */
    delta=.VisionSurfaceDelta~new(previous,surface)
    record=.V5VFrameRecord~new(sequence,timestamp,'DELTA',delta,delta~changedCount)
  end
  previous=surface
  sequence=sequence+1
  return record

::method decodeRecord
  expose previous
  use strict arg record
  select
    when record~recordType == 'KEYFRAME' then surface=record~payload
    when record~recordType == 'DELTA' then do
      if previous == .nil then raise syntax 40.900 array('V5V delta has no base surface')
      surface=record~payload~applyTo(previous)
      surface~timestamp=record~timestamp
    end
    otherwise raise syntax 40.900 array('unknown V5V record type:' record~recordType)
  end
  previous=surface
  return surface

::method evidenceMap
  use strict arg cameraEvidence=.nil,lineEvidence=.nil
  m=.directory~new
  m['CAMERA']=cameraEvidence; m['LINE']=lineEvidence
  return m

::requires 'Vision.cls'
