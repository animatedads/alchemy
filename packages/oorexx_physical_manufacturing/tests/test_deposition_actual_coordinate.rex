p=.GrowingPrinterDynamics~create(0.4,1.0)
p~addSection('base',0.02,0.03,0.01,0.03,800,2,0)
p~commandHead(0.02); p~commandPlate(-0.01)
p~runFor(0.08,0.001)
before=p~depositionPosition
profile=.DepositionThermalProfile~new(500,380,300,0.2,0.7,1)
proc=.ThermalDepositionProcess~new(p,.CommonMaterials~abs,profile)
s=proc~depositSection('next',0.001,0.02,0.001,0.02,500,1,480)
if abs(s~depositionCoordinate-before)>0.000000001 then raise syntax 98.900 array('commanded coordinate substituted for physical coordinate')
say 'PHYSICAL MANUFACTURING ACTUAL DEPOSITION COORDINATE: OK'
::requires 'ThermalDeposition.cls'
