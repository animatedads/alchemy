/* Physical Manufacturing dev5: thermally evolving deposition.
   Manufacturing owns process composition and the deposition event. Physics
   owns temperature integration and mechanics. Materials owns reference thermal
   properties. No hidden print-quality coefficient is used. */

::class DepositionThermalProfile public
::method init
  expose _hot _set _cold _hotFactor _setFactor _coldFactor
  use strict arg hotTemperature,setTemperature,coldTemperature,hotStiffnessFactor,setStiffnessFactor,coldStiffnessFactor=1
  if hotTemperature<=setTemperature | setTemperature<=coldTemperature then raise syntax 88.900 array('hot > set > cold temperatures')
  if hotStiffnessFactor<=0 | setStiffnessFactor<=0 | coldStiffnessFactor<=0 then raise syntax 88.900 array('positive stiffness factors')
  _hot=hotTemperature; _set=setTemperature; _cold=coldTemperature
  _hotFactor=hotStiffnessFactor; _setFactor=setStiffnessFactor; _coldFactor=coldStiffnessFactor
::method factorAt
  expose _hot _set _cold _hotFactor _setFactor _coldFactor
  use strict arg temperature
  t=temperature
  if t>=_hot then return _hotFactor
  if t>=_set then return _hotFactor+(t-_hot)/(_set-_hot)*(_setFactor-_hotFactor)
  if t>=_cold then return _setFactor+(t-_set)/(_cold-_set)*(_coldFactor-_setFactor)
  return _coldFactor

::class ThermalManufacturedSection public subclass ManufacturedSection
::method init
  expose _thermalNode _baseStiffness _thermalProfile _depositionCoordinate _depositionTime
  use strict arg sectionId,bodyState,mass,width,height,depth,materialRef,parent,attachment,thermalNode,baseStiffness,thermalProfile,depositionCoordinate,depositionTime
  self~init:super(sectionId,bodyState,mass,width,height,depth,materialRef,parent,attachment)
  _thermalNode=thermalNode; _baseStiffness=baseStiffness; _thermalProfile=thermalProfile
  _depositionCoordinate=depositionCoordinate; _depositionTime=depositionTime
::method thermalNode; expose _thermalNode; return _thermalNode
::method temperatureKelvin; expose _thermalNode; return _thermalNode~temperatureKelvin
::method depositionCoordinate; expose _depositionCoordinate; return _depositionCoordinate
::method depositionTime; expose _depositionTime; return _depositionTime
::method effectiveStiffness; expose _baseStiffness _thermalProfile; return _baseStiffness*_thermalProfile~factorAt(self~temperatureKelvin)

::class ThermalDepositionProcess public
::method init
  expose _printer _thermal _material _thermalMaterial _profile _ambient _h _sections
  use strict arg printerDynamics,materialDefinition,thermalProfile,ambientKelvin=293.15,convectionCoefficient=8
  if ambientKelvin<=0 | convectionCoefficient<0 then raise syntax 88.900 array('valid ambient and convection coefficient')
  _printer=printerDynamics; _material=materialDefinition; _profile=thermalProfile
  _thermalMaterial=.PhysicsMaterialProjection~thermal(materialDefinition)
  _thermal=.ThermalSolver~new; _ambient=ambientKelvin; _h=convectionCoefficient; _sections=.array~new
::method sections; expose _sections; return _sections~copy
::method thermalSolver; expose _thermal; return _thermal
::method depositSection
  expose _printer _thermal _material _thermalMaterial _profile _ambient _h _sections
  use strict arg id,mass,width,height,depth,baseStiffness,damping,initialTemperature,lateralOffset=0
  if initialTemperature<=0 then raise syntax 88.900 array('positive absolute deposition temperature')
  coordinate=_printer~depositionPosition
  raw=_printer~addSection(id,mass,width,height,depth,baseStiffness*_profile~factorAt(initialTemperature),damping,lateralOffset,_material)
  node=.ThermalNode~fromMass('deposit-'||id,raw~body,.Units~q(mass,.Units~kilogram),_thermalMaterial,.Units~q(initialTemperature,.Units~kelvin))
  _thermal~addNode(node)
  area=2*(width*height+width*depth+height*depth)
  if _h>0 then _thermal~addConvectionBoundary(.ThermalConvectionBoundary~new('ambient-'||id,node,.Units~q(_ambient,.Units~kelvin),.Units~q(_h,.ThermalUnitBoundary~convectionCoefficientUnit),.Units~q(area,.Units~squareMetre)))
  section=.ThermalManufacturedSection~new(id,raw~body,mass,width,height,depth,_material,raw~parent,raw~attachment,node,baseStiffness,_profile,coordinate,_thermal~time)
  _sections~append(section)
  return section
::method stepThermal
  expose _thermal
  use strict arg dt
  _thermal~step(.Units~q(dt,.Units~second))
::method step
  expose _printer
  use strict arg dt
  _printer~step(dt); self~stepThermal(dt)
  return _printer~depositionPosition

::requires 'GrowingWorkpiece.cls'
::requires 'Thermal.cls'
::requires 'PhysicsMaterialProjection.cls'
