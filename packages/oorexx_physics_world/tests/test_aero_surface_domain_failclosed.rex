rows=.array~of(.array~of(0,.2),.array~of(1,1.4))
s=.AerodynamicCoefficientSurface2D~new(.array~of(0,10),.array~of(0,1),rows)
signal on syntax name bad
v=s~evaluate(5,1.2)
exit 1
bad:
say 'PHYSICS AERO SURFACE DOMAIN FAIL-CLOSED: OK'
exit 0
::requires 'AerodynamicCoefficientSurfaces.cls'
