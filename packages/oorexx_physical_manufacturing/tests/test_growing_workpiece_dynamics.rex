/* Equal manufactured mass, different vertical distribution/compliance. */
short=.GrowingPrinterDynamics~create(0.35,1.2)
short~addSection('compact',0.12,0.04,0.02,0.04,1800,8)
tall=.GrowingPrinterDynamics~create(0.35,1.2)
do i=1 to 6; tall~addSection('t'||i,0.02,0.02,0.02,0.02,300,1); end
short~commandPlate(0.03); tall~commandPlate(0.03)
short~runFor(0.10,0.001); tall~runFor(0.10,0.001)
if abs(short~workpiece~totalMass-tall~workpiece~totalMass)>1e-10 then raise syntax 93.900 array('fixture masses differ')
if abs(short~depositionPosition-tall~depositionPosition)<1e-7 then raise syntax 93.900 array('geometry/compliance did not change deposition response')
if tall~workpiece~lateralInertiaAboutCentre<=short~workpiece~lateralInertiaAboutCentre then raise syntax 93.900 array('tall stack inertia should exceed compact stack')
say 'PHYSICAL MANUFACTURING GROWTH DYNAMICS: OK'
exit
::requires '../rexx/GrowingWorkpiece.cls'
