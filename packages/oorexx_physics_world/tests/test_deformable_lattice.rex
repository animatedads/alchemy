ctx=.Maths~defaultContext
mat=.MechanicalMaterial~rubber
origin=.MathVector3~new(0,0,0,ctx)
body=.DeformableBody~boxLattice('cube',2,2,2,'0.1',0.8,'0.0001',mat,origin,ctx)
if body~nodes~items<>8 then call fail 'expected 8 lattice nodes'
if body~links~items<>12 then call fail 'expected 12 axial links'
call near body~mass,'0.8','0.000000001','lattice mass'
call near body~centroid~x,'0.05','0.000000001','centroid x'
call near body~centroid~y,'0.05','0.000000001','centroid y'
call near body~centroid~z,'0.05','0.000000001','centroid z'
say 'PHYSICS DEFORMABLE 3D LATTICE: OK'
exit 0
near: procedure
  use arg actual,expected,tol,label
  if abs(actual-expected)>tol then do; say 'FAIL' label actual expected; exit 1; end
  return
fail: procedure
  use arg msg; say 'FAIL' msg; exit 1
::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
