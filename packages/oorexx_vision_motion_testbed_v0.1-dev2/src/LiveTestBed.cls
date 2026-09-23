/*
 * Application composition parser for native Vision transaction records.
 * Temporal state remains in oorexx_motion_control.
 */
::class LiveVisionRecord public
::method init
  expose sequence sourceTime width height rgbBytes packedBytes rgbEvidence visionEvidence
  use strict arg sequence,sourceTime,width,height,rgbBytes,packedBytes,rgbEvidence,visionEvidence
::attribute sequence get
::attribute sourceTime get
::attribute width get
::attribute height get
::attribute rgbBytes get
::attribute packedBytes get
::attribute rgbEvidence get
::attribute visionEvidence get

::class LiveTestBed public
::method parseRecord
  use strict arg line
  p=line~makeArray(.tab)
  if p~items<9 | p[1]\=="VISION" then return .nil
  return .LiveVisionRecord~new(p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9])
