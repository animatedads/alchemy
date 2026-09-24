numeric digits 30
copper=.ThermalMaterialProperties~approximateCopper
coil=.ThermalNode~fromMass('voice-coil',.nil,.Units~q(.02,.Units~kilogram),copper,.Units~q(20,.Units~celsius))
thermal=.ThermalSolver~new; thermal~addNode(coil)
/* Explicit ambient convection; this coefficient is model input, not inferred. */
convection=.ThermalConvectionBoundary~new('coil-to-air',coil,.Units~q(20,.Units~celsius),.Units~q(12,.Units~watt/(.Units~squareMetre*.Units~deltaKelvin)),.Units~q(.004,.Units~squareMetre))
thermal~addConvectionBoundary(convection)
/* Rexx-tronics (or another electrical authority) has explicitly identified 2 W as heat. */
dt=.1; duration=30; steps=(duration/dt)~trunc
do i=1 to steps
  heat=.ThermalPowerObservation~new(thermal~timeQuantity,.Units~q(2,.Units~watt),'explicit winding dissipation','Rexx-tronics','component power evidence')
  coil~acceptPower(heat)
  thermal~step(.Units~q(dt,.Units~second))
end
say 'coil temperature after' duration 's:' coil~temperatureIn(.Units~celsius) 'degC'
say 'stored power observations:' coil~powerObservations~items
::requires 'Thermal.cls'
