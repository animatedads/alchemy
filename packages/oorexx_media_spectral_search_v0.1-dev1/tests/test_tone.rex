parse arg bridge folder
if bridge='' | folder='' then exit 2
native=.foreign~load(bridge)
rc=native~dense_f32(folder||'/tone.f32',folder||'/dense.f32',folder||'/receipt.tsv',8000,512,128)
if rc<>0 then raise syntax 88.900 array('synthetic dense transform failed',native~last_error)
rules=.array~new
rules~append(.MediaSpectrumRule~new(100,2000,10))
map=.MediaDenseSpectrumMap~new(folder||'/dense.f32',folder||'/receipt.tsv','','SYNTHETIC',0,1000,8000,8000,512,128,59,rules,bridge)
peak=map~rawDb(10,64)
weighted=map~weightedDb(10,64)
if abs(peak-(-6.0206))>0.1 then raise syntax 88.900 array('tone peak must be -6.0206 dBFS',peak)
if abs(weighted-peak-10)>0.001 then raise syntax 88.900 array('reversible view gain must be +10 dB',weighted)
if map~frameCount<>59 | map~binCount<>257 then raise syntax 88.900 array('dense map shape wrong')
say 'PASS synthetic FFT peak='||peak 'weighted='||weighted
exit 0
::requires 'MediaSpectralSearch.cls'
