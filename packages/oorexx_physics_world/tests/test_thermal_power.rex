numeric digits 30
copper=.ThermalMaterialProperties~approximateCopper
node=.ThermalNode~fromMass('copper-body',.nil,.Units~q(1,.Units~kilogram),copper,.Units~q(20,.Units~celsius))
solver=.ThermalSolver~new
solver~addNode(node)
obs=.ThermalPowerObservation~new(.Units~q(0,.Units~second),.Units~q(10,.Units~watt),'explicit electrical dissipation','resistor','Rexx-tronics power evidence')
node~acceptPower(obs)
solver~step(.Units~q(10,.Units~second))
expected=20+100/385
call near node~temperatureIn(.Units~celsius),expected,'10 W into 1 kg copper for 10 s','.000001'
call near node~heatCapacity,385,'mass-specific heat capacity'
if node~powerObservations~items<>1 then do; say 'FAIL: thermal power provenance lost'; exit 1; end
say 'PHYSICS THERMAL POWER: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Thermal.cls'
