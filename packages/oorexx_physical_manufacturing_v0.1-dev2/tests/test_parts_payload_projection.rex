call rxfuncadd 'SysLoadFuncs','rexxutil','SysLoadFuncs'; call SysLoadFuncs
carDef=.PartDefinition~new('BED-CARRIAGE','MACHINE_CARRIAGE','Finite moving bed carriage')
partDef=.PartDefinition~new('PRINT-TOWER','WORKPIECE','Growing printed workpiece')
car=.MachinePartFactory~project(carDef,'bed-1',1.0,0.20,0.20,0.03,'CARRIAGE')
light=.MachinePartFactory~project(partDef,'tower-light',0.05,0.03,0.03,0.05,'PAYLOAD')
heavy=.MachinePartFactory~project(partDef,'tower-heavy',0.50,0.03,0.03,0.20,'PAYLOAD')
a=.MachinePartFactory~movingAxisExperiment(car,.array~of(light),800,45,80)
b=.MachinePartFactory~movingAxisExperiment(car,.array~of(heavy),800,45,80)
a~command(0.05); b~command(0.05)
a~runFor(0.02,0.001); b~runFor(0.02,0.001)
if a~servo~position <= b~servo~position then raise syntax 93.900 array('lighter projected payload must accelerate farther under identical command')
if light~partId <> 'PRINT-TOWER' then raise syntax 93.900 array('catalogue identity was not retained')
say 'PHYSICAL MANUFACTURING PARTS PAYLOAD PROJECTION: OK'
::requires 'MachineDynamics.cls'
::requires 'PartsCatalog.cls'
