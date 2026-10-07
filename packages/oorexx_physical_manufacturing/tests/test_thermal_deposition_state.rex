m=.CommonMaterials~abs
p=.GrowingPrinterDynamics~create(0.4,1.0)
p~commandHead(0.01); p~runFor(0.02,0.001)
profile=.DepositionThermalProfile~new(500,380,300,0.15,0.65,1)
proc=.ThermalDepositionProcess~new(p,m,profile,293.15,12)
s=proc~depositSection('hot-1',0.002,0.02,0.001,0.02,5000,1,500)
if s~materialRef~id <> 'ABS-GENERIC' then raise syntax 98.900 array('material authority lost')
if s~temperatureKelvin <> 500 then raise syntax 98.900 array('initial thermal state wrong')
if abs(s~depositionCoordinate-p~depositionPosition)>0.000000001 then raise syntax 98.900 array('deposition coordinate not actual machine coordinate')
initial=s~temperatureKelvin
do i=1 to 500; proc~step(0.002); end
if s~temperatureKelvin>=initial then raise syntax 98.900 array('deposit did not cool')
say 'PHYSICAL MANUFACTURING THERMAL DEPOSITION STATE: OK'
::requires 'ThermalDeposition.cls'
