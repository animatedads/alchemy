numeric digits 24
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new( -
    .Units~q(60,.Units~centimetre), -
    .Units~q(40,.Units~centimetre), -
    .Units~q(30,.Units~centimetre),12,8)
slosh=.RectangularTankSlosh2D~new(water,tank,.Units~q(36,.Units~litre),.05)

say '2-D tank slosh example'
say 'X natural period:' slosh~fundamentalPeriodX 's'
say 'Z natural period:' slosh~fundamentalPeriodZ 's'
say 'time(s)  xCOM(m)  zCOM(m)  range(m)'

do n=1 to 300
  /* A vessel acceleration of +1.5 X and -0.8 Z gives effective gravity
     components of -1.5 X and +0.8 Z in the vessel frame. */
  slosh~step(.0015,-1.5,.8)
  if n//50=0 then do
    c=slosh~centreOfMassLocal
    say slosh~time c~x c~z slosh~surfaceRange
  end
end
exit 0
::requires 'FreeSurfaceFluids2D.cls'
