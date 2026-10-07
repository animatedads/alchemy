call RxFuncAdd 'SysLoadFuncs','rexxutil','SysLoadFuncs'; call SysLoadFuncs
rig=.CartesianPrinterDynamics~create(0.35,0.8,0.05)
rig~commandHead(0.04); rig~commandPlate(-0.02); rig~runFor(0.12,0.001)
s=rig~samples[rig~samples~items]
commanded=0.06
if abs(s~nozzleToWorkpiece-commanded)<0.000001 then do; say 'FAIL: physical relative coordinate teleported to command'; exit 1; end
if abs(s~nozzleToWorkpiece-(s~headPosition-s~workpiecePosition))>0.000000001 then do; say 'FAIL: relative coordinate mismatch'; exit 1; end
say 'PHYSICAL PRINTER RELATIVE MOTION: OK'; exit 0
::requires '../rexx/MachineDynamics.cls'
