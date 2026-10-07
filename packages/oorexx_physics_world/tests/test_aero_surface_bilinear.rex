numeric digits 30
x=.array~of(0,10); y=.array~of(0,1); rows=.array~new
rows~append(.array~of(0,.2)); rows~append(.array~of(1,1.4))
s=.AerodynamicCoefficientSurface2D~new(x,y,rows)
if s~evaluate(5,.5)<>.65 then exit 1
say 'PHYSICS AERO SURFACE BILINEAR: OK value=' s~evaluate(5,.5)
::requires 'AerodynamicCoefficientSurfaces.cls'
