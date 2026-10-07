numeric digits 30
m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
s=.RectangularTankSlosh2D~new(m,tank,24.5,0)
stable=s~maxStableTimeStep(9.80665)
requested=stable*3
o=s~advanceCfl(requested,0,0,9.80665,0.9,20)
if o~substepCount<=1 then exit 1
if abs(s~time-requested)>1E-20 then exit 1
if abs(s~currentVolume-24.5)>1E-6 then exit 1
say 'PHYSICS FREE SURFACE CFL SUBCYCLE: OK steps='o~substepCount 'minDt='o~minimumSubstep 'time='s~time
::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fluids.cls'
