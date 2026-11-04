/* Synthetic source-coordinate gating: no media bytes. */
policy=.VisionRecoveryPrivacy~new('synthetic-source')
region=.VisionRegion~new(0,0,10,10)
request=.VisionRegionRequest~new('synthetic-source',region,0,1)
call check policy~admitsPoint(request,2,2), 'unprotected pixel'
call check policy~admitsWholeRegion(request), 'unprotected region'
policy~protect(.VisionRegion~new(4,2,3,5))
call check \policy~admitsPoint(request,5,3), 'protected pixel rejected'
call check policy~admitsPoint(request,1,1), 'other pixel permitted'
call check \policy~admitsWholeRegion(request), 'whole-region rejection avoids bypass'
call check \policy~admitsPoint(.VisionRegionRequest~new('other',region,0,1),1,1), 'source isolation'
call check \policy~admitsPoint(request,12,2), 'outside request'
say 'VISION_RECOVERY_PRIVACY 7/7 PASS'
exit 0
::routine check
  use strict arg predicate, name
  if \predicate then raise syntax 93.900 array('FAIL',name)
::requires 'VisionRecoveryPrivacy.cls'
