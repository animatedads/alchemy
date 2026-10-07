numeric digits 30
m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
s=.RectangularTankSlosh2D~new(m,tank,24.5,0)
d=s~cflDiagnostic(9.80665)
if d~cellIndex<1 then exit 1
if d~depth<=0 | d~waveSpeed<=0 | d~stableTimeStep<=0 then exit 1
if abs(d~stableTimeStep-s~maxStableTimeStep(9.80665))>1E-20 then exit 1
say 'PHYSICS FREE SURFACE CFL DIAGNOSTIC: OK cell=' d~cellIndex 'h=' d~depth 'u=' d~velocityX 'c=' d~waveSpeed 'dt=' d~stableTimeStep
::requires 'FreeSurfaceFluids2D.cls'
::requires 'Fluids.cls'
