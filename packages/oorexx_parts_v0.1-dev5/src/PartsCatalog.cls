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
  /* ISO coarse metric bolt. Geometry standard-derived; capacity derived from
   * material yield when available. headStyle: HEX | SOCKET | COUNTERSUNK */
  use strict arg nominalSize='M6', length='30 mm', materialId='STEEL-8.8-REFERENCE', headStyle='HEX'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown bolt material' materialId)
  size=nominalSize~string~upper
  select
    when size='M2'   then do; nominalDiameter='2 mm';   pitch='0.4 mm';  headAcross='4 mm';   headThickness='1.4 mm'; headAreaMm2=12.57; end
    when size='M2.5' then do; nominalDiameter='2.5 mm'; pitch='0.45 mm'; headAcross='5 mm';   headThickness='1.7 mm'; headAreaMm2=19.63; end
    when size='M3'   then do; nominalDiameter='3 mm';   pitch='0.5 mm';  headAcross='5.5 mm'; headThickness='2 mm';   headAreaMm2=28.27; end
    when size='M4'   then do; nominalDiameter='4 mm';   pitch='0.7 mm';  headAcross='7 mm';   headThickness='2.8 mm'; headAreaMm2=50.27; end
    when size='M5'   then do; nominalDiameter='5 mm';   pitch='0.8 mm';  headAcross='8 mm';   headThickness='3.5 mm'; headAreaMm2=78.54; end
    when size='M6'   then do; nominalDiameter='6 mm';   pitch='1 mm';    headAcross='10 mm';  headThickness='4 mm';   headAreaMm2=113.1; end
    when size='M8'   then do; nominalDiameter='8 mm';   pitch='1.25 mm'; headAcross='13 mm';  headThickness='5.3 mm'; headAreaMm2=201.1; end
    when size='M10'  then do; nominalDiameter='10 mm';  pitch='1.5 mm';  headAcross='16 mm';  headThickness='6.4 mm'; headAreaMm2=314.2; end
    when size='M12'  then do; nominalDiameter='12 mm';  pitch='1.75 mm'; headAcross='18 mm';  headThickness='7.5 mm'; headAreaMm2=452.4; end
    otherwise raise syntax 93.900 array('unsupported metric bolt size' nominalSize)
  end
  headStyleU=headStyle~string~upper
  select
    when headStyleU='HEX' then form='HEX_HEAD'
    when headStyleU='SOCKET' | headStyleU='SHCS' then do; form='SOCKET_HEAD'; end
    when headStyleU='COUNTERSUNK' | headStyleU='CSK' then form='COUNTERSUNK'
    otherwise raise syntax 93.900 array('unsupported head style' headStyle)
  end
  p=.directory~new
  p['NOMINAL_SIZE']=size; p['NOMINAL_DIAMETER']=nominalDiameter; p['LENGTH']=length; p['PITCH']=pitch
  p['HEAD_STYLE']=headStyleU; p['HEAD_ACROSS_FLATS']=headAcross; p['HEAD_THICKNESS']=headThickness
  p['SHANK_AREA_MM2']=headAreaMm2; p['MATERIAL_ID']=material~id
  if material~hasProperty('YIELD_STRESS') then do
    yieldStress=material~value('YIELD_STRESS')
    shearFactor=0.6
    headShearStress=yieldStress*shearFactor
    headCapacity=headShearStress*headAreaMm2/1e6
    p['HEAD_SHEAR_STRESS_PA']=headShearStress
    p['HEAD_SHEAR_CAPACITY_N']=headCapacity
    p['HEAD_SHEAR_CAPACITY']=headCapacity||' N'
  end
  m=.directory~new; m['BODY']=material~id
  g=.directory~new
  g['FORM']=form; g['HEAD_SIZE']=headAcross; g['HEAD_THICKNESS']=headThickness
  g['SHANK_DIAMETER']=nominalDiameter; g['THREAD_PITCH']=pitch
  g['NUT_COMPATIBILITY']=size||'-'||pitch~changeStr(' mm','')
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_AND_ROLLED'; mf['FINISH']='ZINC_OR_PLAIN_REFERENCE'
  pr=.directory~new
  pr['GEOMETRY']='ISO metric coarse thread geometry (representative standard dimensions)'
  pr['CAPACITY']='Head-shear capacity derived from material yield * 0.6 * shank area when yield available; not a code-checked joint capacity.'
  return .PartDefinition~new('BOLT-'||size||'X'||length~changeStr(' ','')||'-'||headStyleU||'-'||material~id,'FASTENER',size||' x '||length||' '||headStyleU||' bolt',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

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

/* ---------- fasteners (nuts, washers, rod, set screw) ------------ */

::method metricNut class
  use strict arg nominalSize='M6', materialId='STEEL-8.8-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown nut material' materialId)
  size=nominalSize~string~upper
  select
    when size='M3'  then do; pitch='0.5 mm';  across='5.5 mm'; thick='2.4 mm'; end
    when size='M4'  then do; pitch='0.7 mm';  across='7 mm';   thick='3.2 mm'; end
    when size='M5'  then do; pitch='0.8 mm';  across='8 mm';   thick='4 mm';   end
    when size='M6'  then do; pitch='1 mm';    across='10 mm';  thick='5 mm';   end
    when size='M8'  then do; pitch='1.25 mm'; across='13 mm';  thick='6.5 mm'; end
    when size='M10' then do; pitch='1.5 mm';  across='16 mm';  thick='8 mm';   end
    when size='M12' then do; pitch='1.75 mm'; across='18 mm';  thick='10 mm';  end
    otherwise raise syntax 93.900 array('unsupported metric nut size' nominalSize)
  end
  p=.directory~new; p['NOMINAL_SIZE']=size; p['PITCH']=pitch; p['ACROSS_FLATS']=across; p['THICKNESS']=thick; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='HEX_NUT'; g['ACROSS_FLATS']=across; g['THICKNESS']=thick
  mf=.directory~new; mf['PROCESS']='COLD_FORMED'
  pr=.directory~new; pr['GEOMETRY']='ISO metric coarse nut geometry (representative)'
  return .PartDefinition~new('NUT-'||size||'-'||material~id,'FASTENER',size||' hex nut',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method nylocNut class
  use strict arg nominalSize='M6', materialId='STEEL-8.8-REFERENCE'
  n=self~metricNut(nominalSize,materialId)
  n~parameters['LOCKING']='NYLON_INSERT'
  n~materials['INSERT']='PA66-GENERIC'
  n~geometry['FORM']='NYLOC_NUT'
  n~provenance['NOTE']='Nylon-insert prevailing-torque nut; insert material resolved through Materials.'
  return n

::method plainWasher class
  use strict arg nominalSize='M6', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown washer material' materialId)
  size=nominalSize~string~upper
  select
    when size='M3'  then do; iid='3.2 mm'; od='7 mm';  t='0.5 mm'; end
    when size='M4'  then do; iid='4.3 mm'; od='9 mm';  t='0.8 mm'; end
    when size='M5'  then do; iid='5.3 mm'; od='10 mm'; t='1 mm';   end
    when size='M6'  then do; iid='6.4 mm'; od='12 mm'; t='1.6 mm'; end
    when size='M8'  then do; iid='8.4 mm'; od='16 mm'; t='1.6 mm'; end
    when size='M10' then do; iid='10.5 mm';od='20 mm'; t='2 mm';   end
    when size='M12' then do; iid='13 mm';  od='24 mm'; t='2.5 mm'; end
    otherwise raise syntax 93.900 array('unsupported washer size' nominalSize)
  end
  p=.directory~new; p['NOMINAL_SIZE']=size; p['INNER_DIAMETER']=iid; p['OUTER_DIAMETER']=od; p['THICKNESS']=t; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='PLAIN_WASHER'; g['INNER']=iid; g['OUTER']=od; g['THICKNESS']=t
  mf=.directory~new; mf['PROCESS']='STAMPED'
  return .PartDefinition~new('WASHER-PLAIN-'||size||'-'||material~id,'FASTENER',size||' plain washer',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method springWasher class
  use strict arg nominalSize='M6', materialId='STEEL-MILD-REFERENCE'
  w=self~plainWasher(nominalSize,materialId)
  w~parameters['TYPE']='SPRING_LOCK'
  w~geometry['FORM']='SPRING_WASHER'
  w~provenance['NOTE']='Helical spring lock washer; preload retention belongs to joint model.'
  return w

::method threadedRod class
  use strict arg nominalSize='M6', length='1000 mm', materialId='STEEL-8.8-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown threaded-rod material' materialId)
  size=nominalSize~string~upper
  select
    when size='M6'  then pitch='1 mm'
    when size='M8'  then pitch='1.25 mm'
    when size='M10' then pitch='1.5 mm'
    when size='M12' then pitch='1.75 mm'
    otherwise raise syntax 93.900 array('unsupported threaded rod size' nominalSize)
  end
  p=.directory~new; p['NOMINAL_SIZE']=size; p['LENGTH']=length; p['PITCH']=pitch; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='THREADED_ROD'; g['DIAMETER']=size; g['PITCH']=pitch; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='ROLLED_THREAD'
  return .PartDefinition~new('ROD-'||size||'X'||length~changeStr(' ','')||'-'||material~id,'FASTENER',size||' threaded rod',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method setScrew class
  use strict arg nominalSize='M4', length='8 mm', materialId='STEEL-8.8-REFERENCE', point='CUP'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown set-screw material' materialId)
  p=.directory~new; p['NOMINAL_SIZE']=nominalSize~upper; p['LENGTH']=length; p['POINT']=point~upper; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='SET_SCREW'; g['POINT']=point~upper
  mf=.directory~new; mf['PROCESS']='COLD_FORMED'
  return .PartDefinition~new('SETSCREW-'||nominalSize~upper||'X'||length~changeStr(' ','')||'-'||point~upper,'FASTENER','Set / grub screw',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

/* ---------- shaft / motion hardware ------------------------------ */

::method shaftCollar class
  use strict arg bore='8 mm', outer='16 mm', width='8 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown collar material' materialId)
  p=.directory~new; p['BORE']=bore; p['OUTER']=outer; p['WIDTH']=width; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='SHAFT_COLLAR'; g['BORE']=bore; g['OUTER']=outer; g['WIDTH']=width
  mf=.directory~new; mf['PROCESS']='MACHINED'
  return .PartDefinition~new('COLLAR-'||bore~changeStr(' ','')||'-'||material~id,'SHAFT_HARDWARE','Shaft collar',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method keyStock class
  use strict arg width='3 mm', height='3 mm', length='20 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown key material' materialId)
  p=.directory~new; p['WIDTH']=width; p['HEIGHT']=height; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='SQUARE_KEY'; g['WIDTH']=width; g['HEIGHT']=height; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='DRAWN_KEYSTOCK'
  return .PartDefinition~new('KEY-'||width~changeStr(' ','')||'X'||height~changeStr(' ','')||'X'||length~changeStr(' ',''),'SHAFT_HARDWARE','Metric key stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method rigidCoupler class
  use strict arg boreA='5 mm', boreB='5 mm', length='25 mm', outer='15 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown coupler material' materialId)
  p=.directory~new; p['BORE_A']=boreA; p['BORE_B']=boreB; p['LENGTH']=length; p['OUTER']=outer; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='RIGID_COUPLER'; g['BORE_A']=boreA; g['BORE_B']=boreB
  mf=.directory~new; mf['PROCESS']='MACHINED'
  return .PartDefinition~new('COUPLER-RIGID-'||boreA~changeStr(' ','')||'-'||boreB~changeStr(' ',''),'COUPLER','Rigid shaft coupler',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method flexibleCoupler class
  use strict arg boreA='5 mm', boreB='5 mm', length='25 mm', type='BEAM', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown coupler material' materialId)
  p=.directory~new; p['BORE_A']=boreA; p['BORE_B']=boreB; p['LENGTH']=length; p['TYPE']=type~upper; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='FLEXIBLE_COUPLER'; g['TYPE']=type~upper
  mf=.directory~new; mf['PROCESS']='MACHINED_OR_MOULDED'
  pr=.directory~new; pr['NOTE']='Flexible coupler geometry; torsional stiffness belongs to Physics continuum model.'
  return .PartDefinition~new('COUPLER-FLEX-'||type~upper||'-'||boreA~changeStr(' ',''),'COUPLER','Flexible shaft coupler ('||type||')',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method jawCoupler class
  use strict arg boreA='8 mm', boreB='8 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown coupler material' materialId)
  p=.directory~new; p['BORE_A']=boreA; p['BORE_B']=boreB; p['TYPE']='JAW'; p['MATERIAL_ID']=material~id
  m=.directory~new; m['HUB']=material~id; m['SPIDER']='RUBBER-GENERIC'
  g=.directory~new; g['FORM']='JAW_COUPLER'
  mf=.directory~new; mf['PROCESS']='MACHINED_AND_MOULDED'
  return .PartDefinition~new('COUPLER-JAW-'||boreA~changeStr(' ',''),'COUPLER','Jaw / spider coupler',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method leadScrew class
  use strict arg diameter='8 mm', pitch='2 mm', length='300 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown leadscrew material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['PITCH']=pitch; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='LEAD_SCREW'; g['DIAMETER']=diameter; g['PITCH']=pitch; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='ROLLED_OR_MACHINED_THREAD'
  pr=.directory~new; pr['NOTE']='Lead/pitch geometry; efficiency and wear belong to Physical Manufacturing / Physics.'
  return .PartDefinition~new('LEADSCREW-'||diameter~changeStr(' ','')||'X'||pitch~changeStr(' ',''),'LEAD_SCREW','Metric lead screw / threaded spindle',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method gt2Belt class
  use strict arg length='200 mm', width='6 mm', id='GT2-BELT-200-6'
  p=.directory~new; p['PITCH']='2 mm'; p['LENGTH']=length; p['WIDTH']=width; p['TOOTH_PROFILE']='GT2'
  m=.directory~new; m['BODY']='RUBBER-GENERIC'; m['CORD']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='TIMING_BELT'; g['PITCH']='2 mm'; g['WIDTH']=width; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='MOULDED_BELT'
  pr=.directory~new; pr['NOTE']='GT2 geometry; tension/wrap kinematics belong to Physics World.'
  return .PartDefinition~new(id,'TIMING_BELT','GT2 timing belt',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method gt2Pulley class
  use strict arg teeth=20, bore='5 mm', width='6 mm', id=.nil
  if id=.nil then id='GT2-PULLEY-'||teeth||'T'
  p=.directory~new; p['TEETH']=teeth; p['PITCH']='2 mm'; p['BORE']=bore; p['WIDTH']=width; p['TOOTH_PROFILE']='GT2'
  m=.directory~new; m['BODY']='AL-6061-T6'
  g=.directory~new; g['FORM']='TIMING_PULLEY'; g['TEETH']=teeth; g['PITCH']='2 mm'; g['BORE']=bore
  pitchDia = teeth * 2 / 3.14159265
  g['PITCH_DIAMETER']=pitchDia~format(,,2)||' mm'
  mf=.directory~new; mf['PROCESS']='MACHINED'
  pr=.directory~new; pr['NOTE']='GT2 pulley geometry; pitch diameter derived from tooth count * 2 mm / pi.'
  return .PartDefinition~new(id,'TIMING_PULLEY','GT2 '||teeth||'T timing pulley',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method spurGear class
  use strict arg module=1, teeth=20, faceWidth='10 mm', bore='5 mm', pressureAngle='20 deg', id=.nil
  if id=.nil then id='GEAR-SPUR-M'||module||'-Z'||teeth
  p=.directory~new; p['MODULE']=module; p['TEETH']=teeth; p['FACE_WIDTH']=faceWidth; p['BORE']=bore; p['PRESSURE_ANGLE']=pressureAngle
  m=.directory~new; m['BODY']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='SPUR_GEAR'; g['MODULE']=module; g['TEETH']=teeth; g['FACE_WIDTH']=faceWidth
  pitchDia = module * teeth
  g['PITCH_DIAMETER']=pitchDia||' mm'
  mf=.directory~new; mf['PROCESS']='HOBBED_OR_MACHINED'
  pr=.directory~new; pr['NOTE']='Spur-gear geometry. Contact force, efficiency and backlash belong to Physics World gear-mesh layer.'
  return .PartDefinition~new(id,'GEAR','Spur gear m='||module||' Z='||teeth,p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method rack class
  use strict arg module=1, length='200 mm', faceWidth='10 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown rack material' materialId)
  p=.directory~new; p['MODULE']=module; p['LENGTH']=length; p['FACE_WIDTH']=faceWidth; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='RACK'; g['MODULE']=module; g['LENGTH']=length; g['FACE_WIDTH']=faceWidth
  mf=.directory~new; mf['PROCESS']='MACHINED'
  pr=.directory~new; pr['NOTE']='Rack geometry; mesh kinematics belong to Physics World.'
  return .PartDefinition~new('RACK-M'||module||'-'||length~changeStr(' ',''),'GEAR','Spur rack m='||module,p,m,g,mf,pr,'ENGINEERING_REFERENCE')

/* ---------- additional springs ----------------------------------- */

::method extensionSpring class
  use strict arg wireDiameter='1 mm', meanCoilDiameter='10 mm', activeTurns=20, freeLength='40 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown spring material' materialId)
  p=.directory~new
  p['WIRE_DIAMETER']=wireDiameter; p['MEAN_COIL_DIAMETER']=meanCoilDiameter
  p['ACTIVE_TURNS']=activeTurns; p['FREE_LENGTH']=freeLength; p['MATERIAL_ID']=material~id
  m=.directory~new; m['WIRE']=material~id
  g=.directory~new; g['FORM']='HELICAL_EXTENSION'; g['WIRE_DIAMETER']=wireDiameter; g['MEAN_COIL_DIAMETER']=meanCoilDiameter
  mf=.directory~new; mf['PROCESS']='COLD_COILED_REFERENCE'
  pr=.directory~new; pr['NOTE']='Geometry only; rate derivation belongs to Physics.'
  return .PartDefinition~new('SPRING-EXT-'||wireDiameter~changeStr(' ','')||'-N'||activeTurns,'SPRING','Parameterised helical extension spring',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method torsionSpring class
  use strict arg wireDiameter='1.5 mm', meanCoilDiameter='12 mm', activeTurns=5, legLength='30 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown spring material' materialId)
  p=.directory~new
  p['WIRE_DIAMETER']=wireDiameter; p['MEAN_COIL_DIAMETER']=meanCoilDiameter
  p['ACTIVE_TURNS']=activeTurns; p['LEG_LENGTH']=legLength; p['MATERIAL_ID']=material~id
  m=.directory~new; m['WIRE']=material~id
  g=.directory~new; g['FORM']='HELICAL_TORSION'; g['WIRE_DIAMETER']=wireDiameter; g['MEAN_COIL_DIAMETER']=meanCoilDiameter
  mf=.directory~new; mf['PROCESS']='COLD_COILED_REFERENCE'
  pr=.directory~new; pr['NOTE']='Geometry only; torsional rate belongs to Physics.'
  return .PartDefinition~new('SPRING-TORSION-'||wireDiameter~changeStr(' ','')||'-N'||activeTurns,'SPRING','Parameterised helical torsion spring',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

/* ---------- structural stock ------------------------------------- */

::method roundBar class
  use strict arg diameter='10 mm', length='300 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown bar material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='ROUND_BAR'; g['DIAMETER']=diameter; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='BAR_STOCK'
  return .PartDefinition~new('BAR-ROUND-'||diameter~changeStr(' ','')||'-'||material~id,'STRUCTURAL_BAR','Round bar stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method squareBar class
  use strict arg side='10 mm', length='300 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown bar material' materialId)
  p=.directory~new; p['SIDE']=side; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='SQUARE_BAR'; g['SIDE']=side; g['LENGTH']=length
  mf=.directory~new; mf['PROCESS']='BAR_STOCK'
  return .PartDefinition~new('BAR-SQUARE-'||side~changeStr(' ','')||'-'||material~id,'STRUCTURAL_BAR','Square bar stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method angleStock class
  use strict arg legA='25 mm', legB='25 mm', thickness='3 mm', length='300 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown angle material' materialId)
  p=.directory~new; p['LEG_A']=legA; p['LEG_B']=legB; p['THICKNESS']=thickness; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='ANGLE'; g['LEG_A']=legA; g['LEG_B']=legB; g['THICKNESS']=thickness
  mf=.directory~new; mf['PROCESS']='ROLLED_OR_EXTRUDED'
  return .PartDefinition~new('ANGLE-'||legA~changeStr(' ','')||'X'||legB~changeStr(' ','')||'X'||thickness~changeStr(' ',''),'STRUCTURAL_ANGLE','Equal/unequal angle stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method squareHollowSection class
  use strict arg side='20 mm', thickness='2 mm', length='300 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown SHS material' materialId)
  p=.directory~new; p['SIDE']=side; p['THICKNESS']=thickness; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='SHS'; g['SIDE']=side; g['THICKNESS']=thickness
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_OR_HOT_FINISHED'
  return .PartDefinition~new('SHS-'||side~changeStr(' ','')||'X'||thickness~changeStr(' ',''),'STRUCTURAL_TUBE','Square hollow section',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method rectangularHollowSection class
  use strict arg height='40 mm', width='20 mm', thickness='2 mm', length='300 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown RHS material' materialId)
  p=.directory~new; p['HEIGHT']=height; p['WIDTH']=width; p['THICKNESS']=thickness; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='RHS'; g['HEIGHT']=height; g['WIDTH']=width; g['THICKNESS']=thickness
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_OR_HOT_FINISHED'
  return .PartDefinition~new('RHS-'||height~changeStr(' ','')||'X'||width~changeStr(' ','')||'X'||thickness~changeStr(' ',''),'STRUCTURAL_TUBE','Rectangular hollow section',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

::method tube class
  use strict arg outerDiameter='20 mm', wallThickness='1.5 mm', length='300 mm', materialId='AL-6061-T6'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown tube material' materialId)
  p=.directory~new; p['OUTER_DIAMETER']=outerDiameter; p['WALL_THICKNESS']=wallThickness; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='ROUND_TUBE'; g['OUTER_DIAMETER']=outerDiameter; g['WALL_THICKNESS']=wallThickness
  mf=.directory~new; mf['PROCESS']='EXTRUDED_OR_DRAWN'
  return .PartDefinition~new('TUBE-'||outerDiameter~changeStr(' ','')||'X'||wallThickness~changeStr(' ',''),'STRUCTURAL_TUBE','Round tube stock',p,m,g,mf,.nil,'ENGINEERING_REFERENCE')

/* ---------- packages --------------------------------------------- */

::method packageDIP class
  use strict arg pins=14, pitch='2.54 mm', id=.nil
  if id=.nil then id='PKG-DIP-'||pins
  p=.directory~new; p['PINS']=pins; p['PITCH']=pitch
  m=.directory~new; m['BODY']='EPOXY-GENERIC'; m['LEADFRAME']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='DIP'; g['PINS']=pins; g['PITCH']=pitch
  mf=.directory~new; mf['PROCESS']='IC_PACKAGE'; mf['TERMINATION']='THROUGH-HOLE'
  pr=.directory~new; pr['NOTE']='Physical package definition only; electrical function is independent.'
  return .PartDefinition~new(id,'PACKAGE','DIP-'||pins||' package',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method packageTO220 class
  p=.directory~new; p['TERMINALS']=3
  m=.directory~new; m['BODY']='EPOXY-GENERIC'; m['LEAD']='CU-ALLOY-GENERIC'; m['TAB']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='TO-220'; g['TERMINALS']=3; g['MOUNTING_HOLE']='3.5 mm'
  mf=.directory~new; mf['PROCESS']='IC_PACKAGE'; mf['TERMINATION']='THROUGH-HOLE'
  return .PartDefinition~new('PKG-TO-220','PACKAGE','TO-220 package',p,m,g,mf,.nil,'STANDARD_GEOMETRY')

::method packageChip class
  use strict arg size='0805', id=.nil
  if id=.nil then id='PKG-'||size
  select
    when size='0603' then do; l='1.6 mm'; w='0.8 mm'; end
    when size='0805' then do; l='2.0 mm'; w='1.25 mm'; end
    when size='1206' then do; l='3.2 mm'; w='1.6 mm'; end
    otherwise raise syntax 93.900 array('unsupported chip package size' size)
  end
  p=.directory~new; p['SIZE']=size
  m=.directory~new; m['BODY']='RESISTOR-BODY-GENERIC'; m['TERMINATION']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='CHIP'; g['LENGTH']=l; g['WIDTH']=w
  mf=.directory~new; mf['PROCESS']='CHIP_COMPONENT'; mf['TERMINATION']='SMD'
  return .PartDefinition~new(id,'PACKAGE',size||' chip package',p,m,g,mf,.nil,'STANDARD_GEOMETRY')

/* ---------- electromechanical actuators -------------------------- */

::method brushedDCMotor class
  use strict arg voltage='12 V', noLoadSpeed='3000 rpm', stallTorque='0.05 N.m', id='MOTOR-DC-12V'
  p=.directory~new
  p['VOLTAGE_RATING']=voltage; p['NO_LOAD_SPEED']=noLoadSpeed; p['STALL_TORQUE']=stallTorque
  p['NO_LOAD_CURRENT']='0.1 A'; p['STALL_CURRENT']='1.5 A'
  m=.directory~new; m['WINDING']='CU-C110-REFERENCE'; m['MAGNET']='FERRITE-GENERIC'; m['SHAFT']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='BRUSHED_DC'; g['SHAFT_DIAMETER']='3 mm'
  mf=.directory~new; mf['PROCESS']='MOTOR_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Catalogue electrical/mechanical ratings; torque/speed curve from magnetic model belongs to Physics/Rexx-tronics.'
  return .PartDefinition~new(id,'MOTOR','Generic brushed DC motor',p,m,g,mf,pr,'GENERIC')

::method gearedDCMotor class
  use strict arg voltage='6 V', gearRatio=48, outputSpeed='120 rpm', id='MOTOR-GEARED-6V'
  p=.directory~new
  p['VOLTAGE_RATING']=voltage; p['GEAR_RATIO']=gearRatio; p['OUTPUT_SPEED']=outputSpeed; p['OUTPUT_TORQUE']='0.2 N.m'
  m=.directory~new; m['WINDING']='CU-C110-REFERENCE'; m['GEARS']='PA66-GENERIC'; m['SHAFT']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='GEARED_DC'; g['SHAFT_DIAMETER']='4 mm'
  mf=.directory~new; mf['PROCESS']='GEARED_MOTOR_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Ratings are representative; gear-mesh physics belongs to Physics World.'
  return .PartDefinition~new(id,'MOTOR','Generic small geared DC motor',p,m,g,mf,pr,'GENERIC')

::method nema17Stepper class
  use strict arg current='1.5 A', holdingTorque='0.4 N.m', id='STEPPER-NEMA17'
  p=.directory~new
  p['CURRENT_PER_PHASE']=current; p['HOLDING_TORQUE']=holdingTorque; p['STEP_ANGLE']='1.8 deg'
  p['PHASES']=2; p['VOLTAGE_RATING']='12 V'
  m=.directory~new; m['WINDING']='CU-C110-REFERENCE'; m['MAGNET']='FERRITE-GENERIC'; m['SHAFT']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='NEMA17'; g['FACE']='42 mm'; g['SHAFT_DIAMETER']='5 mm'; g['LENGTH']='40 mm'
  mf=.directory~new; mf['PROCESS']='STEPPER_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='NEMA 17 envelope and representative ratings; commutation/magnetic model belongs to Physics/Rexx-tronics.'
  return .PartDefinition~new(id,'STEPPER','Representative NEMA 17 hybrid stepper motor',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method hobbyServo class
  use strict arg voltage='5 V', torque='1.5 kg.cm', id='SERVO-HOBBY-9G'
  p=.directory~new; p['VOLTAGE_RATING']=voltage; p['TORQUE']=torque; p['SPEED']='0.1 s/60deg'
  m=.directory~new; m['GEARS']='PA66-GENERIC'; m['CASE']='ABS-GENERIC'
  g=.directory~new; g['FORM']='HOBBY_SERVO'; g['SIZE']='9g-class'
  mf=.directory~new; mf['PROCESS']='SERVO_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Catalogue ratings only; position-control behaviour belongs to electromechanics model.'
  return .PartDefinition~new(id,'SERVO','Generic small hobby servo',p,m,g,mf,pr,'GENERIC')

::method solenoid class
  use strict arg coilVoltage='12 V', stroke='10 mm', force='5 N', id='SOLENOID-12V'
  p=.directory~new; p['COIL_VOLTAGE']=coilVoltage; p['STROKE']=stroke; p['FORCE_RATING']=force
  m=.directory~new; m['COIL']='CU-C110-REFERENCE'; m['PLUNGER']='STEEL-MILD-REFERENCE'; m['BODY']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='LINEAR_SOLENOID'; g['STROKE']=stroke
  mf=.directory~new; mf['PROCESS']='SOLENOID_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Force/stroke are catalogue ratings; magnetic-circuit solution belongs to Physics/Rexx-tronics.'
  return .PartDefinition~new(id,'SOLENOID','Generic linear solenoid',p,m,g,mf,pr,'GENERIC')

::method relayPCB class
  use strict arg coilVoltage='5 V', contactCurrent='10 A', id='RELAY-PCB-5V'
  p=.directory~new; p['COIL_VOLTAGE']=coilVoltage; p['CONTACT_CURRENT']=contactCurrent; p['CONTACT_FORM']='SPDT'
  m=.directory~new; m['COIL']='CU-C110-REFERENCE'; m['CONTACT']='CU-ALLOY-GENERIC'; m['BODY']='ABS-GENERIC'
  g=.directory~new; g['FORM']='PCB_RELAY'
  mf=.directory~new; mf['PROCESS']='RELAY_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Coil/contact ratings are representative; magnetic behaviour belongs to electromechanics model.'
  return .PartDefinition~new(id,'RELAY','Generic PCB relay',p,m,g,mf,pr,'GENERIC')

/* ---------- thermal extras --------------------------------------- */

::method thermalPad class
  use strict arg thickness='0.5 mm', conductivity='1.5 W/(m.K)', id='THERMAL-PAD-0.5'
  p=.directory~new; p['THICKNESS']=thickness; p['THERMAL_CONDUCTIVITY']=conductivity
  m=.directory~new; m['BODY']='THERMAL-INTERFACE-GENERIC'
  g=.directory~new; g['FORM']='THERMAL_PAD'; g['THICKNESS']=thickness
  mf=.directory~new; mf['PROCESS']='DIE_CUT'
  pr=.directory~new; pr['NOTE']='Conductivity is representative; interface resistance chain belongs to Physics thermal path.'
  return .PartDefinition~new(id,'THERMAL','Generic thermal pad',p,m,g,mf,pr,'GENERIC')

::method thermalPaste class
  use strict arg conductivity='4 W/(m.K)', id='THERMAL-PASTE-GENERIC'
  p=.directory~new; p['THERMAL_CONDUCTIVITY']=conductivity; p['LAYER_THICKNESS_TYPICAL']='0.05 mm'
  m=.directory~new; m['BODY']='THERMAL-INTERFACE-GENERIC'
  g=.directory~new; g['FORM']='THERMAL_PASTE_LAYER'
  mf=.directory~new; mf['PROCESS']='DISPENSED'
  pr=.directory~new; pr['NOTE']='Catalogue interface material; continuum conduction belongs to Physics.'
  return .PartDefinition~new(id,'THERMAL','Generic thermal paste / grease layer',p,m,g,mf,pr,'GENERIC')

/* ---------- manufacturing tooling -------------------------------- */

::method drillBit class
  use strict arg diameter='5 mm', length='80 mm', materialId='STEEL-MILD-REFERENCE', pointAngle='118 deg'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown drill material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['LENGTH']=length; p['POINT_ANGLE']=pointAngle; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='TWIST_DRILL'; g['DIAMETER']=diameter; g['POINT_ANGLE']=pointAngle
  mf=.directory~new; mf['PROCESS']='GROUND_TOOL'
  pr=.directory~new; pr['NOTE']='Drill geometry only. Cutting force, chip load and wear belong to Physical Manufacturing.'
  return .PartDefinition~new('DRILL-'||diameter~changeStr(' ',''),'CUTTING_TOOL','Twist drill bit',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method endMill class
  use strict arg diameter='6 mm', flutes=4, length='50 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown end-mill material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['FLUTES']=flutes; p['LENGTH']=length; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='END_MILL'; g['DIAMETER']=diameter; g['FLUTES']=flutes
  mf=.directory~new; mf['PROCESS']='GROUND_TOOL'
  pr=.directory~new; pr['NOTE']='Geometry only; material-removal physics belongs to Physical Manufacturing.'
  return .PartDefinition~new('ENDMILL-'||diameter~changeStr(' ','')||'-F'||flutes,'CUTTING_TOOL','End mill',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method latheInsert class
  use strict arg shape='CNMG', size='12', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown insert material' materialId)
  p=.directory~new; p['SHAPE']=shape; p['SIZE']=size; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='INDEXABLE_INSERT'; g['SHAPE']=shape
  mf=.directory~new; mf['PROCESS']='SINTERED_OR_GROUND'
  pr=.directory~new; pr['NOTE']='Insert geometry; cutting-force model belongs to Physical Manufacturing.'
  return .PartDefinition~new('INSERT-'||shape||'-'||size,'CUTTING_TOOL','Lathe turning insert',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

::method sawBlade class
  use strict arg diameter='150 mm', teeth=40, kerf='1.5 mm', materialId='STEEL-MILD-REFERENCE'
  material=.CommonMaterials~byId(materialId)
  if material=.nil then raise syntax 93.900 array('unknown blade material' materialId)
  p=.directory~new; p['DIAMETER']=diameter; p['TEETH']=teeth; p['KERF']=kerf; p['MATERIAL_ID']=material~id
  m=.directory~new; m['BODY']=material~id
  g=.directory~new; g['FORM']='CIRCULAR_SAW'; g['DIAMETER']=diameter; g['TEETH']=teeth; g['KERF']=kerf
  mf=.directory~new; mf['PROCESS']='STAMPED_AND_GROUND'
  pr=.directory~new; pr['NOTE']='Geometry only; cutting physics belongs to Physical Manufacturing.'
  return .PartDefinition~new('SAW-'||diameter~changeStr(' ','')||'-T'||teeth,'CUTTING_TOOL','Circular saw blade',p,m,g,mf,pr,'ENGINEERING_REFERENCE')

/* ---------- sensors / batteries ---------------------------------- */

::method thermocouple class
  use strict arg type='K', id='TC-TYPE-K'
  p=.directory~new; p['TYPE']=type~upper; p['RANGE']='-200..1350 C'
  m=.directory~new; m['POSITIVE']='CU-ALLOY-GENERIC'; m['NEGATIVE']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='THERMOCOUPLE_JUNCTION'
  mf=.directory~new; mf['PROCESS']='WELDED_JUNCTION'
  pr=.directory~new; pr['NOTE']='Type and range only; Seebeck transfer function belongs to sensor behavioural model.'
  return .PartDefinition~new(id,'SENSOR','Type '||type~upper||' thermocouple',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method rtdPT100 class
  use strict arg id='RTD-PT100'
  p=.directory~new; p['R0']='100 Ohm'; p['ALPHA']='0.00385 /K'; p['STANDARD']='IEC 60751'
  m=.directory~new; m['ELEMENT']='CU-ALLOY-GENERIC'; m['LEAD']='CU-C110-REFERENCE'
  g=.directory~new; g['FORM']='RTD_ELEMENT'
  mf=.directory~new; mf['PROCESS']='SENSOR_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='PT100 catalogue definition; resistance-temperature transfer belongs to sensor model.'
  return .PartDefinition~new(id,'SENSOR','PT100 RTD',p,m,g,mf,pr,'STANDARD_GEOMETRY')

::method strainGauge class
  use strict arg resistance='350 Ohm', gaugeFactor=2.0, id='STRAIN-GAUGE-350'
  p=.directory~new; p['RESISTANCE']=resistance; p['GAUGE_FACTOR']=gaugeFactor
  m=.directory~new; m['FOIL']='CU-ALLOY-GENERIC'; m['CARRIER']='PA66-GENERIC'
  g=.directory~new; g['FORM']='FOIL_STRAIN_GAUGE'
  mf=.directory~new; mf['PROCESS']='GAUGE_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Gauge factor is representative; strain-to-resistance belongs to sensor model.'
  return .PartDefinition~new(id,'SENSOR','Foil strain gauge',p,m,g,mf,pr,'GENERIC')

::method loadCell class
  use strict arg capacity='5 kg', output='1 mV/V', id='LOADCELL-5KG'
  p=.directory~new; p['CAPACITY']=capacity; p['RATED_OUTPUT']=output; p['BRIDGE_RESISTANCE']='350 Ohm'
  m=.directory~new; m['BODY']='AL-6061-T6'; m['GAUGE']='CU-ALLOY-GENERIC'
  g=.directory~new; g['FORM']='SINGLE_POINT_OR_S_BEAM'
  mf=.directory~new; mf['PROCESS']='LOAD_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Capacity and rated output are catalogue ratings; structural/strain behaviour belongs to Physics + sensor model.'
  return .PartDefinition~new(id,'SENSOR','Generic load cell',p,m,g,mf,pr,'GENERIC')

::method batteryAA class
  use strict arg chemistry='ALKALINE', id='BATT-AA-ALKALINE'
  p=.directory~new; p['CHEMISTRY']=chemistry; p['NOMINAL_VOLTAGE']='1.5 V'; p['CAPACITY']='2000 mAh'; p['FORM_FACTOR']='AA'
  m=.directory~new; m['CASE']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='AA_CELL'; g['DIAMETER']='14.5 mm'; g['HEIGHT']='50.5 mm'
  mf=.directory~new; mf['PROCESS']='PRIMARY_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Physical/rating catalogue only. Discharge curve, internal resistance and SoC belong to battery behavioural model.'
  return .PartDefinition~new(id,'BATTERY','AA alkaline cell',p,m,g,mf,pr,'COMMON')

::method batteryAAA class
  use strict arg chemistry='ALKALINE', id='BATT-AAA-ALKALINE'
  p=.directory~new; p['CHEMISTRY']=chemistry; p['NOMINAL_VOLTAGE']='1.5 V'; p['CAPACITY']='1000 mAh'; p['FORM_FACTOR']='AAA'
  m=.directory~new; m['CASE']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='AAA_CELL'; g['DIAMETER']='10.5 mm'; g['HEIGHT']='44.5 mm'
  mf=.directory~new; mf['PROCESS']='PRIMARY_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Physical/rating catalogue only.'
  return .PartDefinition~new(id,'BATTERY','AAA alkaline cell',p,m,g,mf,pr,'COMMON')

::method batteryCR2032 class
  p=.directory~new; p['CHEMISTRY']='LI-MNO2'; p['NOMINAL_VOLTAGE']='3 V'; p['CAPACITY']='220 mAh'; p['FORM_FACTOR']='CR2032'
  m=.directory~new; m['CASE']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='COIN_CELL'; g['DIAMETER']='20 mm'; g['HEIGHT']='3.2 mm'
  mf=.directory~new; mf['PROCESS']='COIN_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Physical/rating catalogue only.'
  return .PartDefinition~new('BATT-CR2032','BATTERY','CR2032 lithium coin cell',p,m,g,mf,pr,'COMMON')

::method battery18650 class
  use strict arg capacity='2600 mAh', id='BATT-18650-GENERIC'
  p=.directory~new; p['CHEMISTRY']='LI-ION'; p['NOMINAL_VOLTAGE']='3.7 V'; p['CAPACITY']=capacity; p['FORM_FACTOR']='18650'
  p['MAX_CONTINUOUS_CURRENT']='5 A'
  m=.directory~new; m['CASE']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='18650_CELL'; g['DIAMETER']='18 mm'; g['HEIGHT']='65 mm'
  mf=.directory~new; mf['PROCESS']='LIION_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Representative 18650 geometry and ratings. Dynamic discharge belongs to battery behavioural package.'
  return .PartDefinition~new(id,'BATTERY','Representative 18650 Li-ion cell',p,m,g,mf,pr,'GENERIC')

::method batteryPP3 class
  p=.directory~new; p['CHEMISTRY']='ALKALINE'; p['NOMINAL_VOLTAGE']='9 V'; p['CAPACITY']='500 mAh'; p['FORM_FACTOR']='PP3'
  m=.directory~new; m['CASE']='STEEL-MILD-REFERENCE'
  g=.directory~new; g['FORM']='PP3'; g['HEIGHT']='48.5 mm'; g['WIDTH']='26.5 mm'; g['DEPTH']='17.5 mm'
  mf=.directory~new; mf['PROCESS']='PRIMARY_CELL_ASSEMBLY'
  pr=.directory~new; pr['NOTE']='Physical/rating catalogue only.'
  return .PartDefinition~new('BATT-PP3-9V','BATTERY','9 V PP3 alkaline battery',p,m,g,mf,pr,'COMMON')

/* ---------- expanded bench set ----------------------------------- */

::method standardBenchSet class
  d=.directory~new
  /* Passives */
  d['R_1K_5_025W']=self~resistor('1 kohm','5','0.25 W','R-1K-5-025W')
  d['R_10K_5_025W']=self~resistor('10 kohm','5','0.25 W','R-10K-5-025W')
  d['C_100NF_50V']=self~capacitor('100 nF','50 V','FR4-GENERIC','C-100NF-50V')
  d['C_10UF_25V']=self~capacitor('10 uF','25 V','FR4-GENERIC','C-10UF-25V')
  d['L_10MH']=self~inductor('10 mH','0.1 A','L-10MH')
  /* Semiconductors */
  d['1N4148']=self~diode1N4148
  d['1N4007']=self~diode1N4007
  d['LED_RED_5MM']=self~ledRed5mm
  d['ZENER_5V1']=self~zener5V1
  d['2N2222']=self~transistor2N2222
  d['7SEG_RED_CC']=self~sevenSegmentRed
  /* Electromechanical */
  d['POT_10K']=self~potentiometer('10 kOhm',0.5,'POT-10K')
  d['SW_SPST']=self~switchSPST(.false,'SW-SPST')
  d['RELAY_PCB_5V']=self~relayPCB
  d['MOTOR_DC_12V']=self~brushedDCMotor
  d['STEPPER_NEMA17']=self~nema17Stepper
  d['SERVO_9G']=self~hobbyServo
  d['SOLENOID_12V']=self~solenoid
  /* Mechanical fasteners */
  d['BOLT_M6X30']=self~boltM6x30
  d['BOLT_M6X30_SS304']=self~boltM6x30('SS-304-REFERENCE')
  d['BOLT_M6X30_AL6061']=self~boltM6x30('AL-6061-T6')
  d['NUT_M6']=self~metricNut('M6')
  d['NYLOC_M6']=self~nylocNut('M6')
  d['WASHER_M6']=self~plainWasher('M6')
  d['SPRING_WASHER_M6']=self~springWasher('M6')
  /* Structural / motion */
  d['PLATE_AL6061T6']=self~plateAl6061T6
  d['BEARING_608']=self~bearing608
  d['SHAFT_8MM']=self~roundShaft('8 mm','100 mm')
  d['COLLAR_8MM']=self~shaftCollar('8 mm')
  d['SPRING_COMP']=self~compressionSpring
  d['SPRING_EXT']=self~extensionSpring
  d['GT2_PULLEY_20T']=self~gt2Pulley(20)
  d['GT2_BELT_200']=self~gt2Belt
  d['GEAR_SPUR_M1_Z20']=self~spurGear(1,20)
  d['COUPLER_RIGID_5']=self~rigidCoupler
  /* Thermal / power / sensors / tools */
  d['HEATSINK_TO220']=self~heatsinkTO220
  d['THERMAL_PAD']=self~thermalPad
  d['BATT_AA']=self~batteryAA
  d['BATT_18650']=self~battery18650
  d['TC_K']=self~thermocouple('K')
  d['RTD_PT100']=self~rtdPT100
  d['DRILL_5MM']=self~drillBit('5 mm')
  d['ENDMILL_6MM']=self~endMill('6 mm')
  d['PKG_DIP14']=self~packageDIP(14)
  d['PKG_TO220']=self~packageTO220
  d['PKG_0805']=self~packageChip('0805')
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
