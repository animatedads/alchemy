/* A half-metre rectangular tank receives a short lateral acceleration pulse.
   The surface, relative liquid momentum and centre of mass evolve from the
   shallow-water equations; no slosh/alignment factor is supplied. */
numeric digits 20
water=.FluidMedium~water20C
tank=.RectangularTankGeometry~new(.Units~q(50,.Units~centimetre),.Units~q(20,.Units~centimetre),.Units~q(30,.Units~centimetre),64)
slosh=.RectangularTankSlosh1D~new(water,tank,.Units~q(15,.Units~litre),.Units~q(.06,.Units~hertz))

say 'mean depth:' slosh~meanDepthQuantity~in(.Units~centimetre) 'cm'
say 'shallow-water fundamental period:' slosh~fundamentalPeriod 's'
say
say 'time(s)   left(cm)   right(cm)   xCOM(cm)   kinetic(J)'

do n=1 to 1500
  accel=0
  if n<=300 then accel=-2
  slosh~step(.001,accel)
  if n//100=0 then do
    left=slosh~depthAtCell(1)*100
    right=slosh~depthAtCell(tank~cellCount)*100
    xcom=slosh~centreOfMassLocal~x*100
    say format(slosh~time,5,2) format(left,10,4) format(right,11,4) format(xcom,10,4) format(slosh~kineticEnergy,12,7)
  end
end
::requires 'FreeSurfaceFluids.cls'
