/* VisionHighResolutionRequest.cls
 * Selective source-resolution evidence request.
 *
 * The compact V5V stream is not promoted into source truth.  A high-resolution
 * request refers back to the authoritative source and stable source/world
 * coordinates, then returns material by reference.
 */

::class VisionHighResolutionRequest public
::method init
  expose request reason priority requestedWidth requestedHeight colourRequirement evidenceClass
  use strict arg sourceRef,region,startTime,endTime,reason='EVIDENCE'
  request=.VisionRegionRequest~new(sourceRef,region,startTime,endTime)
  request~requestedSpatialResolution='SOURCE'
  request~purpose=reason
  priority='NORMAL'
  requestedWidth=.nil
  requestedHeight=.nil
  colourRequirement='SOURCE'
  evidenceClass='HIGH_RESOLUTION_REGION'

::attribute request get
::attribute reason get
::attribute priority
::attribute requestedWidth
::attribute requestedHeight
::attribute colourRequirement
::attribute evidenceClass

::method sourceRef
  expose request
  return request~sourceRef
::method region
  expose request
  return request~region
::method startTime
  expose request
  return request~startTime
::method endTime
  expose request
  return request~endTime

::method requireDimensions
  expose requestedWidth requestedHeight request
  use strict arg width,height
  if width<1 | height<1 then raise syntax 40.900 array('high-resolution dimensions must be positive')
  requestedWidth=width
  requestedHeight=height
  request~requestedSpatialResolution=width || 'x' || height
  return self

::method asRegionRequest
  expose request
  return request

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
