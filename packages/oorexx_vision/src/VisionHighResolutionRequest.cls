/* VisionHighResolutionRequest.cls -- dev15
 * Selective source-resolution evidence escalation.
 */

::class VisionHighResolutionRequest public
::method init
  expose request requestId reason priority requestedWidth requestedHeight colourRequirement evidenceClass state
  use strict arg sourceRef,region,startTime,endTime,reason='EVIDENCE',requestId=.nil
  request=.VisionRegionRequest~new(sourceRef,region,startTime,endTime)
  request~requestedSpatialResolution='SOURCE'; request~purpose=reason
  if requestId == .nil then requestId='HR-' || startTime || '-' || region~x || '-' || region~y
  priority='NORMAL'; requestedWidth=.nil; requestedHeight=.nil
  colourRequirement='SOURCE'; evidenceClass='HIGH_RESOLUTION_REGION'; state='REQUESTED'
::attribute request get
::attribute requestId get
::attribute reason get
::attribute priority
::attribute requestedWidth
::attribute requestedHeight
::attribute colourRequirement
::attribute evidenceClass
::attribute state get

::method requireDimensions
  expose requestedWidth requestedHeight request
  use strict arg width,height
  if width<1 | height<1 then raise syntax 40.900 array('high-resolution dimensions must be positive')
  requestedWidth=width; requestedHeight=height
  request~requestedSpatialResolution=width || 'x' || height
  return self

::method markFulfilled
  expose state request
  use strict arg resultRef
  if state \== 'REQUESTED' then raise syntax 40.900 array('high-resolution request is not pending')
  request~resultRef=resultRef; state='FULFILLED'
  return self

::method sourceRef; expose request; return request~sourceRef
::method region; expose request; return request~region
::method startTime; expose request; return request~startTime
::method endTime; expose request; return request~endTime
::method asRegionRequest; expose request; return request

::class VisionHighResolutionEvidence public
::method init
  expose highResolutionRequest material provenanceRef
  use strict arg highResolutionRequest,material
  if \material~isInstanceOf(.VisionRegionMaterial) then raise syntax 40.900 array('VisionRegionMaterial required')
  provenanceRef=.nil
::attribute highResolutionRequest get
::attribute material get
::attribute provenanceRef

::requires 'Vision.cls'
