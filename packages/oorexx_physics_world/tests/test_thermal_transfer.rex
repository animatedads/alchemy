numeric digits 30
cap=.Units~q(100,(.Units~joule/.Units~deltaKelvin))
a=.ThermalNode~new('a',.Units~q(300,.Units~kelvin),cap)
b=.ThermalNode~new('b',.Units~q(320,.Units~kelvin),cap)
path=.ThermalConductionPath~new('link',a,b,.Units~q(10,(.Units~watt/.Units~deltaKelvin)))
solver=.ThermalSolver~new
solver~addNode(a); solver~addNode(b); solver~addConductionPath(path)
call near path~heatFlowToA,200,'conductive heat flow'
solver~step(.Units~q(1,.Units~second))
call near a~temperatureKelvin,302,'cold node warms'
call near b~temperatureKelvin,318,'hot node cools'
call near a~temperatureKelvin+b~temperatureKelvin,620,'closed pair energy balance via equal heat capacities'

c=.ThermalNode~new('convective',.Units~q(310,.Units~kelvin),cap)
conv=.ThermalConvectionBoundary~new('air',c,.Units~q(300,.Units~kelvin),.Units~q(10,(.Units~watt/(.Units~squareMetre*.Units~deltaKelvin))),.Units~q(2,.Units~squareMetre))
solver2=.ThermalSolver~new; solver2~addNode(c); solver2~addConvectionBoundary(conv)
call near conv~heatFlowToNode,-200,'convective cooling power'
solver2~step(.Units~q(.5,.Units~second))
call near c~temperatureKelvin,309,'convective cooling temperature'

r=.ThermalNode~new('radiative',.Units~q(400,.Units~kelvin),cap)
rad=.ThermalRadiationBoundary~new('room',r,.Units~q(300,.Units~kelvin),.Units~q(.8,.Units~one),.Units~q(1,.Units~squareMetre))
if rad~heatFlowToNode>=0 then do; say 'FAIL: hotter body should radiatively cool'; exit 1; end
say 'PHYSICS THERMAL TRANSFER: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    exit 1
  end
return
::requires 'Thermal.cls'
