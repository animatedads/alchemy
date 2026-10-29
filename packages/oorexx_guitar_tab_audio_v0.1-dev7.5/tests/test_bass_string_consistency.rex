numeric digits 30
models=.BassInstrumentFactory~standardStringSet
maxErr=0
do m over models
  f=(1/(2*m~scaleLength))*RxCalcSqrt(m~tension/m~linearDensity)
  err=abs(f-m~openFrequency)
  if err>maxErr then maxErr=err
  if err>0.000001 then do; say 'FAIL string consistency f='f 'declared='m~openFrequency; exit 1; end
end
say 'BASS STRING PHYSICAL CONSISTENCY: OK maxHzError='maxErr
::requires 'rxmath' LIBRARY
::requires 'BassGuitarMechanics.cls'
