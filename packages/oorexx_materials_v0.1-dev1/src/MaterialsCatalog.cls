/* ooRexx Materials Library v0.1-dev1
 * Reusable material-property catalogue.  It owns reference data, conditions,
 * provenance and projection; Physics World owns physical behaviour.
 */

::class MaterialProperty public
::attribute name get
::attribute value get
::attribute unit get
::attribute condition get
::attribute provenance get
::attribute grade get

::method init
  expose name value unit condition provenance grade
  use strict arg nameArg,valueArg,unitArg=.nil,conditionArg=.nil,provenanceArg=.nil,gradeArg='REFERENCE'
  name=nameArg~string~upper; value=valueArg; unit=unitArg
  if conditionArg==.nil then condition=.directory~new; else condition=conditionArg
  if provenanceArg==.nil then provenance=.directory~new; else provenance=provenanceArg
  grade=gradeArg~string~upper

::method quantity
  expose value unit
  if unit==.nil then return value
  return .Units~q(value,unit)

::class MaterialDefinition public
::attribute id get
::attribute name get
::attribute family get
::attribute properties get
::attribute provenance get
::attribute modelGrade get

::method init
  expose id name family properties provenance modelGrade
  use strict arg idArg,nameArg,familyArg,propertiesArg=.nil,provenanceArg=.nil,modelGradeArg='REFERENCE'
  id=idArg~string; name=nameArg~string; family=familyArg~string~upper
  if propertiesArg==.nil then properties=.directory~new; else properties=propertiesArg
  if provenanceArg==.nil then provenance=.directory~new; else provenance=provenanceArg
  modelGrade=modelGradeArg~string~upper

::method hasProperty
  expose properties
  use strict arg propertyName
  return properties~hasIndex(propertyName~string~upper)

::method property
  expose properties id
  use strict arg propertyName
  k=propertyName~string~upper
  if \properties~hasIndex(k) then raise syntax 93.900 array('material' id 'has no property' propertyName)
  return properties[k]

::method value
  use strict arg propertyName
  return self~property(propertyName)~value

::method quantity
  use strict arg propertyName
  return self~property(propertyName)~quantity

::method validate
  expose id name family properties
  if id='' | name='' | family='' then raise syntax 93.900 array('material identity fields must not be empty')
  if properties~items=0 then raise syntax 93.900 array('material must have at least one property')
  return .true

::class MaterialBuilder public
::method init
  expose _id _name _family _p _prov _grade
  use strict arg id,name,family,grade='REFERENCE'
  _id=id; _name=name; _family=family; _grade=grade; _p=.directory~new; _prov=.directory~new
::method add
  expose _p
  use strict arg name,value,unit=.nil,condition=.nil,note=''
  pr=.directory~new
  if note<>'' then pr['NOTE']=note
  _p[name~string~upper]=.MaterialProperty~new(name,value,unit,condition,pr)
  return self
::method provenance
  expose _prov
  use strict arg key,value
  _prov[key~string~upper]=value
  return self
::method build
  expose _id _name _family _p _prov _grade
  return .MaterialDefinition~new(_id,_name,_family,_p,_prov,_grade)

::class CommonMaterials public
::method referenceCondition class
  d=.directory~new; d['TEMPERATURE_C']=20; d['PRESSURE_PA']=101325; return d

::method copper class
  c=self~referenceCondition
  b=.MaterialBuilder~new('CU-C110-REFERENCE','Copper, high-conductivity reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',8960,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',385,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',400,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('ELECTRICAL_RESISTIVITY','0.0000000168',.Units~ohm*.Units~metre,c)
  b~add('YOUNG_MODULUS','117000000000',.Units~pascal,c)
  b~add('POISSON_RATIO','0.34',.Units~one,c)
  b~add('THERMAL_EXPANSION','0.0000165',.Units~one/.Units~deltaKelvin,c)
  b~provenance('NOTE','Representative engineering values near room temperature; not lot certification.')
  return b~build

::method aluminium6061T6 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('AL-6061-T6','Aluminium 6061-T6 reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',2700,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',897,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',167,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','68900000000',.Units~pascal,c)
  b~add('POISSON_RATIO','0.33',.Units~one,c)
  b~add('YIELD_STRESS','276000000',.Units~pascal,c)
  b~add('SHEAR_FACTOR','0.6',.Units~one,c)
  return b~build

::method mildSteel class
  c=self~referenceCondition
  b=.MaterialBuilder~new('STEEL-MILD-REFERENCE','Mild steel reference','METAL','GENERIC')
  b~add('DENSITY',7850,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',486,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',50,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','200000000000',.Units~pascal,c)
  b~add('POISSON_RATIO','0.30',.Units~one,c)
  return b~build

::method stainless304 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('SS-304-REFERENCE','Stainless steel 304 reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',8000,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',500,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','16.2',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','193000000000',.Units~pascal,c)
  b~add('YIELD_STRESS','215000000',.Units~pascal,c)
  b~add('SHEAR_FACTOR','0.6',.Units~one,c)
  return b~build

::method steelFastener88 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('STEEL-8.8-REFERENCE','Property class 8.8 fastener steel reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',7850,.Units~kilogramPerCubicMetre,c)
  b~add('YOUNG_MODULUS','200000000000',.Units~pascal,c)
  b~add('YIELD_STRESS','640000000',.Units~pascal,c); b~add('POISSON_RATIO','0.30',.Units~one,c)
  b~add('SHEAR_FACTOR','0.6',.Units~one,c)
  return b~build

::method steelFastener48 class
  c=self~referenceCondition; b=.MaterialBuilder~new('STEEL-4.8-REFERENCE','Property class 4.8 fastener steel reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',7850,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','200000000000',.Units~pascal,c); b~add('YIELD_STRESS','320000000',.Units~pascal,c); b~add('POISSON_RATIO','0.30',.Units~one,c); b~add('SHEAR_FACTOR','0.6',.Units~one,c); return b~build

::method steelFastener109 class
  c=self~referenceCondition; b=.MaterialBuilder~new('STEEL-10.9-REFERENCE','Property class 10.9 fastener steel reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',7850,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','200000000000',.Units~pascal,c); b~add('YIELD_STRESS','900000000',.Units~pascal,c); b~add('POISSON_RATIO','0.30',.Units~one,c); b~add('SHEAR_FACTOR','0.6',.Units~one,c); return b~build

::method steelFastener129 class
  c=self~referenceCondition; b=.MaterialBuilder~new('STEEL-12.9-REFERENCE','Property class 12.9 fastener steel reference','METAL','ENGINEERING_REFERENCE')
  b~add('DENSITY',7850,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','200000000000',.Units~pascal,c); b~add('YIELD_STRESS','1100000000',.Units~pascal,c); b~add('POISSON_RATIO','0.30',.Units~one,c); b~add('SHEAR_FACTOR','0.6',.Units~one,c); return b~build

::method brass class
  c=self~referenceCondition
  b=.MaterialBuilder~new('BRASS-COMMON-REFERENCE','Common brass reference','METAL','GENERIC')
  b~add('DENSITY',8500,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','100000000000',.Units~pascal,c)
  b~add('THERMAL_CONDUCTIVITY',109,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method silicon class
  c=self~referenceCondition
  b=.MaterialBuilder~new('SI-INTRINSIC-REFERENCE','Silicon reference','SEMICONDUCTOR','GENERIC')
  b~add('DENSITY',2329,.Units~kilogramPerCubicMetre,c); b~add('SPECIFIC_HEAT',700,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',148,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method fr4 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('FR4-GENERIC','FR-4 laminate generic reference','COMPOSITE','GENERIC')
  b~add('DENSITY',1850,.Units~kilogramPerCubicMetre,c); b~add('SPECIFIC_HEAT',1100,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','0.30',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method glass class
  c=self~referenceCondition
  b=.MaterialBuilder~new('GLASS-SODA-LIME-REFERENCE','Soda-lime glass reference','GLASS','GENERIC')
  b~add('DENSITY',2500,.Units~kilogramPerCubicMetre,c); b~add('SPECIFIC_HEAT',840,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',1,.Units~watt/(.Units~metre*.Units~deltaKelvin),c); b~add('REFRACTIVE_INDEX','1.52',.Units~one,c)
  return b~build

::method abs class
  c=self~referenceCondition
  b=.MaterialBuilder~new('ABS-GENERIC','ABS polymer generic reference','POLYMER','GENERIC')
  b~add('DENSITY',1040,.Units~kilogramPerCubicMetre,c); b~add('SPECIFIC_HEAT',1300,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','0.18',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method nylon66 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('PA66-GENERIC','Nylon 6/6 generic reference','POLYMER','GENERIC')
  b~add('DENSITY',1140,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','2800000000',.Units~pascal,c)
  return b~build

::method ptfe class
  c=self~referenceCondition
  b=.MaterialBuilder~new('PTFE-GENERIC','PTFE generic reference','POLYMER','GENERIC')
  b~add('DENSITY',2200,.Units~kilogramPerCubicMetre,c); b~add('THERMAL_CONDUCTIVITY','0.25',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method rubber class
  c=self~referenceCondition
  b=.MaterialBuilder~new('RUBBER-GENERIC','Elastomer generic reference','ELASTOMER','GENERIC')
  b~add('DENSITY',1100,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','7000000',.Units~pascal,c)
  return b~build

::method water20C class
  c=self~referenceCondition
  b=.MaterialBuilder~new('WATER-20C','Liquid water reference near 20 C','FLUID','REFERENCE')
  b~add('DENSITY','998.2',.Units~kilogramPerCubicMetre,c); b~add('DYNAMIC_VISCOSITY','0.001002',.Units~pascal*.Units~second,c)
  b~add('SPECIFIC_HEAT',4182,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','0.598',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('REFRACTIVE_INDEX','1.333',.Units~one,c)
  return b~build

::method air20C class
  c=self~referenceCondition
  b=.MaterialBuilder~new('AIR-20C','Dry air reference near 20 C','GAS','REFERENCE')
  b~add('DENSITY','1.2041',.Units~kilogramPerCubicMetre,c); b~add('DYNAMIC_VISCOSITY','0.00001825',.Units~pascal*.Units~second,c)
  b~add('SPECIFIC_HEAT',1005,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','0.0257',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('REFRACTIVE_INDEX','1.000277',.Units~one,c)
  return b~build

::method epoxy class
  c=self~referenceCondition
  b=.MaterialBuilder~new('EPOXY-GENERIC','Cured epoxy generic reference','POLYMER','GENERIC')
  b~add('DENSITY',1200,.Units~kilogramPerCubicMetre,c); b~add('THERMAL_CONDUCTIVITY','0.20',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

::method ferrite class
  c=self~referenceCondition
  b=.MaterialBuilder~new('FERRITE-GENERIC','Soft ferrite generic reference','CERAMIC_MAGNETIC','GENERIC')
  b~add('DENSITY',4900,.Units~kilogramPerCubicMetre,c); b~add('THERMAL_CONDUCTIVITY',5,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  return b~build

/* Added engineering references: selected because they close common structural,
   enclosure and thermal-analysis gaps without pretending to be certificates. */
::method polycarbonate class
  c=self~referenceCondition
  b=.MaterialBuilder~new('PC-GENERIC','Polycarbonate generic reference','POLYMER','ENGINEERING_REFERENCE')
  b~add('DENSITY',1200,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',1250,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','0.22',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','2300000000',.Units~pascal,c)
  b~add('YIELD_STRESS','65000000',.Units~pascal,c)
  b~add('POISSON_RATIO','0.37',.Units~one,c)
  return b~build

::method carbonFiberEpoxy class
  c=self~referenceCondition
  b=.MaterialBuilder~new('CFRP-EPOXY-GENERIC','Carbon-fibre epoxy laminate generic reference','COMPOSITE','ENGINEERING_REFERENCE')
  b~add('DENSITY',1600,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',800,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY',6,.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','70000000000',.Units~pascal,c)
  b~add('THERMAL_EXPANSION','0.000002',.Units~one/.Units~deltaKelvin,c)
  return b~build

::method concreteC30 class
  c=self~referenceCondition
  b=.MaterialBuilder~new('CONCRETE-C30','Concrete C30 generic reference','MINERAL_COMPOSITE','ENGINEERING_REFERENCE')
  b~add('DENSITY',2400,.Units~kilogramPerCubicMetre,c)
  b~add('SPECIFIC_HEAT',880,.Units~joule/(.Units~kilogram*.Units~deltaKelvin),c)
  b~add('THERMAL_CONDUCTIVITY','1.7',.Units~watt/(.Units~metre*.Units~deltaKelvin),c)
  b~add('YOUNG_MODULUS','30000000000',.Units~pascal,c)
  b~add('COMPRESSIVE_STRENGTH','30000000',.Units~pascal,c)
  return b~build

::method pom class
  c=self~referenceCondition; b=.MaterialBuilder~new('POM-GENERIC','Acetal/polyoxymethylene generic reference','POLYMER','GENERIC')
  b~add('DENSITY',1410,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','3000000000',.Units~pascal,c); b~add('THERMAL_CONDUCTIVITY','0.31',.Units~watt/(.Units~metre*.Units~deltaKelvin),c); return b~build

::method pvc class
  c=self~referenceCondition; b=.MaterialBuilder~new('PVC-GENERIC','Polyvinyl chloride generic reference','POLYMER','GENERIC')
  b~add('DENSITY',1380,.Units~kilogramPerCubicMetre,c); b~add('YOUNG_MODULUS','3000000000',.Units~pascal,c); b~add('THERMAL_CONDUCTIVITY','0.19',.Units~watt/(.Units~metre*.Units~deltaKelvin),c); return b~build

::method catalog class
  a=.array~new
  a~append(self~copper); a~append(self~aluminium6061T6); a~append(self~mildSteel); a~append(self~stainless304)
  a~append(self~brass); a~append(self~silicon); a~append(self~fr4); a~append(self~glass)
  a~append(self~abs); a~append(self~nylon66); a~append(self~ptfe); a~append(self~rubber)
  a~append(self~water20C); a~append(self~air20C); a~append(self~epoxy); a~append(self~ferrite)
  a~append(self~polycarbonate); a~append(self~carbonFiberEpoxy); a~append(self~concreteC30); a~append(self~pom); a~append(self~pvc); a~append(self~steelFastener48); a~append(self~steelFastener88); a~append(self~steelFastener109); a~append(self~steelFastener129)
  return a

::method byId class
  use strict arg wanted
  do m over self~catalog
    if m~id~caselessEquals(wanted) then return m
  end
  return .nil


::requires 'Units.cls'
