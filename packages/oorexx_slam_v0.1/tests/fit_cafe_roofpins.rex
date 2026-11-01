/* Distinguish qualified pylon horizontal registration from unreliable image
 * correspondences/foreground geometry. Photo 1000066577.jpg is NOT embedded.
 * Bridge centres cannot be equated to facade corners in a photograph.
 * This is a diagnostic provisional fitting pass, not a camera pose claim. */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
parse arg outdir
if outdir=='' then outdir='.'
f=.HarbourPerspectiveFit~new
q=.HarbourBridgeRoofPins~apply(f~model~scene)
base=f~initialCamera
obs=.array~new
obs~append(.array~of('S_TOP',122,278,14))
obs~append(.array~of('N_TOP',770,314,14))
obs~append(.array~of('S_DECK',122,379,14))
obs~append(.array~of('N_DECK',770,390,14))
fit=f~fit(obs,base)
rv=f~report('CAFE SYDNEY / FOUR ROOF PINS / BRIDGE ONLY - CONFLICT CHECK',fit,obs)
rv=f~renderOverlay(outdir||'/cafe_roofpins_bridge_only.svg',fit['POSE'],obs,'User roof pin geometry; bridge image observations still approximate')
say '----'
obs2=obs~copy
obs2~append(.array~of('PROVISIONAL_CAHILL_EDGE',500,736,15))
fit2=f~fit(obs2,base)
rv=f~report('CAFE SYDNEY / FOUR ROOF PINS / BRIDGE PLUS PROVISIONAL FOREGROUND',fit2,obs2)
rv=f~renderOverlay(outdir||'/cafe_roofpins_plus_cahill.svg',fit2['POSE'],obs2,'Provisional image-to-Cahill association; not accepted calibrated camera')
say 'PHOTO_FIT_ADMISSION=BLOCKED_UNVERIFIED_IMAGE_LANDMARK_CORRESPONDENCES'
exit 0
::requires 'SlamHarbourPerspectiveFit.cls'
::requires 'SlamHarbourRoofPins.cls'