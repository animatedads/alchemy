/* Source-level protection for selective, evidence-preserving recovery.
 * A region request is not permission to reconstruct every pixel it contains.
 * The caller supplies protected VisionRegion zones in source coordinates.
 * Never use a semantic detector's prediction to remove a protected zone.
 */
::class VisionRecoveryPrivacy public
::method init
  expose sourceRef protected
  use strict arg sourceRefArg, protectedArg=.nil
  if sourceRefArg=.nil then raise syntax 93.900 array('Source reference required')
  if strip(sourceRefArg~string)='' then raise syntax 93.900 array('Source reference required')
  sourceRef=sourceRefArg
  protected=.array~new
  if protectedArg<>.nil then do region over protectedArg
    self~protect(region)
  end

::method protect
  expose protected
  use strict arg region
  if \region~isA(.VisionRegion) then raise syntax 93.900 array('VisionRegion required')
  protected~append(region)
  return protected~items

::method protectedCount
  expose protected
  return protected~items

::method admitsPoint
  expose protected
  use strict arg request, px, py
  if \request~isA(.VisionRegionRequest) then return .false
  if request~sourceRef<>self~sourceRef then return .false
  if \request~region~contains(px,py) then return .false
  do p over protected
    if p~contains(px,py) then return .false
  end
  return .true

::method admitsWholeRegion
  expose protected
  use strict arg request
  if \request~isA(.VisionRegionRequest) then return .false
  if request~sourceRef<>self~sourceRef then return .false
  do p over protected
    if request~region~intersects(p) then return .false
  end
  return .true

::method sourceRef
  expose sourceRef
  return sourceRef

::requires 'Vision.cls'
