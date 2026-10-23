numeric digits 16
call test
say 'PASS: EWMA noise estimator, Wiener, subtraction, checkpoint, defensive copies'
exit 0
::routine test
 t=.AudioSpectralNoiseTracker~new(0.5,0.01)
 n=t~advance(.array~of(2,4),1)
 if n[1]<>2 then raise syntax 93.900 array('noise initialization')
 n[1]=100
 if t~estimate[1]<>2 then raise syntax 93.900 array('defensive estimate')
 s=t~snapshot
 n=t~advance(.array~of(4,2),1)
 if n[1]<>3 | n[2]<>3 then raise syntax 93.900 array('EWMA update')
 t~restore(s)
 n=t~advance(.array~of(4,2),1)
 if n[1]<>3 | n[2]<>3 then raise syntax 93.900 array('snapshot replay')
 n=t~advance(.array~of(100,100),0)
 if n[1]<>3 then raise syntax 93.900 array('noise-only gate')
 w=.AudioWienerGain~new(0.05)
 g=w~gains(.array~of(10,2,0),.array~of(2,4,0))
 if abs(g[1]-0.8)>0.000001 then raise syntax 93.900 array('Wiener power ratio')
 if g[2]<>0.05 | g[3]<>0.05 then raise syntax 93.900 array('Wiener floor')
 sub=.AudioSpectralSubtractionGain~new(1,0.1)
 g=sub~gains(.array~of(4,1),.array~of(3,4))
 if abs(g[1]-0.5)>0.000001 then raise syntax 93.900 array('spectral subtraction sqrt')
 if g[2]<>0.1 then raise syntax 93.900 array('subtraction floor')
 r=.AudioSpectralModelRegistry~new
 if r~names~items<>3 then raise syntax 93.900 array('registry')
::requires 'AudioSpectralModels.cls'
