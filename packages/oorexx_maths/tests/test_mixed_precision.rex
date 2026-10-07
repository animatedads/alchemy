numeric digits 50
failures=0

scheme=.MathQuantizationScheme~nf4(64,'BFLOAT16')
plan=.Maths~mixedPrecision(scheme,4096,'FLOAT32')
call check plan~defaultScheme~name='NF4','mixed-precision plan retains default quantization scheme'
call check plan~highPrecisionType~name='FLOAT32','mixed-precision plan retains high-precision island dtype'
call check \plan~shouldQuantize(4095),'mixed-precision policy keeps small tensors high precision by default'
call check plan~shouldQuantize(4096),'mixed-precision policy permits quantization at configured size threshold'
plan~protect('BIAS')
call check \plan~shouldQuantize(100000,'BIAS'),'protected semantic role remains high precision'
call check \plan~shouldQuantize(100000,'WEIGHTS',.true),'exact mathematical values are preserved by default'
call check plan~shouldQuantize(100000,'WEIGHTS',.false),'large approximate weights can follow quantized default path'
plan~outliers(6)
call check plan~outlierThreshold=6,'mixed-precision plan retains explicit outlier threshold'
call check plan~canonical~pos('minElements=4096')>0 & plan~canonical~pos('BIAS')>0,'mixed-precision plan is canonically serializable with protected roles'

if failures=0 then do; say 'PASS oorexx_maths mixed precision 9 assertions'; exit 0; end
say 'FAIL oorexx_maths mixed precision failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
