parse arg root .
if root='' then root='.'
width=1304; height=734; lineSize=1304
refPath=root||'/tests/tp00000_reference.gray'
shiftPath=root||'/tests/tp00000_shifted.gray'
ref=charin(refPath,1,width*height); call stream refPath,'C','CLOSE'
shift=charin(shiftPath,1,width*height); call stream shiftPath,'C','CLOSE'
if ref~length<>width*height then call fail 'reference bytes'
if shift~length<>width*height then call fail 'shift bytes'
cfg=.FDDoorMicroMotionConfig~tp00000Night
model=.FDNightDoorGeometryModel~new(cfg)
fp=model~calibrateFingerprint(ref,width,height,lineSize)
if fp==.nil then call fail 'fingerprint not calibrated'
if fp~panelX>=fp~doorX | fp~doorX>=fp~frameX then call fail 'fingerprint edge ordering'
if fp~frameX<300 | fp~frameX>500 then call fail 'reference frame edge outside expected broad region:' fp~frameX
anchor=model~locateDoor(ref,width,height,lineSize,fp)
if anchor==.nil then call fail 'reference door not located'
if abs(anchor~frameX-fp~frameX)>4 then call fail 'reference locate moved frame edge too far:' anchor~frameX fp~frameX
moved=model~locateDoor(shift,width,height,lineSize,fp)
if moved==.nil then call fail 'shifted door not reacquired'
shiftPx=moved~frameX-anchor~frameX
if shiftPx<72 | shiftPx>88 then call fail 'shifted door x displacement wrong:' shiftPx
say 'PASS night locator reference_frame_x='||format(anchor~frameX,,3)||' shifted_frame_x='||format(moved~frameX,,3)||' shift_px='||format(shiftPx,,3)||' fp_score='||format(fp~score,,3)
exit 0
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
