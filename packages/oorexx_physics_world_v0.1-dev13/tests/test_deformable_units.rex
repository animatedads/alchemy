numeric digits 50
ctx=.Maths~defaultContext

/* Shared Units can express dimensions Physics does not privately catalogue. */
area=.Units~q(1,.Units~centimetre)*.Units~q(1,.Units~centimetre)
density=.Units~q(7850,.Units~kilogram) / -
        (.Units~q(1,.Units~metre)*.Units~q(1,.Units~metre)*.Units~q(1,.Units~metre))
yieldStrain=.Units~q('0.125',.Units~percent)
fractureStrain=.Units~q(18,.Units~percent)
damping=.Units~q(2000000,.Units~pascal*.Units~second)
plasticFlow=.Units~q(100,.Units~percent)

mat=.MechanicalMaterial~new('typed-steel',density,.Units~q(200000000000,.Units~pascal), -
                            yieldStrain,fractureStrain,damping,plasticFlow)
call near mat~density,7850,'typed density canonicalisation'
call near mat~yieldStrain,'0.00125','percent yield strain canonicalisation'
call near mat~youngModulusQuantity~in(.Units~pascal),200000000000,'Young modulus quantity'

body=.DeformableBody~bar('typed-bar',2,.Units~q(100,.Units~centimetre), -
                         .Units~q(2,.Units~kilogram),area,mat,.MathVector3~new(0,0,0,ctx))
call near body~massQuantity~in(.Units~kilogram),2,'typed bar mass'
ns=body~nodes
call near (ns[2]~position-ns[1]~position)~norm,1,'typed bar length'
call near body~links[1]~areaQuantity~canonicalValue,'0.0001','typed area canonicalisation'

/* A real Maths vector can itself be the payload of a typed unit quantity. */
ns[2]~velocity=.Units~q(.MathVector3~new(1,0,0,ctx),.Units~metrePerSecond)~canonicalValue
call near ns[2]~velocityQuantity~canonicalValue~x,1,'typed vector velocity'

g=.Units~q(.MathVector3~new(0,'-9.80665',0,ctx),.Units~metrePerSecondSquared)
solver=.DeformableSolver~new(g)
solver~addBody(body)
solver~step(.Units~q(1,.Units~millisecond))
ledger=solver~energyLedger
if \ledger~totalQuantity~isA(.UnitQuantity) then do; say 'FAIL energy ledger quantity type'; exit 1; end
if \ledger~totalQuantity~dimension~compatible(.Units~joule~dimension) then do; say 'FAIL energy ledger dimension'; exit 1; end

say 'PHYSICS DEFORMABLE SHARED UNITS: OK'
exit 0

near: procedure
  use arg actual,expected,label
  if abs(actual-expected) > '0.000000000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
  return

::requires 'Deformable.cls'
