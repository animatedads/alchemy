/* Video-core hardening qualification: broad-field motion, photometric step,
   fingerprint compatibility and vertical shear fail-closed behaviour. */
parse arg root .
if root='' then root='.'
w=1304; h=734; lineSize=w
rp=root||'/tests/tp00000_reference.gray'
ref=charin(rp,1,w*h); call stream rp,'C','CLOSE'
if ref~length<>w*h then call fail 'reference bytes'

cfg=.FDDoorMicroMotionConfig~tp00000Night
model=.FDNightDoorGeometryModel~new(cfg)
fp=model~calibrateFingerprint(ref,w,h,lineSize)
if fp==.nil then call fail 'fingerprint calibration'
anchor=model~locateDoor(ref,w,h,lineSize,fp)
if anchor==.nil then call fail 'door locate'
geom=model~acquireTrackedGeometry(ref,w,h,lineSize,anchor)
if \model~validGeometry(geom) then call fail 'reference geometry'

/* Whole-frame one-pixel translation must be treated as camera motion. */
shifted=''
do y=0 to h-1
  row=ref~substr((y*w)+1,w)
  shifted=shifted||row~substr(1,1)||row~substr(1,w-1)
end
sig1=model~sceneMotionSignature(ref,w,h,lineSize,anchor~frameX)
sig2=model~trackSceneMotionSignature(shifted,w,h,lineSize,anchor~frameX+1,sig1)
motion=model~sceneMotionEstimate(sig1,sig2)
if \motion['CAMERA_MOTION'] then call fail 'whole-field 1px motion not detected dx='||motion['DX']||' dy='||motion['DY']||' matches='||motion['MATCHES']
if abs(motion['DX'])<0.65 | abs(motion['DX'])>1.35 then call fail 'whole-field dx='||motion['DX']

/* Moving only the F11/left field must not impersonate broad camera motion. */
local=''; split=500
do y=0 to h-1
  row=ref~substr((y*w)+1,w)
  left=row~substr(1,split)
  leftShift=left~substr(1,1)||left~substr(1,split-1)
  local=local||leftShift||row~substr(split+1)
end
sigLocal=model~trackSceneMotionSignature(local,w,h,lineSize,anchor~frameX+1,sig1)
localMotion=model~sceneMotionEstimate(sig1,sigLocal)
if localMotion['CAMERA_MOTION'] then call fail 'localized door-field change misclassified as camera motion dx='||localMotion['DX']||' dy='||localMotion['DY']

/* An IR gain/exposure step is a measurement-boundary event, not mechanical evidence. */
inTable=''; outTable=''
do i=0 to 255
  inTable=inTable||d2c(i)
  v=i+28; if v>255 then v=255
  outTable=outTable||d2c(v)
end
bright=translate(ref,outTable,inTable)
p1=model~photometricStats(ref,w,h,lineSize)
p2=model~photometricStats(bright,w,h,lineSize)
pt=model~photometricTransition(p1,p2)
if \pt['TRANSITION'] then call fail 'photometric transition not detected mean_step='||pt['MEAN_STEP']||' sigma_ratio='||pt['SIGMA_RATIO']

/* Geometry upper/lower locking must retain its shear signature. */
if \model~geometryShearConsistent(geom,geom) then call fail 'identical geometry rejected'
/* Three-height tracking is 2-of-3 authoritative after acquisition. */
two=.directory~new; do k over geom~allIndexes; two[k]=geom[k]; end
two['DOOR_UP']=.FDEdgeMeasurement~new(geom['DOOR_UP']~position,0,0,.false)
two['FRAME_UP']=.FDEdgeMeasurement~new(geom['FRAME_UP']~position,0,0,.false)
if \model~validGeometry(two) then call fail '2-of-3 vertical geometry rejected'
one=.directory~new; do k over two~allIndexes; one[k]=two[k]; end
one['DOOR_BOTTOM']=.FDEdgeMeasurement~new(geom['DOOR_BOTTOM']~position,0,0,.false)
one['FRAME_BOTTOM']=.FDEdgeMeasurement~new(geom['FRAME_BOTTOM']~position,0,0,.false)
if model~validGeometry(one) then call fail '1-of-3 vertical geometry admitted'
/* Camera/global translation moves frame and door together; residual stays quiet. */
moved=.directory~new; do k over geom~allIndexes; moved[k]=geom[k]; end
do suffix over .array~of('UP','LO','BOTTOM')
  fk='FRAME_'||suffix; dk='DOOR_'||suffix
  fe=geom[fk]; de=geom[dk]
  moved[fk]=.FDEdgeMeasurement~new(fe~position+1.0,fe~score,fe~signedScore,fe~valid)
  moved[dk]=.FDEdgeMeasurement~new(de~position+1.0,de~score,de~signedScore,de~valid)
end
fm=model~verticalCoherence(geom,moved,'FRAME',0.10,0.30)
dm=model~verticalCoherence(geom,moved,'DOOR_RESIDUAL',0.12,0.35)
if \fm['COHERENT'] | fm['AGREEMENT']<2 then call fail 'three-height frame coherence not detected'
if dm['COHERENT'] | dm['MAGNITUDE']>0.05 then call fail 'common-mode translation leaked into door residual'
/* A coherent half-pixel door-only residual at all valid heights is admitted. */
deflected=.directory~new; do k over moved~allIndexes; deflected[k]=moved[k]; end
do suffix over .array~of('UP','LO','BOTTOM')
  dk='DOOR_'||suffix; de=moved[dk]
  deflected[dk]=.FDEdgeMeasurement~new(de~position+0.50,de~score,de~signedScore,de~valid)
end
dm=model~verticalCoherence(moved,deflected,'DOOR_RESIDUAL',0.12,0.35)
if \dm['COHERENT'] | dm['AGREEMENT']<2 | dm['MAGNITUDE']<0.45 then call fail 'coherent door residual not detected'
bad=.directory~new
do k over geom~allIndexes; bad[k]=geom[k]; end
old=geom['DOOR_LO']
bad['DOOR_LO']=.FDEdgeMeasurement~new(old~position+3.0,old~score,old~signedScore,.true)
if model~geometryShearConsistent(geom,bad) then call fail '3px door shear change admitted'

if \model~fingerprintsCompatible(fp,fp) then call fail 'fingerprint self-compatibility'
sp=root||'/tests/tp00000_shifted.gray'
shiftFile=charin(sp,1,w*h); call stream sp,'C','CLOSE'
cfgWide=.FDDoorMicroMotionConfig~nightF11; modelWide=.FDNightDoorGeometryModel~new(cfgWide)
fpA=modelWide~calibrateFingerprint(ref,w,h,lineSize); fpB=modelWide~calibrateFingerprint(shiftFile,w,h,lineSize)
if fpA==.nil | fpB==.nil then call fail 'wide fingerprint confirmation fixtures'
if \modelWide~fingerprintsCompatible(fpA,fpB) then call fail 'relocated fingerprint compatibility rejected'

say 'PASS video hardening camera_dx='||format(motion['DX'],,3)||' matches='||motion['MATCHES']||' photo_step='||format(pt['MEAN_STEP'],,3)
exit 0

fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
