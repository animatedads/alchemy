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
  m=.directory~new; m['LEAD']='copper'; m['BODY']='resistor-body-generic'
  g=.directory~new; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='ASSEMBLED'; mf['TERMINATION']='THROUGH-HOLE'
  return .PartDefinition~new(id,'RESISTOR','Generic axial resistor',p,m,g,mf,.nil,'GENERIC')

::method capacitor class
  use strict arg capacitance, voltageRating='50 V', dielectric='ceramic', id='GENERIC-CAPACITOR'
  p=.directory~new; p['CAPACITANCE']=capacitance; p['VOLTAGE_RATING']=voltageRating
  m=.directory~new; m['DIELECTRIC']=dielectric; m['TERMINAL']='copper'
  g=.directory~new; g['FORM']='RADIAL_OR_DISC'
  mf=.directory~new; mf['PROCESS']='ASSEMBLED'
  return .PartDefinition~new(id,'CAPACITOR','Generic capacitor',p,m,g,mf,.nil,'GENERIC')

::method diode1N4148 class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  p['REVERSE_VOLTAGE_RATING']='100 V'
  m=.directory~new; m['SEMICONDUCTOR']='silicon'; m['LEAD']='copper'
  g=.directory~new; g['PACKAGE']='DO-35'; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['PACKAGE']='GLASS_AXIAL'
  pr=.directory~new; pr['NOTE']='Deterministic PWL simulation defaults; rating/model values are not a manufacturer lot guarantee.'
  return .PartDefinition~new('1N4148','DIODE','Common silicon small-signal switching diode',p,m,g,mf,pr,'COMMON')

::method diode1N4007 class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  p['REVERSE_VOLTAGE_RATING']='1000 V'
  m=.directory~new; m['SEMICONDUCTOR']='silicon'; m['LEAD']='copper'
  g=.directory~new; g['PACKAGE']='DO-41'; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['PACKAGE']='MOLDED_AXIAL'
  pr=.directory~new; pr['NOTE']='Deterministic PWL simulation defaults; rating/model values are not a manufacturer lot guarantee.'
  return .PartDefinition~new('1N4007','DIODE','Common silicon rectifier diode',p,m,g,mf,pr,'COMMON')

::method ledRed5mm class
  p=.directory~new
  p['FORWARD_VOLTAGE_MODEL']='1.9 V'; p['ON_RESISTANCE_MODEL']='10 Ohm'; p['LIGHT_THRESHOLD']='0.5 mA'; p['WAVELENGTH']=.Units~q(625,.Units~nanometre)
  m=.directory~new; m['SEMICONDUCTOR']='III-V LED DIE'; m['ENCAPSULANT']='epoxy'; m['LEAD']='copper'
  g=.directory~new; g['PACKAGE']='T-1 3/4'; g['DIAMETER']='5 mm'
  mf=.directory~new; mf['PROCESS']='LED_ASSEMBLY'; mf['PACKAGE']='THROUGH-HOLE'
  return .PartDefinition~new('LED-RED-5MM-GENERIC','LED','Generic red 5 mm through-hole LED',p,m,g,mf,.nil,'GENERIC')

::method zener5V1 class
  p=.directory~new
  p['BREAKDOWN_MODEL']='5.1 V'; p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['ON_RESISTANCE_MODEL']='1 Ohm'; p['REVERSE_RESISTANCE_MODEL']='5 Ohm'
  m=.directory~new; m['SEMICONDUCTOR']='silicon'; m['LEAD']='copper'
  g=.directory~new; g['FORM']='AXIAL'
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'
  return .PartDefinition~new('ZENER-5V1-GENERIC','ZENER','Generic 5.1 V Zener diode',p,m,g,mf,.nil,'GENERIC')

::method inductor class
  use strict arg inductance, currentRating='0.1 A', id='GENERIC-INDUCTOR'
  p=.directory~new; p['INDUCTANCE']=inductance; p['CURRENT_RATING']=currentRating; p['INITIAL_CURRENT']=0
  m=.directory~new; m['WINDING']='copper'; m['CORE']='ferrite-generic'
  g=.directory~new; g['FORM']='RADIAL_OR_AXIAL'
  mf=.directory~new; mf['PROCESS']='COIL_WINDING'; mf['TERMINATION']='THROUGH-HOLE'
  return .PartDefinition~new(id,'INDUCTOR','Generic wound inductor',p,m,g,mf,.nil,'GENERIC')

::method potentiometer class
  use strict arg resistance, position=0.5, id='GENERIC-POTENTIOMETER'
  p=.directory~new; p['RESISTANCE']=resistance; p['POSITION']=position
  m=.directory~new; m['TRACK']='carbon-composition'; m['TERMINAL']='copper-alloy'
  g=.directory~new; g['FORM']='ROTARY'
  mf=.directory~new; mf['PROCESS']='ELECTROMECHANICAL_ASSEMBLY'
  return .PartDefinition~new(id,'POTENTIOMETER','Generic rotary potentiometer',p,m,g,mf,.nil,'GENERIC')

::method switchSPST class
  use strict arg normallyClosed=.false, id='GENERIC-SPST'
  p=.directory~new; p['CLOSED']=normallyClosed; p['CLOSED_RESISTANCE']='1 mOhm'; p['OPEN_RESISTANCE']=1000000000000
  m=.directory~new; m['CONTACT']='copper-alloy'; m['BODY']='polymer-generic'
  g=.directory~new; g['FORM']='SPST'
  mf=.directory~new; mf['PROCESS']='ELECTROMECHANICAL_ASSEMBLY'
  return .PartDefinition~new(id,'SWITCH','Generic SPST switch',p,m,g,mf,.nil,'GENERIC')

::method transistor2N2222 class
  p=.directory~new
  p['POLARITY']='NPN'; p['BETA_MODEL']=100; p['FORWARD_VOLTAGE_MODEL']='0.7 V'; p['BASE_ON_RESISTANCE_MODEL']='100 Ohm'
  p['SATURATION_VOLTAGE_MODEL']='0.2 V'; p['SATURATION_RESISTANCE_MODEL']='10 Ohm'; p['OFF_RESISTANCE_MODEL']=1000000000000
  m=.directory~new; m['SEMICONDUCTOR']='silicon'; m['LEAD']='copper-alloy'; m['PACKAGE']='epoxy-mold-compound'
  g=.directory~new; g['PACKAGE']='TO-92'; g['TERMINALS']=3
  mf=.directory~new; mf['PROCESS']='SEMICONDUCTOR_ASSEMBLY'; mf['DIE_ATTACH']='GENERIC'; mf['WIRE_BOND']='GENERIC'
  pr=.directory~new; pr['NOTE']='Common deterministic teaching/simulation model, not a manufacturer-specific lot or datasheet guarantee.'
  return .PartDefinition~new('2N2222-GENERIC','BJT','Common NPN small-signal transistor model',p,m,g,mf,pr,'COMMON')

::method sevenSegmentRed class
  p=.directory~new
  p['COMMON_TYPE']='COMMON_CATHODE'; p['FORWARD_VOLTAGE_MODEL']='1.7 V'; p['SEGMENT_RESISTANCE_MODEL']='1 kOhm'; p['LIGHT_THRESHOLD']='0.5 mA'; p['OFF_RESISTANCE_MODEL']=1000000000000
  m=.directory~new; m['DIE']='III-V LED DIE'; m['LEADFRAME']='copper-alloy'; m['ENCAPSULANT']='epoxy'
  g=.directory~new; g['FORM']='SEVEN_SEGMENT'; g['SEGMENTS']=7
  mf=.directory~new; mf['PROCESS']='LED_DISPLAY_ASSEMBLY'
  return .PartDefinition~new('7SEG-RED-CC-GENERIC','SEVEN_SEGMENT_DISPLAY','Generic red common-cathode seven-segment display',p,m,g,mf,.nil,'GENERIC')

::method boltM6x30 class
  p=.directory~new
  p['NOMINAL_DIAMETER']='6 mm'; p['LENGTH']='30 mm'; p['PITCH']='1 mm'
  p['TENSILE_STRENGTH']='800 MPa'; p['PROOF_LOAD']='580 MPa'
  m=.directory~new; m['BODY']='steel-metric-fastener'; m['NUT_COMPATIBILITY']='M6-1.0'
  g=.directory~new; g['FORM']='HEX_HEAD'; g['HEAD_SIZE']='10 mm'; g['SHANK_DIAMETER']='6 mm'
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_AND_ROLLED'; mf['FINISH']='ZINC_REFERENCE'
  return .PartDefinition~new('BOLT-M6X30-8.8','FASTENER','M6 x 30 mm property-class 8.8 bolt',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method plateAl6061T6 class
  p=.directory~new
  p['LENGTH']='100 mm'; p['WIDTH']='50 mm'; p['THICKNESS']='3 mm'
  p['MASS']='40.5 g'; p['YIELD_STRESS']='276 MPa'
  m=.directory~new; m['BODY']='aluminium-6061-T6'
  g=.directory~new; g['FORM']='RECTANGULAR_PLATE'; g['VOLUME']='15000 mm3'; g['AREA']='5000 mm2'
  mf=.directory~new; mf['PROCESS']='CUT_AND_MILL'; mf['TOLERANCE']='ISO-2768-M'
  return .PartDefinition~new('PLATE-AL6061T6-100X50X3','STRUCTURAL_PLATE','100 x 50 x 3 mm aluminium reference plate',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method bearing608 class
  p=.directory~new
  p['BORE_DIAMETER']='8 mm'; p['OUTER_DIAMETER']='22 mm'; p['WIDTH']='7 mm'
  p['DYNAMIC_LOAD_RATING']='3300 N'; p['STATIC_LOAD_RATING']='1370 N'; p['LIMITING_SPEED']='34000 rpm'
  m=.directory~new; m['RINGS']='bearing-steel'; m['CAGE']='polyamide'; m['SEAL']='rubber'
  g=.directory~new; g['FORM']='DEEP_GROOVE'; g['BORE']='8 mm'; g['OUTER']='22 mm'; g['WIDTH']='7 mm'
  mf=.directory~new; mf['PROCESS']='GROUND_RINGS_AND_ASSEMBLED'; mf['LUBRICANT']='GREASE_REFERENCE'
  return .PartDefinition~new('BEARING-608-2RS','BEARING','608-2RS miniature deep-groove bearing',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method heatsinkTO220 class
  p=.directory~new
  p['THERMAL_RESISTANCE']='12 K/W'; p['MASS']='18 g'; p['MAX_DEVICE_POWER']='10 W'
  m=.directory~new; m['BODY']='aluminium-6061-T6'; m['INTERFACE']='mica-or-silicone-pad'
  g=.directory~new; g['FORM']='EXTRUDED_FIN'; g['BASE']='25 mm'; g['HEIGHT']='20 mm'
  mf=.directory~new; mf['PROCESS']='EXTRUDED_AND_CUT'; mf['MOUNT']='TO-220_CLIP_OR_SCREW'
  return .PartDefinition~new('HEATSINK-TO220-12KW','THERMAL','Generic TO-220 12 K/W heatsink',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')


::method standardBenchSet class
  d=.directory~new
  d['R_1K_5_025W']=self~resistor('1 kohm','5','0.25 W','R-1K-5-025W')
  d['R_10K_5_025W']=self~resistor('10 kohm','5','0.25 W','R-10K-5-025W')
  d['C_100NF_50V']=self~capacitor('100 nF','50 V','ceramic','C-100NF-50V')
  d['C_10UF_25V']=self~capacitor('10 uF','25 V','electrolytic','C-10UF-25V')
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
