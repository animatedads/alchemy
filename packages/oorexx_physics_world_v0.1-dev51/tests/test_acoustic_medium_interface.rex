numeric digits 30
air=.AcousticMedium~air
water=.AcousticMedium~water
if air~soundSpeed>=water~soundSpeed then do; say 'FAIL expected sound faster in development water model'; exit 1; end
if air~impedance>=water~impedance then do; say 'FAIL expected water impedance > air'; exit 1; end
x=.AcousticInterface~normalIncidence(air,water)
if x['intensityReflection']<'0.998' then do; say 'FAIL expected strong air-water intensity reflection' x['intensityReflection']; exit 1; end
call near x['intensityReflection']+x['intensityTransmission'],1,'interface energy split','0.0000001'
call near air~wavelength(343.2),1,'343.2 Hz wavelength in air','0.000000001'
rval=x['intensityReflection']; say 'PHYSICS ACOUSTICS MEDIUM + INTERFACE: OK R=' rval
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
