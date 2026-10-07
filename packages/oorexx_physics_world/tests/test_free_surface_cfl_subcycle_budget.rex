m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
s=.RectangularTankSlosh2D~new(m,tank,24.5,0)
signal on syntax name bad
o=s~advanceCfl(s~maxStableTimeStep(9.80665)*3,0,0,9.80665,0.9,1)
exit 1
bad:
say 'PHYSICS FREE SURFACE CFL SUBCYCLE BUDGET FAIL-CLOSED: OK'
exit 0
::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fluids.cls'
