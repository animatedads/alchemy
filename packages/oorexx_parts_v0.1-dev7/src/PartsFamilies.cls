/* Parameterised physical catalogue families.  These return the existing
   PartDefinition type; they do not implement behaviour or mutate definitions. */
::class CommonPartFamilies public

::method material class
  use strict arg materialId
  m=.CommonMaterials~byId(materialId)
  if m=.nil then raise syntax 93.900 array('unresolved material id' materialId)
  return m

::method q class
  use strict arg value,unit
  return .Units~q(value,unit)

::method metricFastener class
  use strict arg size='M6',lengthMm=30,style='HEX_BOLT',propertyClass='8.8',materialId=.nil
  s=size~string~upper; pc=propertyClass~string
  if materialId=.nil then do
    if pc='4.8' then materialId='STEEL-4.8-REFERENCE'
    else if pc='8.8' then materialId='STEEL-8.8-REFERENCE'
    else if pc='10.9' then materialId='STEEL-10.9-REFERENCE'
    else if pc='12.9' then materialId='STEEL-12.9-REFERENCE'
    else raise syntax 93.900 array('unsupported fastener property class' pc)
  end
  mat=self~material(materialId)
  p=.directory~new; p['NOMINAL_SIZE']=s; p['LENGTH']=self~q(lengthMm,.Units~millimetre); p['MATERIAL_ID']=mat~id; p['PROPERTY_CLASS']=pc
  p['PITCH']=self~q(self~pitch(s),.Units~millimetre); p['THREADED_LENGTH']=self~q(lengthMm-6,.Units~millimetre)
  p['HEAD_SHEAR_CAPACITY_N']=self~headCapacity(s,mat)
  p['HEAD_SHEAR_AREA']=self~q(self~headArea(s),.Units~millimetre~power(2))
  m=.directory~new; m['BODY']=mat~id
  g=.directory~new; g['STYLE']=style~string~upper; g['NOMINAL_DIAMETER']=self~q(self~diameter(s),.Units~millimetre); g['HEAD_WIDTH']=self~q(self~headWidth(s),.Units~millimetre)
  mf=.directory~new; mf['PROCESS']='COLD_FORMED_AND_ROLLED'; mf['TOLERANCE']='REPRESENTATIVE_ISO'
  return .PartDefinition~new('FASTENER-'s||'-'||style~string~upper||'-'||lengthMm||'-'||mat~id,'FASTENER','Parameterised metric fastener',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method pitch private class
  use strict arg s
  if s='M2' then return 0.4; if s='M2.5' then return 0.45; if s='M3' then return 0.5; if s='M4' then return 0.7; if s='M5' then return 0.8; if s='M6' then return 1; if s='M8' then return 1.25; if s='M10' then return 1.5; if s='M12' then return 1.75
  raise syntax 93.900 array('unsupported metric size' s)
::method diameter private class; use strict arg s; return s~substr(2) + 0
::method headWidth private class
  use strict arg s
  if s='M2' then return 4; if s='M2.5' then return 5; if s='M3' then return 5.5; if s='M4' then return 7; if s='M5' then return 8; if s='M6' then return 10; if s='M8' then return 13; if s='M10' then return 16; if s='M12' then return 18
  raise syntax 93.900 array('unsupported metric size' s)
::method headArea private class; use strict arg s; return self~headWidth(s)*self~headWidth(s)*0.866*0.55
::method headCapacity private class
  use strict arg s,mat
  shearFactor=mat~value('SHEAR_FACTOR')
  return mat~value('YIELD_STRESS')*shearFactor*self~headArea(s)/1000000

::method metricNut class
  use strict arg size='M6',style='HEX',materialId='STEEL-8.8-REFERENCE'
  mat=self~material(materialId); s=size~string~upper
  p=.directory~new; p['NOMINAL_SIZE']=s; p['PITCH']=self~q(self~pitch(s),.Units~millimetre); p['MATERIAL_ID']=mat~id; p['HEIGHT']=self~q(self~nutHeight(s),.Units~millimetre)
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['STYLE']=style; g['ACROSS_FLATS']=self~q(self~headWidth(s),.Units~millimetre)
  return .PartDefinition~new('NUT-'s||'-'||style,'NUT','Parameterised metric nut',p,m,g,.nil,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')
::method nutHeight private class; use strict arg s; return self~diameter(s)*0.8

::method bearing class
  use strict arg designation='608',seal='2RS',materialId='STEEL-MILD-REFERENCE'
  mat=self~material(materialId); b=.directory~new
  if designation='608' then do; bore=8; outer=22; width=7; dyn=3300; stat=1370; end
  else if designation='6000' then do; bore=10; outer=26; width=8; dyn=4550; stat=1960; end
  else if designation='6001' then do; bore=12; outer=28; width=8; dyn=5100; stat=2360; end
  else if designation='6002' then do; bore=15; outer=32; width=9; dyn=5600; stat=2830; end
  else if designation='6200' then do; bore=10; outer=30; width=9; dyn=5100; stat=2390; end
  else if designation='6201' then do; bore=12; outer=32; width=10; dyn=6800; stat=3100; end
  else if designation='6202' then do; bore=15; outer=35; width=11; dyn=7650; stat=3750; end
  else if designation='6203' then do; bore=17; outer=40; width=12; dyn=9550; stat=4750; end
  else if designation='6204' then do; bore=20; outer=47; width=14; dyn=12800; stat=6650; end
  else raise syntax 93.900 array('unsupported bearing' designation)
  b['BORE']=self~q(bore,.Units~millimetre); b['OUTER_DIAMETER']=self~q(outer,.Units~millimetre); b['WIDTH']=self~q(width,.Units~millimetre); b['DYNAMIC_LOAD_RATING_N']=dyn; b['STATIC_LOAD_RATING_N']=stat; b['SEAL']=seal; b['MATERIAL_ID']=mat~id
  m=.directory~new; m['RINGS']=mat~id; g=.directory~new; g['TYPE']='DEEP_GROOVE'; g['SEAL']=seal; mf=.directory~new; mf['PROVENANCE']='REPRESENTATIVE_CATALOGUE_VALUE'
  return .PartDefinition~new('BEARING-'designation||'-'||seal,'BEARING','Parameterised deep-groove bearing',b,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method roundShaft class
  use strict arg diameterMm=8,lengthMm=100,materialId='STEEL-MILD-REFERENCE'
  mat=self~material(materialId); p=.directory~new; p['DIAMETER']=self~q(diameterMm,.Units~millimetre); p['LENGTH']=self~q(lengthMm,.Units~millimetre); p['MATERIAL_ID']=mat~id
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']='ROUND'; mf=.directory~new; mf['PROCESS']='TURNED_OR_DRAWN'
  return .PartDefinition~new('SHAFT-'diameterMm||'X'||lengthMm||'-'||mat~id,'SHAFT','Parameterised round shaft',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method compressionSpring class
  use strict arg wireMm=1,meanDiameterMm=10,activeTurns=8,freeLengthMm=25,materialId='STEEL-8.8-REFERENCE'
  mat=self~material(materialId); young=mat~value('YOUNG_MODULUS'); poisson=mat~value('POISSON_RATIO'); if poisson=.nil then poisson=0.3
  shear=young/(2*(1+poisson)); rate=shear*(wireMm**4)/(8*(meanDiameterMm**3)*activeTurns)
  p=.directory~new; p['WIRE_DIAMETER']=self~q(wireMm,.Units~millimetre); p['MEAN_DIAMETER']=self~q(meanDiameterMm,.Units~millimetre); p['ACTIVE_TURNS']=activeTurns; p['FREE_LENGTH']=self~q(freeLengthMm,.Units~millimetre); p['SPRING_RATE_N_PER_M']=rate; p['MATERIAL_ID']=mat~id
  m=.directory~new; m['WIRE']=mat~id; g=.directory~new; g['FORM']='COMPRESSION_HELICAL'; mf=.directory~new; mf['PROCESS']='COILED_AND_STRESS_RELIEVED'
  return .PartDefinition~new('SPRING-COMP-'wireMm||'X'||meanDiameterMm||'X'||activeTurns,'SPRING','Parameterised compression spring',p,m,g,mf,.nil,'MODEL_DERIVED')

::method structuralPlate class
  use strict arg materialId='AL-6061-T6',lengthMm=100,widthMm=50,thicknessMm=3
  mat=self~material(materialId); p=.directory~new; p['LENGTH']=self~q(lengthMm,.Units~millimetre); p['WIDTH']=self~q(widthMm,.Units~millimetre); p['THICKNESS']=self~q(thicknessMm,.Units~millimetre); p['MATERIAL_ID']=mat~id; p['VOLUME_MM3']=lengthMm*widthMm*thicknessMm; p['MASS_KG']=mat~value('DENSITY')*p['VOLUME_MM3']/1000000000
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']='RECTANGULAR_PLATE'; mf=.directory~new; mf['PROCESS']='CUT_SHEET_STOCK'
  return .PartDefinition~new('PLATE-'||mat~id||'-'||lengthMm||'X'||widthMm||'X'||thicknessMm,'STOCK','Parameterised structural plate',p,m,g,mf,.nil,'MODEL_DERIVED')

::method washer class
  use strict arg size='M6',style='PLAIN',materialId='STEEL-MILD-REFERENCE'
  mat=self~material(materialId); s=size~string~upper; d=self~diameter(s); p=.directory~new
  p['NOMINAL_SIZE']=s; p['INNER_DIAMETER']=self~q(d+0.5,.Units~millimetre); p['OUTER_DIAMETER']=self~q(d*2.2,.Units~millimetre); p['THICKNESS']=self~q(d*0.25,.Units~millimetre); p['MATERIAL_ID']=mat~id
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']=style~string~upper; mf=.directory~new; mf['PROCESS']='STAMPED_AND_FINISHED'
  return .PartDefinition~new('WASHER-'s||'-'||style,'WASHER','Parameterised metric washer',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method spurGear class
  use strict arg moduleMm=1,teeth=20,pressureAngle=20,materialId='POM-GENERIC'
  mat=self~material(materialId); p=.directory~new; p['MODULE']=self~q(moduleMm,.Units~millimetre); p['TEETH']=teeth; p['PRESSURE_ANGLE_DEG']=pressureAngle; p['PITCH_DIAMETER']=self~q(moduleMm*teeth,.Units~millimetre); p['MATERIAL_ID']=mat~id
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']='INVOLUTE_SPUR'; mf=.directory~new; mf['PROCESS']='HOBBED_OR_MOULDED'
  return .PartDefinition~new('GEAR-M'||moduleMm||'-Z'||teeth,'GEAR','Parameterised involute spur gear',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method wire class
  use strict arg gauge='22AWG',lengthM=1,materialId='CU-C110-REFERENCE'
  mat=self~material(materialId); area=0.326; if gauge='18AWG' then area=0.823; if gauge='20AWG' then area=0.519; if gauge='22AWG' then area=0.326; if gauge='24AWG' then area=0.205
  resistivity=mat~value('ELECTRICAL_RESISTIVITY'); if resistivity=.nil then resistivity='0.0000000168'; resistance=resistivity*lengthM/(area/1000000)
  p=.directory~new; p['GAUGE']=gauge; p['LENGTH']=self~q(lengthM,.Units~metre); p['CROSS_SECTIONAL_AREA']=self~q(area,.Units~millimetre~power(2)); p['RESISTANCE_OHM']=resistance; p['MATERIAL_ID']=mat~id
  m=.directory~new; m['CONDUCTOR']=mat~id; m['INSULATION']='PVC-GENERIC'; g=.directory~new; g['FORM']='ROUND_HOOKUP_WIRE'; mf=.directory~new; mf['PROCESS']='DRAWN_AND_INSULATED'
  return .PartDefinition~new('WIRE-'||gauge||'-'||lengthM||'M','WIRE','Parameterised hookup wire',p,m,g,mf,.nil,'MODEL_DERIVED')

::method packageDIP class
  use strict arg pins=8
  p=.directory~new; p['PINS']=pins; p['PIN_PITCH']=self~q(2.54,.Units~millimetre); p['ROW_SPACING']=self~q(7.62,.Units~millimetre); p['BODY_MATERIAL_ID']='EPOXY-GENERIC'
  m=.directory~new; m['BODY']='EPOXY-GENERIC'; m['LEADS']='CU-C110-REFERENCE'; g=.directory~new; g['FORM']='DUAL_INLINE'; mf=.directory~new; mf['PROCESS']='INSERT_MOULD_AND_TRIM'
  return .PartDefinition~new('PACKAGE-DIP-'pins,'PACKAGE','Parameterised dual-inline package',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method battery class
  use strict arg form='AA',chemistry='ALKALINE'
  p=.directory~new; p['FORM']=form; p['CHEMISTRY']=chemistry; p['NOMINAL_VOLTAGE']=1.5; p['CAPACITY_MAH']=2500; p['MATERIAL_ID']='ABS-GENERIC'
  m=.directory~new; m['CASE']='ABS-GENERIC'; m['TERMINALS']='CU-C110-REFERENCE'; g=.directory~new; g['FORM']='CYLINDRICAL'; mf=.directory~new; mf['PROCESS']='CELL_ASSEMBLY'
  return .PartDefinition~new('BATTERY-'form||'-'||chemistry,'BATTERY','Representative primary cell physical definition',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method nylocNut class
  use strict arg size='M6',materialId='STEEL-8.8-REFERENCE'
  n=self~metricNut(size,'NYLOC',materialId); n~parameters['LOCKING_INSERT_MATERIAL_ID']='POLYAMIDE-GENERIC'; return n

::method threadedRod class
  use strict arg size='M6',lengthMm=1000,materialId='STEEL-MILD-REFERENCE'
  mat=self~material(materialId); p=.directory~new; p['NOMINAL_SIZE']=size; p['LENGTH']=self~q(lengthMm,.Units~millimetre); p['PITCH']=self~q(self~pitch(size),.Units~millimetre); p['MATERIAL_ID']=mat~id
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']='FULLY_THREADED_ROD'; mf=.directory~new; mf['PROCESS']='ROLLED_OR_CUT_THREAD'
  return .PartDefinition~new('ROD-'||size||'X'||lengthMm||'-'||mat~id,'THREADED_ROD','Parameterised metric threaded rod',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method extensionSpring class
  use strict arg wireMm=1,meanDiameterMm=10,activeTurns=8,freeLengthMm=30,materialId='STEEL-MILD-REFERENCE'
  p=.directory~new; p['WIRE_DIAMETER']=self~q(wireMm,.Units~millimetre); p['MEAN_DIAMETER']=self~q(meanDiameterMm,.Units~millimetre); p['ACTIVE_TURNS']=activeTurns; p['FREE_LENGTH']=self~q(freeLengthMm,.Units~millimetre); p['MATERIAL_ID']=self~material(materialId)~id
  m=.directory~new; m['WIRE']=materialId; g=.directory~new; g['FORM']='HELICAL_EXTENSION'; mf=.directory~new; mf['PROCESS']='COILED_AND_STRESS_RELIEVED'
  return .PartDefinition~new('SPRING-EXT-'||wireMm||'X'||meanDiameterMm||'X'||activeTurns,'SPRING','Parameterised extension spring',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method torsionSpring class
  use strict arg wireMm=1,meanDiameterMm=10,activeTurns=5,materialId='STEEL-MILD-REFERENCE'
  p=.directory~new; p['WIRE_DIAMETER']=self~q(wireMm,.Units~millimetre); p['MEAN_DIAMETER']=self~q(meanDiameterMm,.Units~millimetre); p['ACTIVE_TURNS']=activeTurns; p['MATERIAL_ID']=self~material(materialId)~id
  m=.directory~new; m['WIRE']=materialId; g=.directory~new; g['FORM']='HELICAL_TORSION'; mf=.directory~new; mf['PROCESS']='COILED_AND_STRESS_RELIEVED'
  return .PartDefinition~new('SPRING-TORS-'||wireMm||'X'||meanDiameterMm||'X'||activeTurns,'SPRING','Parameterised torsion spring',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method structuralProfile class
  use strict arg profile='SQUARE_TUBE',widthMm=20,heightMm=20,wallMm=2,lengthMm=1000,materialId='AL-6061-T6'
  mat=self~material(materialId); p=.directory~new; p['PROFILE']=profile; p['WIDTH']=self~q(widthMm,.Units~millimetre); p['HEIGHT']=self~q(heightMm,.Units~millimetre); p['WALL']=self~q(wallMm,.Units~millimetre); p['LENGTH']=self~q(lengthMm,.Units~millimetre); p['MATERIAL_ID']=mat~id
  m=.directory~new; m['BODY']=mat~id; g=.directory~new; g['FORM']=profile; mf=.directory~new; mf['PROCESS']='EXTRUDED_OR_ROLLED_STOCK'
  return .PartDefinition~new('PROFILE-'||profile||'-'||widthMm||'X'||heightMm||'X'||wallMm,'STRUCTURAL_PROFILE','Parameterised structural profile',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method resistorE24 class
  use strict arg resistanceOhm=1000,tolerancePercent=5,powerW=0.25
  p=.directory~new; p['RESISTANCE_OHM']=resistanceOhm; p['TOLERANCE_PERCENT']=tolerancePercent; p['POWER_W']=powerW; p['SERIES']='E24'; p['MATERIAL_ID']='CARBON-COMPOSITION-GENERIC'
  m=.directory~new; m['BODY']='RESISTOR-BODY-GENERIC'; m['LEAD']='CU-C110-REFERENCE'; g=.directory~new; g['FORM']='AXIAL'; mf=.directory~new; mf['PROCESS']='THICK_FILM_ASSEMBLY'
  return .PartDefinition~new('RESISTOR-E24-'||resistanceOhm||'-'||powerW||'W','RESISTOR','Parameterised E24 resistor',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method capacitorPhysical class
  use strict arg capacitance='100 nF',voltageV=50,kind='CERAMIC'
  dielectric='FR4-GENERIC'; if kind~string~upper='ELECTROLYTIC' then dielectric='ELECTROLYTIC-DIELECTRIC-GENERIC'; if kind~string~upper='FILM' then dielectric='EPOXY-GENERIC'
  p=.directory~new; p['CAPACITANCE']=capacitance; p['VOLTAGE_RATING_V']=voltageV; p['TYPE']=kind~string~upper; p['POLARITY']=kind~string~upper='ELECTROLYTIC'; p['MATERIAL_ID']=dielectric
  m=.directory~new; m['DIELECTRIC']=dielectric; m['TERMINAL']='CU-C110-REFERENCE'; g=.directory~new; g['FORM']='RADIAL_OR_BOX'; mf=.directory~new; mf['PROCESS']='WOUND_OR_LAYERED_ASSEMBLY'
  return .PartDefinition~new('CAPACITOR-'||kind||'-'||capacitance||'-'||voltageV||'V','CAPACITOR','Parameterised physical capacitor',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method fuse class
  use strict arg currentA=1,voltageV=250,package='5X20MM'
  p=.directory~new; p['CURRENT_RATING_A']=currentA; p['VOLTAGE_RATING_V']=voltageV; p['PACKAGE']=package; p['MATERIAL_ID']='GLASS-SODA-LIME-REFERENCE'
  m=.directory~new; m['BODY']='GLASS-SODA-LIME-REFERENCE'; m['CAPS']='CU-C110-REFERENCE'; g=.directory~new; g['FORM']='CARTRIDGE'; mf=.directory~new; mf['PROCESS']='FUSE_ELEMENT_ASSEMBLY'
  return .PartDefinition~new('FUSE-'||currentA||'A-'||package,'FUSE','Representative cartridge fuse',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method led class
  use strict arg colour='RED',diameterMm=5
  vf=1.9; if colour~string~upper='GREEN' then vf=2.1; if colour~string~upper='BLUE' then vf=3.0; if colour~string~upper='WHITE' then vf=3.0; if colour~string~upper='IR' then vf=1.3
  p=.directory~new; p['COLOUR']=colour~string~upper; p['FORWARD_VOLTAGE_V']=vf; p['DIAMETER']=self~q(diameterMm,.Units~millimetre); p['MATERIAL_ID']='III-V-SEMICONDUCTOR-GENERIC'
  m=.directory~new; m['DIE']='III-V-SEMICONDUCTOR-GENERIC'; m['LEAD']='CU-C110-REFERENCE'; m['ENCAPSULANT']='EPOXY-GENERIC'; g=.directory~new; g['FORM']='THROUGH_HOLE_LED'; mf=.directory~new; mf['PROCESS']='DIE_ATTACH_AND_ENCAPSULATION'
  return .PartDefinition~new('LED-'||colour||'-'||diameterMm||'MM','LED','Representative LED physical definition',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method packageSOIC class
  use strict arg pins=8,pitchMm=1.27
  p=.directory~new; p['PINS']=pins; p['PIN_PITCH']=self~q(pitchMm,.Units~millimetre); p['BODY_MATERIAL_ID']='EPOXY-GENERIC'; p['LEAD_MATERIAL_ID']='CU-ALLOY-GENERIC'
  m=.directory~new; m['BODY']='EPOXY-GENERIC'; m['LEADS']='CU-ALLOY-GENERIC'; g=.directory~new; g['FORM']='SMALL_OUTLINE'; mf=.directory~new; mf['PROCESS']='MOULD_AND_TRIM'
  return .PartDefinition~new('PACKAGE-SOIC-'||pins,'PACKAGE','Parameterised SOIC package',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method connector class
  use strict arg kind='PIN_HEADER',positions=2,pitchMm=2.54
  p=.directory~new; p['KIND']=kind~string~upper; p['POSITIONS']=positions; p['PITCH']=self~q(pitchMm,.Units~millimetre); p['CONTACT_MATERIAL_ID']='CU-ALLOY-GENERIC'; p['BODY_MATERIAL_ID']='POLYAMIDE-GENERIC'
  m=.directory~new; m['CONTACTS']='CU-ALLOY-GENERIC'; m['BODY']='POLYAMIDE-GENERIC'; g=.directory~new; g['FORM']=kind~string~upper; mf=.directory~new; mf['PROCESS']='STAMPED_CONTACT_AND_MOULDED_BODY'
  return .PartDefinition~new('CONNECTOR-'||kind||'-'||positions,'CONNECTOR','Parameterised connector',p,m,g,mf,.nil,'REPRESENTATIVE_ENGINEERING_VALUE')

::method representativeCatalog class
  return .array~of(self~metricFastener('M3',12,'SOCKET_HEAD','8.8'),self~metricNut('M3'),self~washer('M3'),self~bearing('608','2RS'),self~roundShaft(8,100),self~compressionSpring(),self~structuralPlate(),self~structuralPlate('SS-304-REFERENCE',100,50,2),self~structuralPlate('STEEL-MILD-REFERENCE',200,100,5),self~spurGear(),self~wire(),self~packageDIP(),self~battery(),self~nylocNut(),self~threadedRod(),self~extensionSpring(),self~torsionSpring(),self~structuralProfile(),self~resistorE24(),self~capacitorPhysical(),self~fuse(),self~led(),self~packageSOIC(),self~connector())

::requires 'PartsCatalog.cls'
::requires 'MaterialsCatalog.cls'
::requires 'Units.cls'
