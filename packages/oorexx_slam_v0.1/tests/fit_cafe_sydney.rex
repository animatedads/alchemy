/* Two fits: bridge-only and bridge + explicitly provisional Cahill edge.
 * Calibration uses the ACTUAL 1536x862 Cafe Sydney original photo.
 * This is an automated numerical fit of provisionally measured image points.
 * It is NOT autonomous visual landmark detection and not a survey.
 */
numeric digits 20
call RxFuncAdd 'MathLoadFuncs','rxmath','MathLoadFuncs'
call MathLoadFuncs
f=.HarbourPerspectiveFit~new
base=f~initialCamera
obs=.array~new
/* Pixel centres estimated by inspecting 1000066577.jpg. Each has ~6px
   observation uncertainty plus unmodelled pylon/deck geometry error. */
obs~append(.array~of('S_TOP',122,278,6))
obs~append(.array~of('N_TOP',770,314,6))
obs~append(.array~of('S_DECK',122,379,6))
obs~append(.array~of('N_DECK',770,390,6))
r=f~fit(obs,base)
rv=f~report('Cafe Sydney: bridge only, 4 features',r,obs)
parse arg outdir
if outdir=='' then outdir='.'
rv=f~renderOverlay(outdir||'/bridge_only_overlay.svg',r['POSE'],obs,'BRIDGE ONLY: 4 landmarks; roof/height not verified')
say 'HOLDOUT arch crown: image ~447,190; model midpoint is ONLY indicative.'
arch=f~project(f~world('ARCH_CROWN'),r['POSE'])
say 'HOLDOUT crown model' format(arch[1],5,1) format(arch[2],5,1) 'offset from image' format(arch[1]-447,4,1) format(arch[2]-190,4,1)
say '-----'
/* NOT surveyed: the visible lower-image edge could be terrace railing,
   a station face or Cahill. Treat this separately, not as confirmed fact. */
obs2=obs~copy
obs2~append(.array~of('PROVISIONAL_CAHILL_EDGE',500,736,15))
r2=f~fit(obs2,base)
rv=f~report('Cafe Sydney: bridge + HYPOTHETICAL Cahill image edge',r2,obs2)
rv=f~renderOverlay(outdir||'/bridge_plus_cahill_overlay.svg',r2['POSE'],obs2,'BRIDGE + presumed Cahill edge: conditional fit')
say 'CAUTION: difference in fitted Z demonstrates datum / correspondence sensitivity.'
exit 0
::requires 'SlamHarbourPerspectiveFit.cls'