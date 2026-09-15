parse arg root .
w=1304; h=734
rp=root||'/tests/tp00000_reference.gray'; op=root||'/tests/tp00000_occluded.gray'
r=charin(rp,1,w*h); call stream rp,'C','CLOSE'; o=charin(op,1,w*h); call stream op,'C','CLOSE'
c=.FDDoorMicroMotionConfig~tp00000Night; m=.FDNightDoorGeometryModel~new(c); fp=m~calibrateFingerprint(r,w,h,w)
if fp==.nil then call fail 'reference fingerprint'
a=m~locateDoor(o,w,h,w,fp)
if a==.nil then do; say 'PASS occluded door not admitted'; exit 0; end
/* A false location far from the original door must also fail this qualification. */
if abs(a~frameX-fp~frameX)>40 then do; say 'PASS occluded door rejected by geometry displacement frame_x='a~frameX; exit 0; end
call fail 'occluded door unexpectedly admitted near reference frame_x='||a~frameX
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotion.cls'
