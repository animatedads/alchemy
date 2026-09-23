/* V5VCodec.cls
 * V5V processable-video codec contract, dev14.
 *
 * Principle: remove redundant representation before removing observation.
 * This module provides the wire-facing temporal record vocabulary.  It does
 * not perform motion classification, line classification or object identity.
 */

::class V5VCodecPolicy public
::method init
  expose keyFrameInterval exactSurface temporalMode
  use strict arg keyFrameInterval=25, exactSurface=.true, temporalMode='EXACT_DELTA'
  if keyFrameInterval < 1 then raise syntax 40.900 array('keyFrameInterval must be >= 1')
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
  previous=.nil
  sequence=0

::attribute policy get

::method reset
  expose previous sequence
  previous=.nil
  sequence=0
  return self

::method encodeSurface
  expose policy previous sequence
  use strict arg surface
  timestamp=surface~timestamp
  if previous == .nil | sequence//policy~keyFrameInterval=0 then do
    payload=surface~packedBytes
    record=.V5VFrameRecord~new(sequence,timestamp,'KEYFRAME',payload,surface~width*surface~height)
  end
  else do
    /* VisionSurfaceDelta remains the semantic exact-delta authority.  Wire
       packing/compression is deliberately replaceable without changing what
       the delta means. */
    delta=.VisionSurfaceDelta~between(previous,surface)
    record=.V5VFrameRecord~new(sequence,timestamp,'DELTA',delta,delta~changedCount)
  end
  previous=surface
  sequence=sequence+1
  return record

/* A request from Camera Behaviour or Line Assessment is advisory evidence
 * about where fidelity is valuable.  It may change packing decisions, but it
 * must never silently change an EXACT_SURFACE policy into a lossy one. */
::method evidenceMap
  use strict arg cameraEvidence=.nil,lineEvidence=.nil
  m=.directory~new
  m['CAMERA']=cameraEvidence
  m['LINE']=lineEvidence
  return m

::requires 'Vision.cls'
