numeric digits 30
ctx=.Maths~defaultContext
freq=.array~of(125,250,500,1000,2000,4000)
wood=.AcousticBuildingMaterialFactory~solidWoodDoor(freq)
block=.AcousticBuildingMaterialFactory~breezeBlockWall(freq)

if wood~responseAt(1000)~pressureTransmission<=0 then exit 1
if block~responseAt(1000)~pressureTransmission<=0 then exit 1
if block~responseAt(1000)~pressureTransmission>=wood~responseAt(1000)~pressureTransmission then do
  say 'FAIL expected reference breeze block to transmit less than reference wood door at 1 kHz'
  exit 1
end

a=.MathVector3~new(0,0,0,ctx)
b=.MathVector3~new(4,0,0,ctx)
panel=.AcousticVerticalPanel~new(a,b,0,3)
p=.MathVector3~new(2,-1,1.5,ctx)
q=.MathVector3~new(2,1,1.5,ctx)
h=panel~segmentHit(p,q)
if h==.nil then do;say 'FAIL expected vertical-panel segment hit';exit 1;end
if abs(h~point~x-2)>1E-12 | abs(h~point~y)>1E-12 then exit 1

world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
solver=.AcousticImpulseResponseSolver~new(world)
solver~addSurface(.AcousticSpectralSurface~new('wood-door',panel,wood))
e=.AcousticEmissionSpectrum~new
do f over freq;e~addBand(.AcousticEmissionBand~new(f,0.001));end
receivers=.directory~new;receivers['R']=q
r=solver~solve(p,e,receivers,0.15)
first=r~receiver('R')~firstArrival
if first==.nil then do;say 'FAIL wood door should admit transmitted path';exit 1;end
if first~kind<>'DIRECT_OR_TRANSMITTED' then exit 1
if first~vertices~items<>3 then do;say 'FAIL expected source/door/receiver vertices';exit 1;end
if first~vertices[2]~name<>'wood-door' then exit 1

say 'PHYSICS BUILDING ACOUSTICS MATERIALS/PANEL: OK'
say 'wood 1kHz pressure transmission='wood~responseAt(1000)~pressureTransmission
say 'block 1kHz pressure transmission='block~responseAt(1000)~pressureTransmission
say 'door path delay='first~delay
::requires 'AcousticImpulseResponse.cls'
