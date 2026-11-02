/* Compare fixed original and corrected bridge geometry on the SAME old image
 * annotations, with full six-variable fit. This is a diagnostic, NOT a valid
 * surveyed camera solution. Source: original 1536x709 still correspondences. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
say 'POWER SLAM v0.18: full camera re-optimisation with corrected bridge z and abutments'
do key over .array~of('NORTH_SHORE','BLUES_TOWER')
  say 'SITE' key
  old=.HarbourOtherCameraFit~new
  r0=old~fitSite(key,'BRIDGE',25)
  say 'OLD_FIT' key 'height='r0['POSE'][3] 'chi2='r0['CHI2'] 'status='r0['STATUS']
  new=.HarbourOtherCameraFit~new
  q=.HarbourBridgeVertical~apply(new~model~scene)
  if q['STATUS']\=='CORRECTED_CONTINUITY_GEOMETRY_UNSURVEYED' then raise syntax 88.900 array('failed corrected scene')
  r1=new~fitSite(key,'BRIDGE',25)
  say 'NEW_FIT' key 'height='r1['POSE'][3] 'chi2='r1['CHI2'] 'status='r1['STATUS']
  say 'DIFFERENCE height metres' r1['POSE'][3]-r0['POSE'][3]
  say 'OLD_HOLDOUT' old~qualify(key,r0)
  say 'NEW_HOLDOUT' new~qualify(key,r1)
  p0=old~holdouts(key,r0['POSE']);p1=new~holdouts(key,r1['POSE'])
  do i=1 to p0~items
    say 'HOLDOUT' p0[i][1] 'old px' format(p0[i][2],5,2) 'new px' format(p1[i][2],5,2)
  end
  if r1['POSE']==.nil then exit 6
end
say 'FULL_REFIT_DIAGNOSTIC completed, remains provisional'
exit 0
::requires 'SlamHarbourOtherCameraFit.cls'
::requires 'SlamHarbourBridgeVertical.cls'