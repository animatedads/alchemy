call test
exit 0
::routine test
m=.AudioLMS~new(2,0.5)
a=m~advance(1,1)
if a[1]<>1 then raise syntax 93.900 array('initial LMS error')
s=m~snapshot
b=m~advance(2,1)
m~restore(s)
c=m~advance(2,1)
if abs(b[1]-c[1])>0.00000001 then raise syntax 93.900 array('LMS checkpoint replay')
f=.AudioSpectralFlux~new
if f~advance(.array~of(1,2))<>0 then raise syntax 93.900 array('flux first frame')
if f~advance(.array~of(2,1))<>1 then raise syntax 93.900 array('flux positive change')
z=.AudioZeroCrossing~new
if z~count(.array~of(-1,1,-1,1))<>3 then raise syntax 93.900 array('crossings')
r=.AudioModelRegistry~new
if r~names~items<>3 then raise syntax 93.900 array('registry')
say 'PASS: NLMS, flux, zero crossing, snapshot replay'
::requires 'AudioModels.cls'
