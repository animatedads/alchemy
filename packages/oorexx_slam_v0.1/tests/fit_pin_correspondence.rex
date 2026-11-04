/* Rerun actual photo with four alternative individual roof correspondences.
   The fitted result is diagnostic; no 3D camera result is accepted. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
c=.HarbourPinCorrespondence~new
parse arg iter
if iter=='' then iter=20
r=c~compare(iter)
say 'PAIR  CHI2  HEIGHT_ASL  HFOV  ARCH_HOLDOUT_PX  BOUNDARY  STATUS'
do item over r
  p=item['POSE']
  say item['SOUTH']||'/'||item['NORTH'] format(item['CHI2'],3,3) format(p[3],3,2) format(item['FOV_DEG'],2,2) format(item['ARCH_HOLDOUT_PX'],4,1) item['BOUNDARY_REACHED'] item['STATUS']
end
say 'PHOTO_FIT_ADMISSION=BLOCKED; source screenshot pylon roof interiors are unsurveyed and image points provisional'
::requires 'SlamHarbourPinCorrespondence.cls'