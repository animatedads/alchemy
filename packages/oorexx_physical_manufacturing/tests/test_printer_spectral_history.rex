call RxFuncAdd 'SysLoadFuncs','rexxutil','SysLoadFuncs'; call SysLoadFuncs
rig=.CartesianPrinterDynamics~create(0.35,0.8,0.08,0.12,300,2)
rig~commandPlate(0.04); rig~runFor(0.04,0.002)
h=rig~relativeHistory
if h~count<15 then do; say 'FAIL: insufficient retained history'; exit 1; end
if h~rms<=0 then do; say 'FAIL: no physical relative-motion evidence'; exit 1; end
obs=h~component(10)
if obs~sampleCount<>h~count then do; say 'FAIL: spectral evidence sample count'; exit 1; end
say 'PHYSICAL PRINTER SPECTRAL EVIDENCE: OK'; exit 0
::requires '../rexx/MachineDynamics.cls'
