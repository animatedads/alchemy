/* ooRexx Common Parts Library v0.1-dev2
 * Catalogue authority only. Physics and Rexx-tronics retain behaviour authority.
 */

::class PartDefinition public
::attribute id get
::attribute family get
::attribute description get
::attribute parameters get
::attribute materials get
::attribute geometry get
::attribute manufacturing get
::attribute provenance get
::attribute modelGrade get

::method init
  expose id family description parameters materials geometry manufacturing provenance modelGrade
  use strict arg idArg, familyArg, descriptionArg, parametersArg=.nil, materialsArg=.nil, geometryArg=.nil, manufacturingArg=.nil, provenanceArg=.nil, modelGradeArg='GENERIC'
  id = idArg~string
  family = familyArg~string~upper
  description = descriptionArg~string
  if parametersArg == .nil then parameters = .directory~new; else parameters = parametersArg
  if materialsArg == .nil then materials = .directory~new; else materials = materialsArg
  if geometryArg == .nil then geometry = .directory~new; else geometry = geometryArg
  if manufacturingArg == .nil then manufacturing = .directory~new; else manufacturing = manufacturingArg
  if provenanceArg == .nil then provenance = .directory~new; else provenance = provenanceArg
  modelGrade = modelGradeArg~string~upper

::method parameter
  expose parameters
  use strict arg name
  key = name~string~upper
  if \parameters~hasIndex(key) then raise syntax 93.900 array('unknown part parameter ' || name)
  return parameters[key]

::method material
  expose materials
  use strict arg role
  key = role~string~upper
  if \materials~hasIndex(key) then return .nil
  return materials[key]

::method validate
  expose id family parameters
  if id = '' then raise syntax 93.900 array('part id must not be empty')
  if family = '' then raise syntax 93.900 array('part family must not be empty')
  return .true

::class CommonParts public

::method resistor class
  use strict arg resistance, tolerance=5, power='0.25 W', id='GENERIC-RESISTOR'
  p=.directory~new; p['RESISTANCE']=resistance; p['TOLERANCE']=tolerance; p['POWER']=power
  m=.directory~new; m['LEAD']='CU-C110-REFERENCE'; m['BODY']='RESISTOR-BODY-GENERIC'
  g=.directory~new; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='ASSEMBLED'; mf['TERMINATION']='THROUGH-HOLE'
  return .PartDefinition~new(id,'RESISTOR','Generic axial resistor',p,m,g,mf,.nil,'GENERIC')

::method capacitor class
  use strict arg capacitance, voltageRating='50 V', dielectric='FR4-GENERIC', id='GENERIC-CAPACITOR'
  p=.directory~new; p['CAPACITANCE']=capacitance; p['VOLTAGE_RATING']=voltageRating
  m=.directory~new; m['DIELECTRIC']=dielectric; m['TERMINAL']='CU-C110-REFERENCE'
  g=.directory~new; g['FORM']='RADIAL_OR_DISC'
  mf=.directory~new; mf['PROCESS']='ASSEMBLED'
  return .PartDefinition~new(id,'CAPACITOR','Generic capacitor',p,m,g,mf,.nil,'GENERIC')

::method diode1N4148 class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  p['REVERSE_VOLTAGE_RATING']='100 V'
  m=.directory~new; m['SEMICONDUCTOR']='SI-INTRINSIC-REFERENCE'; m['LEAD']='CU-C110-REFERENCE'
  g=.directory~new; g['PACKAGE']='DO-35'; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['PACKAGE']='GLASS_AXIAL'
  pr=.directory~new; pr['NOTE']='Deterministic PWL simulation defaults; rating/model values are not a manufacturer lot guarantee.'
  return .PartDefinition~new('1N4148','DIODE','Common silicon small-signal switching diode',p,m,g,mf,pr,'COMMON')

::method diode1N4007 class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  p['REVERSE_VOLTAGE_RATING']='1000 V'
  m=.directory~new; m['SEMICONDUCTOR']='SI-INTRINSIC-REFERENCE'; m['LEAD']='CU-C110-REFERENCE'
  g=.directory~new; g['PACKAGE']='DO-41'; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['PACKAGE']='MOLDED_AXIAL'
  pr=.directory~new; pr['NOTE']='Deterministic PWL simulation defaults; rating/model values are not a manufacturer lot guarantee.'
  return .PartDefinition~new('1N4007','DIODE','Common silicon rectifier diode',p,m,g,mf,pr,'COMMON')

::method ledRed5mm class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='1.9 V'; p['ON_RESISTANCE_MODEL']='10 Ohm'; p['LIGHT_THRESHOLD']='0.5 mA'; p['WAVELENGTH']=.Units~q(625,.Units~nanometre)
  m=.directory~new; m['SEMICONDUCTOR']='III-V-SEMICONDUCTOR-GENERIC'; m['ENCAPSULANT']='EPOXY-GENERIC'; m['LEAD']='CU-C110-REFERENCE'
  g=.directory~new; g['PACKAGE']='T-1 3/4'; g['DIAMETER']='5 mm'
  mf=.directory~new; mf['PROCESS']='LED_ASSEMBLY'; mf['PACKAGE']='THROUGH-HOLE'
  return .PartDefinition~new('LED-RED-5MM-GENERIC','LED','Generic red 5 mm through-hole LED',p,m,g,mf,.nil,'GENERIC')

::method zener5V1 class
  p=.directory~new
  p['BREAKDOWN_MODEL']='5.1 V'; p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['REVERSE_RESISTANCE_MODEL']='5 Ohm'
  m=.directory~new; m['SEMICONDUCTOR']='SI-INTRINSIC-REFERENCE'; m['LEAD']='CU-C110-REFERENCE'
  g=.directory~new; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'
  return .PartDefinition~new('ZENER-5V1-GENERIC','ZENER','Generic 5.1 V Zener diode',p,m,g,mf,.nil,'GENERIC')

::method inductor class
  use strict arg inductance, currentRating='0.1 A', id='GENERIC-INDUCTOR'
  p=.directory~new; p['INDUCTANCE']=inductance; p['CURRENT_RATING']=currentRating; p['INITIAL_CURRENT']=0
  m=.directory~new; m['WINDING']='CU-C110-REFERENCE'; m['CORE']='FERRITE-GENERIC'
  g=.directory~new; g['FORM']='RADIAL_OR_AXIAL'
  mf=.directory~new; mf['PROCESS']='COIL_WINDING'; mf['TERMINATION']='THROUGH-HOLE'
  return .PartDefinition~new(id,'INDUCTOR','Generic wound inductor',p,m,g,mf,.nil,'GENERIC')

::method potentiometer class
  use strict arg resistance, position=0.5, id='GENERIC-POTENTIOMETER'
  p=.directory~new; p['RESISTANCE']=resistance; p['POSITION']=position
  m=.directory~new; m['TRACK']='CARBON-COMPOSITION-GENERIC'; m['TERMINAL']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='ROTARY'
  mf=.directory~new; mf['PROCESS']='ELECTROMECHANICAL_ASSEMBLY'
  return .PartDefinition~new(id,'POTENTIOMETER','Generic rotary potentiometer',p,m,g,mf,.nil,'GENERIC')

::method switchSPST class
  use strict arg normallyClosed=.false, id='GENERIC-SPST'
  p=.directory~new; p['CLOSED']=normallyClosed; p['CLOSED_RESISTANCE']='1 mOhm'; p['OPEN_RESISTANCE']=1000000000000
  m=.directory~new; m['CONTACT']='CU-ALLOY-GENERIC'; m['BODY']='ABS-GENERIC'
  g=.directory~new; g['FORM']='SPST'
  mf=.directory~new; mf['PROCESS']='ELECTROMECHANICAL_ASSEMBLY'
  return .PartDefinition~new(id,'SWITCH','Generic SPST switch',p,m,g,mf,.nil,'GENERIC')

::method transistor2N2222 class
  p=.directory~new
  p['POLARITY']='NPN'; p['BETA_MODEL']=100; p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['BASE_ON_RESISTANCE_MODEL']='100 Ohm'
  p['SATURATION_VOLTAGE_MODEL']='0.2 V'; p['SATURATION_RESISTANCE_MODEL']='10 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  m=.directory~new; m['SEMICONDUCTOR']='SI-INTRINSIC-REFERENCE'; m['LEAD']='CU-ALLOY-GENERIC'; m['PACKAGE']='EPOXY-GENERIC'
  g=.directory~new; g['PACKAGE']='TO-92'; g['TERMINALS']=3
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['DIE_ATTACH']='GENERIC'; mf['WIRE_BOND']='GENERIC'
  pr=.directory~new; pr['NOTE']='Common deterministic teaching/simulation model, not a manufacturer-specific lot or datasheet guarantee.'
  return .PartDefinition~new('2N2222-GENERIC','BJT','Common NPN small-signal transistor model',p,m,g,mf,pr,'COMMON')

::method sevenSegmentRed class
  p=.directory~new
  p['COMMON_TYPE']='COMMON_CATHODE'; p['FORWARD_VOLTAGE_MODEL']='1.7 V'; p['SEGMENT_RESISTANCE_MODEL']='1 kOhm'; p['LIGHT_THRESHOLD']='0.5 mA'; p['OFF_RESISTANCE_MODEL']=1000000000000
  m=.directory~new; m['DIE']='III-V-SEMICONDUCTOR-GENERIC'; m['LEADFRAME']='CU-ALLOY-GENERIC'; m['ENCAPSULANT']='EPOXY-GENERIC'
  g=.directory~new; g['FORM']='SEVEN_SEGMENT'; g['SEGMENTS']=7
  mf=.directory~new; mf['PROCESS']='LED_DISPLAY_ASSEMBLY'
  return .PartDefinition~new('7SEG-RED-CC-GENERIC','SEVEN_SEGMENT_DISPLAY','Generic red common-cathode seven-segment display',p,m,g,mf,.nil,'GENERIC')

::method boltM6x30 class
  use strict arg materialId='STEEL-8.8-REFERENCE'
  return self~metricBolt('M6','30 mm',materialId)

::method metricBolt class
  use strict arg nominalSize='M6', length='30 mm', materialId='STEEL-8.8-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown bolt material' materialId)
  yieldStress=material~value('YIELD_STRESS')
  shearFactor=material~value('SHEAR_FACTOR')
  size=nominalSize~string~upper
  if size='M2' then do; nominalDiameter='2 mm'; pitch='0.4 mm'; headAcross='4 mm'; headThickness='1.4 mm'; headAreaMm2=18.5; end
  else if size='M2.5' then do; nominalDiameter='2.5 mm'; pitch='0.45 mm'; headAcross='5 mm'; headThickness='1.7 mm'; headAreaMm2=27.1; end
  else if size='M3' then do; nominalDiameter='3 mm'; pitch='0.5 mm'; headAcross='5.5 mm'; headThickness='2 mm'; headAreaMm2=34.64; end
  else if size='M4' then do; nominalDiameter='4 mm'; pitch='0.7 mm'; headAcross='7 mm'; headThickness='2.8 mm'; headAreaMm2=61.60; end
  else if size='M5' then do; nominalDiameter='5 mm'; pitch='0.8 mm'; headAcross='8 mm'; headThickness='3.5 mm'; headAreaMm2=96.99; end
  else if size='M6' then do; nominalDiameter='6 mm'; pitch='1 mm'; headAcross='10 mm'; headThickness='4 mm'; headAreaMm2=138.56; end
  else if size='M8' then do; nominalDiameter='8 mm'; pitch='1.25 mm'; headAcross='13 mm'; headThickness='5.3 mm'; headAreaMm2=237.98; end
  else if size='M10' then do; nominalDiameter='10 mm'; pitch='1.5 mm'; headAcross='16 mm'; headThickness='6.4 mm'; headAreaMm2=366.6; end
  else if size='M12' then do; nominalDiameter='12 mm'; pitch='1.75 mm'; headAcross='18 mm'; headThickness='7.5 mm'; headAreaMm2=482.0; end
  else raise syntax 93.900 array('unsupported metric bolt size' nominalSize)
  headShearStress=yieldStress*shearFactor
  headCapacity=headShearStress*headAreaMm2/1000000
  p=.directory~new
  p['NOMINAL_SIZE']=nominalSize~string~upper; p['NOMINAL_DIAMETER']=nominalDiameter; p['LENGTH']=length; p['PITCH']=pitch
  p['TENSILE_STRENGTH']='800 MPa'; p['PROOF_LOAD']='580 MPa'
  p['MATERIAL_ID']=material~id; p['HEAD_ACROSS_FLATS']=headAcross; p['HEAD_THICKNESS']=headThickness
  p['HEAD_SHEAR_AREA']=headAreaMm2||' mm2'; p['HEAD_SHEAR_STRESS_PA']=headShearStress; p['HEAD_SHEAR_STRESS']=headShearStress||' Pa'
  p['HEAD_SHEAR_CAPACITY_N']=headCapacity; p['HEAD_SHEAR_CAPACITY']=headCapacity||' N'
  m=.directory~new; m['BODY']=material~id; p['NUT_COMPATIBILITY']=size||'-'||pitch
  g=.directory~new; g['FORM']='HEX_HEAD'; g['HEAD_SIZE']=headAcross; g['HEAD_THICKNESS']=headThickness; g['SHANK_DIAMETER']=nominalDiameter
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_AND_ROLLED'; mf['FINISH']='ZINC_REFERENCE'
  return .PartDefinition~new('BOLT-'||nominalSize~string~upper||'X'||length||'-'||material~id,'FASTENER',nominalSize~string~upper||' x '||length||' material-selectable bolt',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method plateAl6061T6 class
  p=.directory~new
  p['LENGTH']='100 mm'; p['WIDTH']='50 mm'; p['THICKNESS']='3 mm'
  p['MASS']='40.5 g'; p['YIELD_STRESS']='276 MPa'
  m=.directory~new; m['BODY']='AL-6061-T6'
  g=.directory~new; g['FORM']='RECTANGULAR_PLATE'; g['VOLUME']='15000 mm3'; g['AREA']='5000 mm2'
  mf=.directory~new; mf['PROCESS']='CUT_AND_MILL'; mf['TOLERANCE']='ISO-2768-M'
  return .PartDefinition~new('PLATE-AL6061T6-100X50X3','STRUCTURAL_PLATE','100 x 50 x 3 mm aluminium reference plate',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method bearing608 class
  return self~bearingDeepGroove('608','2RS')

::method heatsinkTO220 class
  p=.directory~new
  p['THERMAL_RESISTANCE']='12 K/W'; p['MASS']='18 g'; p['MAX_DEVICE_POWER']='10 W'
  m=.directory~new; m['BODY']='AL-6061-T6'; m['INTERFACE']='THERMAL-INTERFACE-GENERIC'
  g=.directory~new; g['FORM']='EXTRUDED_FIN'; g['BASE']='25 mm'; g['HEIGHT']='20 mm'
  mf=.directory~new; mf['PROCESS']='EXTRUDED_AND_CUT'; mf['MOUNT']='TO-220_CLIP_OR_SCREW'
  return .PartDefinition~new('HEATSINK-TO220-12KW','THERMAL','Generic TO-220 12 K/W heatsink',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')



::method roundShaft class
  use strict arg diameter='8 mm', length='100 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown shaft material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='ROUND_SHAFT'; g['DIAMETER']=diameter; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='BAR_STOCK_CUT'
  return .PartDefinition~new('SHAFT-'||diameter||'X'||length||'-'||material~id,'SHAFT','Round shaft stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method rectangularPlate class
  use strict arg length='100 mm', width='50 mm', thickness='3 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown plate material' materialId)
  p=.directory~new; p['LENGTH']=length; p['WIDTH']=width; p['THICKNESS']=thickness; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='RECTANGULAR_PLATE'; g['LENGTH']=length; g['WIDTH']=width; g['THICKNESS']=thickness
  mf=.directory~new; mf['PROCESS']='SHEET_OR_PLATE_CUT'
  return .PartDefinition~new('PLATE-'||length||'X'||width||'X'||thickness||'-'||material~id,'STRUCTURAL_PLATE','Parameterised rectangular plate stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method compressionSpring class
  use strict arg wireDiameter='1 mm', meanCoilDiameter='10 mm', activeTurns=8, freeLength='30 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown spring material' materialId)
  p=.directory~new
  p['WIRE_DIAMETER']=wireDiameter; p['MEAN_COIL_DIAMETER']=meanCoilDiameter; p['ACTIVE_TURNS']=activeTurns; p['FREE_LENGTH']=freeLength
  p['MATERIAL_ID']=material~id
  m=.directory~new; m['WIRE']=material~id
  g=.directory~new; g['FORM']='HELICAL_COMPRESSION'; g['WIRE_DIAMETER']=wireDiameter; g['MEAN_COIL_DIAMETER']=meanCoilDiameter
  mf=.directory~new; mf['PROCESS']='COLD_COILED_REFERENCE'
  pr=.directory~new; pr['NOTE']='Geometry authority only in Parts; spring force/rate belongs to Physics and may be derived from material shear modulus.'
  return .PartDefinition~new('SPRING-COMPRESSION-'||wireDiameter||'-'||meanCoilDiameter||'-N'||activeTurns,'SPRING','Parameterised helical compression spring',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method bearingDeepGroove class
  use strict arg series='608', seal='2RS'
  select
    when series='608' then do; bore='8 mm'; outer='22 mm'; width='7 mm'; end
    when series='6000' then do; bore='10 mm'; outer='26 mm'; width='8 mm'; end
    when series='6001' then do; bore='12 mm'; outer='28 mm'; width='8 mm'; end
    when series='6002' then do; bore='15 mm'; outer='32 mm'; width='9 mm'; end
    when series='6200' then do; bore='10 mm'; outer='30 mm'; width='9 mm'; end
    when series='6201' then do; bore='12 mm'; outer='32 mm'; width='10 mm'; end
    when series='6202' then do; bore='15 mm'; outer='35 mm'; width='11 mm'; end
    when series='6203' then do; bore='17 mm'; outer='40 mm'; width='12 mm'; end
    when series='6204' then do; bore='20 mm'; outer='47 mm'; width='14 mm'; end
    otherwise raise syntax 93.900 array('unsupported bearing series' series)
  end
  p=.directory~new; p['BORE_DIAMETER']=bore; p['OUTER_DIAMETER']=outer; p['WIDTH']=width; p['SEAL']=seal
  m=.directory~new; m['RINGS']='STEEL-BEARING-GENERIC'; m['CAGE']='POLYAMIDE-GENERIC'
  if seal='2RS' then m['SEAL']='RUBBER-GENERIC'
  g=.directory~new; g['FORM']='DEEP_GROOVE'; g['BORE']=bore; g['OUTER']=outer; g['WIDTH']=width
  mf=.directory~new; mf['PROCESS']='GROUND_RINGS_AND_ASSEMBLED'
  pr=.directory~new; pr['NOTE']='Envelope dimensions are catalogue geometry; manufacturer load/speed ratings deliberately omitted from generic family.'
  return .PartDefinition~new('BEARING-'||series||'-'||seal,'BEARING',series||' deep-groove bearing',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method standardBenchSet class
  d=.directory~new
  d['R_1K_5_025W']=self~resistor('1 kohm','5','0.25 W','R-1K-5-025W')
  d['R_10K_5_025W']=self~resistor('10 kohm','5','0.25 W','R-10K-5-025W')
  d['C_100NF_50V']=self~capacitor('100 nF','50 V','FR4-GENERIC','C-100NF-50V')
  d['C_10UF_25V']=self~capacitor('10 uF','25 V','ELECTROLYTIC-DIELECTRIC-GENERIC','C-10UF-25V')
  d['1N4148']=self~diode1N4148
  d['1N4007']=self~diode1N4007
  d['LED_RED_5MM']=self~ledRed5mm
  d['ZENER_5V1']=self~zener5V1
  d['L_10MH']=self~inductor('10 mH','0.1 A','L-10MH')
  d['POT_10K']=self~potentiometer('10 kOhm',0.5,'POT-10K')
  d['SW_SPST']=self~switchSPST(.false,'SW-SPST')
  d['2N2222']=self~transistor2N2222
  d['7SEG_RED_CC']=self~sevenSegmentRed
  d['BOLT_M6X30']=self~boltM6x30
  d['BOLT_M6X30_SS304']=self~boltM6x30('SS-304-REFERENCE')
  d['BOLT_M6X30_AL6061']=self~boltM6x30('AL-6061-T6')
  d['PLATE_AL6061T6']=self~plateAl6061T6
  d['BEARING_608']=self~bearing608
  d['HEATSINK_TO220']=self~heatsinkTO220
  return d

::class RexxTronicsPartFactory public
::method instantiate class
  use strict arg definition, instanceId
  definition~validate
  select
    when definition~family='RESISTOR' then return .Resistor~new(instanceId, definition~parameter('RESISTANCE'), definition~parameter('TOLERANCE'), definition~parameter('POWER'))
    when definition~family='CAPACITOR' then return .Capacitor~new(instanceId, definition~parameter('CAPACITANCE'))
    when definition~family='DIODE' then return .Diode~new(instanceId, definition~parameter('FORWARD_VOLTAGE_MODEL'), definition~parameter('ON_RESISTANCE_MODEL'), definition~parameter('OFF_RESISTANCE_MODEL'))
    when definition~family='ZENER' then return .ZenerDiode~new(instanceId, definition~parameter('BREAKDOWN_MODEL'), definition~parameter('FORWARD_VOLTAGE_MODEL'), definition~parameter('ON_RESISTANCE_MODEL'), definition~parameter('REVERSE_RESISTANCE_MODEL'))
    when definition~family='LED' then return .LED~new(instanceId, definition~parameter('FORWARD_VOLTAGE_MODEL'), definition~parameter('ON_RESISTANCE_MODEL'), definition~parameter('LIGHT_THRESHOLD'), .nil, definition~parameter('WAVELENGTH'))
    when definition~family='INDUCTOR' then return .Inductor~new(instanceId, definition~parameter('INDUCTANCE'), definition~parameter('INITIAL_CURRENT'))
    when definition~family='POTENTIOMETER' then return .Potentiometer~new(instanceId, definition~parameter('RESISTANCE'), definition~parameter('POSITION'))
    when definition~family='SWITCH' then return .Switch~new(instanceId, definition~parameter('CLOSED'), definition~parameter('CLOSED_RESISTANCE'), definition~parameter('OPEN_RESISTANCE'))
    when definition~family='BJT' then return .BipolarJunctionTransistor~new(instanceId, definition~parameter('POLARITY'), definition~parameter('BETA_MODEL'), definition~parameter('FORWARD_VOLTAGE_MODEL'), definition~parameter('BASE_ON_RESISTANCE_MODEL'), definition~parameter('SATURATION_VOLTAGE_MODEL'), definition~parameter('SATURATION_RESISTANCE_MODEL'), definition~parameter('OFF_RESISTANCE_MODEL'))
    when definition~family='SEVEN_SEGMENT_DISPLAY' then return .SevenSegmentDisplay~new(instanceId, definition~parameter('COMMON_TYPE'), definition~parameter('FORWARD_VOLTAGE_MODEL'), definition~parameter('SEGMENT_RESISTANCE_MODEL'), definition~parameter('LIGHT_THRESHOLD'), definition~parameter('OFF_RESISTANCE_MODEL'))
    otherwise raise syntax 93.900 array('no Rexx-tronics factory mapping for part family ' || definition~family)
  end

::requires 'RexxTronicsDC.cls'
::requires 'RexxTronicsSemiconductors.cls'
::requires 'RexxTronicsDisplays.cls'
::requires 'MaterialsCatalog.cls'
