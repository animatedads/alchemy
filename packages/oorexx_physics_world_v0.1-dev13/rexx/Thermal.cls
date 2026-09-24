/* ooRexx Physics World v0.1-dev9
   First thermal solver over shared PhysicalWorld identity and shared Units.

   Scope: lumped thermal capacitance with explicit heat-power inputs, conductive
   links, convection boundaries and grey-body thermal radiation boundaries.
   Temperature is physical state; power does not disappear merely because its
   electrical or mechanical source has finished accounting for it.

   This is not yet a continuum heat-equation mesh, phase-change model, fluid
   convection solver or temperature-dependent material-property engine.
*/

::class ThermalUnitBoundary
::method scalar class
  use strict arg value,expectedDimension,label
  numeric digits 50
  if \value~isA(.UnitQuantity) then raise syntax 93.900 array(label 'must be a UnitQuantity')
  if \value~dimension~compatible(expectedDimension) then raise syntax 93.900 array(label 'has incompatible physical dimension')
  return value~canonicalValue+0
::method absoluteTemperature class
  use strict arg value,label='temperature'
  if \value~isA(.UnitQuantity) then raise syntax 93.900 array(label 'must be a UnitQuantity')
  if \value~isAbsoluteTemperature then raise syntax 93.900 array(label 'must be an absolute temperature quantity')
  t=value~canonicalValue+0
  if t<0 then raise syntax 88.900 array('absolute temperature >= 0 K',t)
  return t
::method heatCapacityUnit class; return .Units~joule/.Units~deltaKelvin
::method specificHeatUnit class; return .Units~joule/(.Units~kilogram*.Units~deltaKelvin)
::method conductivityUnit class; return .Units~watt/(.Units~metre*.Units~deltaKelvin)
::method conductanceUnit class; return .Units~watt/.Units~deltaKelvin
::method convectionCoefficientUnit class; return .Units~watt/(.Units~squareMetre*.Units~deltaKelvin)

::class ThermalMaterialProperties public
::method init
  expose _name _specificHeat _conductivity _emissivity
  use strict arg name,specificHeatCapacity,thermalConductivity,emissivity=.nil
  _name=name
  _specificHeat=.ThermalUnitBoundary~scalar(specificHeatCapacity,.ThermalUnitBoundary~specificHeatUnit~dimension,'specific heat capacity')
  _conductivity=.ThermalUnitBoundary~scalar(thermalConductivity,.ThermalUnitBoundary~conductivityUnit~dimension,'thermal conductivity')
  if _specificHeat<=0 then raise syntax 88.900 array('positive specific heat capacity',_specificHeat)
  if _conductivity<0 then raise syntax 88.900 array('non-negative thermal conductivity',_conductivity)
  if emissivity==.nil then _emissivity=.nil
  else do
    _emissivity=.ThermalUnitBoundary~scalar(emissivity,.UnitDimension~dimensionless,'thermal emissivity')
    if _emissivity<0 | _emissivity>1 then raise syntax 88.900 array('thermal emissivity in [0,1]',_emissivity)
  end
::method name; expose _name; return _name
::method specificHeatCapacity; expose _specificHeat; return _specificHeat
::method specificHeatCapacityQuantity; return .Units~q(self~specificHeatCapacity,.ThermalUnitBoundary~specificHeatUnit)
::method thermalConductivity; expose _conductivity; return _conductivity
::method thermalConductivityQuantity; return .Units~q(self~thermalConductivity,.ThermalUnitBoundary~conductivityUnit)
::method emissivity; expose _emissivity; return _emissivity
::method approximateCopper class
  return self~new('copper-approx',.Units~q(385,.ThermalUnitBoundary~specificHeatUnit),.Units~q(400,.ThermalUnitBoundary~conductivityUnit),.Units~q(.03,.Units~one))
::method approximateGlass class
  return self~new('glass-approx',.Units~q(840,.ThermalUnitBoundary~specificHeatUnit),.Units~q(1,.ThermalUnitBoundary~conductivityUnit),.Units~q(.9,.Units~one))

::class ThermalPowerObservation public
::method init
  expose _time _power _cause _source _evidence
  use strict arg timeQuantity,powerQuantity,cause='',source=.nil,evidence=.nil
  _time=.ThermalUnitBoundary~scalar(timeQuantity,.UnitDimension~time,'thermal power observation time')
  if _time<0 then raise syntax 88.900 array('non-negative thermal observation time',_time)
  _power=.ThermalUnitBoundary~scalar(powerQuantity,.Units~watt~dimension,'thermal power')
  _cause=cause; _source=source; _evidence=evidence
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method power; expose _power; return _power
::method powerQuantity; return .Units~q(self~power,.Units~watt)
::method cause; expose _cause; return _cause
::method source; expose _source; return _source
::method evidence; expose _evidence; return _evidence

::class ThermalNode public
::method init
  expose _name _body _temperature _heatCapacity _power _observations
  use strict arg name,temperatureQuantity,heatCapacityQuantity,body=.nil
  _name=name; _body=body
  _temperature=.ThermalUnitBoundary~absoluteTemperature(temperatureQuantity,'thermal node temperature')
  _heatCapacity=.ThermalUnitBoundary~scalar(heatCapacityQuantity,.ThermalUnitBoundary~heatCapacityUnit~dimension,'thermal heat capacity')
  if _heatCapacity<=0 then raise syntax 88.900 array('positive thermal heat capacity',_heatCapacity)
  _power=0; _observations=.array~new
::method fromMass class
  use strict arg name,body,massQuantity,material,temperatureQuantity
  mass=.ThermalUnitBoundary~scalar(massQuantity,.UnitDimension~mass,'thermal body mass')
  if mass<=0 then raise syntax 88.900 array('positive thermal body mass',mass)
  c=mass*material~specificHeatCapacity
  return self~new(name,temperatureQuantity,.Units~q(c,.ThermalUnitBoundary~heatCapacityUnit),body)
::method name; expose _name; return _name
::method body; expose _body; return _body
::method temperatureKelvin; expose _temperature; return _temperature
::method temperatureQuantity; return .Units~q(self~temperatureKelvin,.Units~kelvin)
::method temperatureIn
  use strict arg unit
  return self~temperatureQuantity~in(unit)
::method heatCapacity; expose _heatCapacity; return _heatCapacity
::method heatCapacityQuantity; return .Units~q(self~heatCapacity,.ThermalUnitBoundary~heatCapacityUnit)
::method pendingPower; expose _power; return _power
::method pendingPowerQuantity; return .Units~q(self~pendingPower,.Units~watt)
::method powerObservations; expose _observations; return _observations~copy
::method addPower
  expose _power
  use strict arg powerWatts
  _power=_power+powerWatts
  return self
::method acceptPower
  expose _observations
  use strict arg observation
  if \observation~isA(.ThermalPowerObservation) then raise syntax 93.900 array('ThermalPowerObservation required')
  self~addPower(observation~power)
  _observations~append(observation)
  return observation
::method integrate
  expose _temperature _power
  use strict arg dtSeconds
  if dtSeconds<=0 then raise syntax 88.900 array('positive thermal timestep',dtSeconds)
  _temperature=_temperature+(_power*dtSeconds/self~heatCapacity)
  if _temperature<0 then raise syntax 88.900 array('thermal integration produced temperature below absolute zero',_temperature)
  _power=0

::class ThermalConductionPath public
::method init
  expose _name _a _b _conductance
  use strict arg name,nodeA,nodeB,conductanceQuantity
  _name=name; _a=nodeA; _b=nodeB
  _conductance=.ThermalUnitBoundary~scalar(conductanceQuantity,.ThermalUnitBoundary~conductanceUnit~dimension,'thermal conductance')
  if _conductance<0 then raise syntax 88.900 array('non-negative thermal conductance',_conductance)
::method fromGeometry class
  use strict arg name,nodeA,nodeB,material,areaQuantity,lengthQuantity
  area=.ThermalUnitBoundary~scalar(areaQuantity,.Units~squareMetre~dimension,'conduction area')
  length=.ThermalUnitBoundary~scalar(lengthQuantity,.UnitDimension~length,'conduction length')
  if area<=0 | length<=0 then raise syntax 88.900 array('positive conduction area and length',area length)
  g=material~thermalConductivity*area/length
  return self~new(name,nodeA,nodeB,.Units~q(g,.ThermalUnitBoundary~conductanceUnit))
::method name; expose _name; return _name
::method nodeA; expose _a; return _a
::method nodeB; expose _b; return _b
::method conductance; expose _conductance; return _conductance
::method conductanceQuantity; return .Units~q(self~conductance,.ThermalUnitBoundary~conductanceUnit)
::method heatFlowToA; return self~conductance*(self~nodeB~temperatureKelvin-self~nodeA~temperatureKelvin)
::method heatFlowToAQuantity; return .Units~q(self~heatFlowToA,.Units~watt)
::method apply
  q=self~heatFlowToA
  self~nodeA~addPower(q); self~nodeB~addPower(-q)

::class ThermalConvectionBoundary public
::method init
  expose _name _node _ambient _coefficient _area
  use strict arg name,node,ambientTemperature,heatTransferCoefficient,areaQuantity
  _name=name; _node=node
  _ambient=.ThermalUnitBoundary~absoluteTemperature(ambientTemperature,'convection ambient temperature')
  _coefficient=.ThermalUnitBoundary~scalar(heatTransferCoefficient,.ThermalUnitBoundary~convectionCoefficientUnit~dimension,'convective heat-transfer coefficient')
  _area=.ThermalUnitBoundary~scalar(areaQuantity,.Units~squareMetre~dimension,'convective area')
  if _coefficient<0 | _area<=0 then raise syntax 88.900 array('non-negative convection coefficient and positive area',_coefficient _area)
::method name; expose _name; return _name
::method node; expose _node; return _node
::method ambientKelvin; expose _ambient; return _ambient
::method heatFlowToNode; return self~coefficient*self~area*(self~ambientKelvin-self~node~temperatureKelvin)
::method coefficient; expose _coefficient; return _coefficient
::method area; expose _area; return _area
::method apply; self~node~addPower(self~heatFlowToNode)

::class ThermalRadiationBoundary public
::method init
  expose _name _node _environment _emissivity _area
  use strict arg name,node,environmentTemperature,emissivity,areaQuantity
  _name=name; _node=node
  _environment=.ThermalUnitBoundary~absoluteTemperature(environmentTemperature,'radiative environment temperature')
  _emissivity=.ThermalUnitBoundary~scalar(emissivity,.UnitDimension~dimensionless,'thermal emissivity')
  _area=.ThermalUnitBoundary~scalar(areaQuantity,.Units~squareMetre~dimension,'radiating thermal area')
  if _emissivity<0 | _emissivity>1 then raise syntax 88.900 array('thermal emissivity in [0,1]',_emissivity)
  if _area<=0 then raise syntax 88.900 array('positive thermal radiation area',_area)
::method name; expose _name; return _name
::method node; expose _node; return _node
::method environmentKelvin; expose _environment; return _environment
::method emissivity; expose _emissivity; return _emissivity
::method area; expose _area; return _area
::method stefanBoltzmann class; return '0.00000005670374419'
::method heatFlowToNode
  t=self~node~temperatureKelvin; e=self~environmentKelvin
  return self~emissivity*.ThermalRadiationBoundary~stefanBoltzmann*self~area*(e**4-t**4)
::method apply; self~node~addPower(self~heatFlowToNode)

::class ThermalSolver public
::method init
  expose _nodes _paths _convection _radiation _time
  use strict arg startTime=.nil
  _nodes=.array~new; _paths=.array~new; _convection=.array~new; _radiation=.array~new
  if startTime==.nil then _time=0
  else _time=.ThermalUnitBoundary~scalar(startTime,.UnitDimension~time,'thermal solver start time')
  if _time<0 then raise syntax 88.900 array('non-negative thermal solver start time',_time)
::method time; expose _time; return _time
::method timeQuantity; return .Units~q(self~time,.Units~second)
::method nodes; expose _nodes; return _nodes~copy
::method addNode; expose _nodes; use strict arg node; _nodes~append(node); return node
::method addConductionPath; expose _paths; use strict arg path; _paths~append(path); return path
::method addConvectionBoundary; expose _convection; use strict arg boundary; _convection~append(boundary); return boundary
::method addRadiationBoundary; expose _radiation; use strict arg boundary; _radiation~append(boundary); return boundary
::method step
  expose _nodes _paths _convection _radiation _time
  use strict arg dtQuantity
  dt=.ThermalUnitBoundary~scalar(dtQuantity,.UnitDimension~time,'thermal solver timestep')
  if dt<=0 then raise syntax 88.900 array('positive thermal solver timestep',dt)
  do path over _paths; path~apply; end
  do boundary over _convection; boundary~apply; end
  do boundary over _radiation; boundary~apply; end
  do node over _nodes; node~integrate(dt); end
  _time=_time+dt

::requires 'PhysicsWorld.cls'
