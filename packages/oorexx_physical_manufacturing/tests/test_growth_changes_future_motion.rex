rig=.GrowingPrinterDynamics~create(0.35,1.2)
rig~addSection('base',0.04,0.03,0.02,0.03,700,3)
rig~commandPlate(0.025); rig~runFor(0.08,0.001)
before=rig~depositionPosition
/* Grow while preserving the machine/controller state. */
do i=1 to 4
  rig~addSection('grow'||i,0.02,0.02,0.02,0.02,350,1.5,0.001*i,'ABS-GENERIC')
end
rig~commandPlate(-0.025); rig~runFor(0.08,0.001)
after=rig~depositionPosition
if rig~workpiece~sectionCount<>5 then raise syntax 93.900 array('growth not retained')
if abs(after-before)<1e-7 then raise syntax 93.900 array('growth did not alter subsequent relative motion')
if rig~relativeHistory~count<100 then raise syntax 93.900 array('physical history not retained')
say 'PHYSICAL MANUFACTURING GROWTH CHANGES FUTURE MOTION: OK'
exit
::requires '../rexx/GrowingWorkpiece.cls'
