call RxFuncAdd 'SysLoadFuncs','rexxutil','SysLoadFuncs'; call SysLoadFuncs
stiff=.CartesianPrinterDynamics~create(0.35,0.8,0.12,0.15,10000,20)
soft=.CartesianPrinterDynamics~create(0.35,0.8,0.12,0.15,120,1)
do r over .array~of(stiff,soft); r~commandPlate(0.05); r~runFor(0.03,0.002); end
ss=stiff~samples[stiff~samples~items]; so=soft~samples[soft~samples~items]
stiffLag=abs(ss~workpiecePosition-ss~platePosition); softLag=abs(so~workpiecePosition-so~platePosition)
if softLag<=stiffLag then do; say 'FAIL: compliant tall payload did not lag plate more'; say stiffLag softLag; exit 1; end
say 'PHYSICAL PRINTER PAYLOAD COMPLIANCE: OK'; exit 0
::requires '../rexx/MachineDynamics.cls'
