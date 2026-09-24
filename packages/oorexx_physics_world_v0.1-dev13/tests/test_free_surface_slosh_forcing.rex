numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(.Units~q(50,.Units~centimetre),.Units~q(20,.Units~centimetre),.Units~q(30,.Units~centimetre),64)
slosh=.RectangularTankSlosh1D~new(water,tank,.Units~q(15,.Units~litre),.Units~q(.08,.Units~hertz))
flat=slosh~centreOfMassLocal

do n=1 to 300
  slosh~step(.Units~q(.001,.Units~second),.Units~q(-2,.Units~metrePerSecondSquared))
end
forced=slosh~snapshot
if forced~surfaceRange<=.001 then do; say 'FAIL acceleration did not create free-surface deformation'; exit 1; end
if abs(forced~centreOfMassLocal~x-flat~x)<=.0001 then do; say 'FAIL acceleration did not move liquid centre of mass'; exit 1; end
if forced~kineticEnergy<=0 then do; say 'FAIL forced slosh has no kinetic energy'; exit 1; end
report=slosh~reactionReport
if abs(report~localForce~x)<=.0001 then do; say 'FAIL asymmetric free surface produced no wall reaction'; exit 1; end
say 'PHYSICS FREE-SURFACE FORCING: OK range='forced~surfaceRange 'xCOM='forced~centreOfMassLocal~x 'Fx='report~localForce~x
exit 0
::requires 'FreeSurfaceFluids.cls'
