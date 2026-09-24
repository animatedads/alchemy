numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.8,.5,.35,12,8)
slosh=.RectangularTankSlosh2D~new(water,tank,.08,.03)

do n=1 to 180
  slosh~step(.0015,-1.0,0)
end
com=slosh~centreOfMassLocal
if abs(com~z)>.00000001 then do; say 'FAIL x-only forcing broke z symmetry' com~z; exit 1; end
if abs(slosh~relativeMomentum~z)>.000001 then do; say 'FAIL x-only forcing created z momentum' slosh~relativeMomentum~z; exit 1; end
if com~x>=0 then do; say 'FAIL x-only forcing did not shift x COM'; exit 1; end
say 'PHYSICS FREE-SURFACE 2D SYMMETRY: OK xCOM='com~x 'zCOM='com~z
exit 0
::requires 'FreeSurfaceFluids2D.cls'
