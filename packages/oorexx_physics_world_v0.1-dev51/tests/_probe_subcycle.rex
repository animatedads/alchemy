numeric digits 30
m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
s=.RectangularTankSlosh2D~new(m,tank,24.5,0)
stable=s~maxStableTimeStep(9.80665); requested=stable*3
o=s~advanceCfl(requested,0,0,9.80665,0.9,20)
say 'steps' o~substepCount 'requested' requested 'time' s~time 'diff' abs(s~time-requested) 'volume' s~currentVolume 'vdiff' abs(s~currentVolume-24.5)
::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fluids.cls'
