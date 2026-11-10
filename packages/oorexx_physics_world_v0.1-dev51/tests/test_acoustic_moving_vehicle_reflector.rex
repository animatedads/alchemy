numeric digits 20
ctx=.Maths~defaultContext
freq=.array~of(125,1000,4000)
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
medium=world~ambientAcoustic
source=.MathVector3~new(0,0,4.8,ctx)
receiver=.MathVector3~new(9,1,4.8,ctx)
receivers=.directory~new;receivers['R']=receiver
em=.AcousticEmissionSpectrum~new
do f over freq
  w=.AcousticLevelMath~acousticPowerForSplAt1m(80+10*RxCalcLog10(1/3,30),medium)
  em~addBand(.AcousticEmissionBand~new(f,w))
end
/* Vehicle centre below the elevated source/receiver. Its finite vertical side is
   only 1.5 m high, so mirror specular reflection is impossible; diffuse finite-body
   scattering must still produce an admitted vehicle-reflected path. */
origin=.MathVector3~new(4,2,0,ctx);vel=.MathVector3~new('11.111111111111111',0,0,ctx)
car=.AcousticMovingVehicle~new('vehicle',origin,vel,4,1.5,0.5)
rigid=.AcousticSpectralMaterial~rigid(freq)
carSurface=.AcousticSpectralSurface~new('MOVING_VEHICLE',car~roadSidePanelAt(0),rigid)

base=.AcousticImpulseResponseSolver~new(world)
r0=base~solve(source,em,receivers,0.25)~receiver('R')

solver=.AcousticImpulseResponseSolver~new(world)
solver~addSurface(carSurface)
solver~addDiffuseReflector(.AcousticDiffuseReflector~new('MOVING_VEHICLE',carSurface,car~length*car~height,1))
r1=solver~solve(source,em,receivers,0.25)~receiver('R')
found=.false;shifted=.false
baseEnergy=r0~energyProxy;withEnergy=r1~energyProxy
do a over r1~arrivals
  if a~kind='DIFFUSE_REFLECTION' & a~evidence='MOVING_VEHICLE' then do
    found=.true
    verts=a~vertices
    fobs=.AcousticDoppler~movingReflectionObserved(1000,medium~soundSpeed,vel,source,verts[2]~point,receiver)
    if abs(fobs-1000)>0.001 then shifted=.true
  end
end
if found=.false then do;say 'FAIL moving vehicle did not create diffuse reflection';exit 1;end
if withEnergy<=baseEnergy then do;say 'FAIL vehicle reflection did not increase received energy';exit 1;end
if withEnergy/baseEnergy>10 then do;say 'FAIL diffuse vehicle scattering gain is implausibly large for bounded cross-section fixture';exit 1;end
if shifted=.false then do;say 'FAIL moving vehicle reflection did not carry Doppler shift';exit 1;end
say 'PASS moving vehicle reflector coupling'
say 'base_energy='baseEnergy
say 'with_vehicle_energy='withEnergy
say 'gain_ratio='withEnergy/baseEnergy
::requires 'AcousticMovingVehicle.cls'
