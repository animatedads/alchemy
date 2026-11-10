call addpath
ctx=.Maths~defaultContext
z=.MathVector3~new(0,0,0,ctx)

/* Hooke-law qualification: 1 m bar, A=1e-4 m2, E=200 GPa, strain=5e-5 => 1000 N. */
mat=.MechanicalMaterial~new('test-steel',7850,'200000000000','0.00125','0.20',0,1)
a=.DeformableNode~new(z,1,,.true)
b=.DeformableNode~new(.MathVector3~new('1.00005',0,0,ctx),1)
link=.DeformableLink~new(a,b,'0.0001',mat,1)
link~apply
call near abs(b~force~x),1000,'0.00001','elastic force'
call near link~elasticEnergy,'0.025','0.0000001','elastic energy'

/* Plastic qualification: 10% extension with 2% yield changes natural length. */
pmat=.MechanicalMaterial~new('plastic-test',1000,1000000,'0.02','0.30',0,1)
p1=.DeformableNode~new(z,1,,.true)
p2=.DeformableNode~new(.MathVector3~new('1.10',0,0,ctx),1)
plink=.DeformableLink~new(p1,p2,1,pmat,1)
plink~apply
call near plink~lastStrain,'0.02','0.00000001','yield-capped elastic strain'
if plink~restLength<=1 then call fail 'plastic rest length did not grow'
residual=plink~permanentStrain
if residual<=0 then call fail 'plastic residual strain missing'
if plink~plasticWork<=0 then call fail 'plastic work missing'

/* Fracture qualification. */
f2=.DeformableNode~new(.MathVector3~new('1.35',0,0,ctx),1)
flink=.DeformableLink~new(p1,f2,1,pmat,1)
flink~apply
if \flink~broken then call fail 'fracture threshold did not break link'

say 'PHYSICS DEFORMABLE ELASTIC + PLASTIC + FRACTURE: OK'
exit 0

addpath:
  return
near: procedure
  use arg actual,expected,tol,label
  if abs(actual-expected)>tol then do; say 'FAIL' label actual expected; exit 1; end
  return
fail: procedure
  use arg msg; say 'FAIL' msg; exit 1

::requires 'Deformable.cls'
::requires 'MathsBootstrap.cls'
