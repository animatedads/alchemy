rig=.GrowingPrinterDynamics~create(0.35,1.2)
rig~addSection('s1',0.05,0.03,0.02,0.03,900,5,0,'ABS-GENERIC')
rig~addSection('s2',0.05,0.03,0.02,0.03,700,4,0.01,'ABS-GENERIC')
w=rig~workpiece
if abs(w~totalMass-0.10)>1e-10 then raise syntax 93.900 array('mass not conserved')
if w~centreOfMass~y<=0 then raise syntax 93.900 array('invalid centre of mass')
if w~lateralInertiaAboutCentre<=0 then raise syntax 93.900 array('invalid inertia evidence')
if w~sections[2]~materialRef<>'ABS-GENERIC' then raise syntax 93.900 array('material identity lost')
say 'PHYSICAL MANUFACTURING GROWTH MASS PROPERTIES: OK'
exit
::requires '../rexx/GrowingWorkpiece.cls'
