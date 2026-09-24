d=.PartDefinition~new('P-1','WORKPIECE','catalogue-owned identity')
p=.MachinePartFactory~project(d,'instance-7',0.25,0.1,0.1,0.1)
if p~definition \== d then raise syntax 93.900 array('projection must retain original catalogue definition')
if p~partId <> d~id | p~family <> d~family then raise syntax 93.900 array('projection identity drift')
say 'PHYSICAL MANUFACTURING PARTS AUTHORITY BOUNDARY: OK'
::requires 'MachineDynamics.cls'
::requires 'PartsCatalog.cls'
