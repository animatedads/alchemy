/* ooRexx Common Parts - assembly and interface model v0.1-dev6
 *
 * Assemblies retain constituent PartDefinition identities.  This is catalogue
 * composition and interface authority only; constraints, loads, motion,
 * contact and manufacturing operations remain external behaviour.
 */

::class PartInterface public
::attribute id get
::attribute kind get
::attribute geometry get
::attribute attributes get

::method init
  expose id kind geometry attributes
  use strict arg idArg,kindArg,geometryArg=.nil,attributesArg=.nil
  id=idArg~string
  kind=kindArg~string~upper
  if geometryArg=.nil then geometry=.directory~new; else geometry=geometryArg
  if attributesArg=.nil then attributes=.directory~new; else attributes=attributesArg

::class AssemblyMember public
::attribute id get
::attribute definition get
::attribute transform get
::attribute interfaces get

::method init
  expose id definition transform interfaces
  use strict arg idArg,definitionArg,transformArg=.nil,interfacesArg=.nil
  id=idArg~string
  definition=definitionArg
  if transformArg=.nil then transform=.directory~new; else transform=transformArg
  if interfacesArg=.nil then interfaces=.directory~new; else interfaces=interfacesArg
  definition~validate

::method interface
  expose interfaces
  use strict arg interfaceId
  k=interfaceId~string~upper
  if \interfaces~hasIndex(k) then return .nil
  return interfaces[k]

::class AssemblyConnection public
::attribute id get
::attribute memberA get
::attribute interfaceA get
::attribute memberB get
::attribute interfaceB get
::attribute relation get
::attribute parameters get

::method init
  expose id memberA interfaceA memberB interfaceB relation parameters
  use strict arg idArg,memberAArg,interfaceAArg,memberBArg,interfaceBArg,relationArg='MATED',parametersArg=.nil
  id=idArg~string
  memberA=memberAArg~string; interfaceA=interfaceAArg~string
  memberB=memberBArg~string; interfaceB=interfaceBArg~string
  relation=relationArg~string~upper
  if parametersArg=.nil then parameters=.directory~new; else parameters=parametersArg

::class PartAssembly public
::attribute id get
::attribute description get
::attribute members get
::attribute connections get
::attribute provenance get

::method init
  expose id description members connections provenance
  use strict arg idArg,descriptionArg=''
  id=idArg~string; description=descriptionArg~string
  members=.directory~new; connections=.directory~new; provenance=.directory~new

::method addMember
  expose members
  use strict arg member
  k=member~id~string~upper
  if members~hasIndex(k) then raise syntax 93.900 array('duplicate assembly member' member~id)
  members[k]=member
  return self

::method member
  expose members
  use strict arg memberId
  k=memberId~string~upper
  if \members~hasIndex(k) then return .nil
  return members[k]

::method connect
  expose members connections
  use strict arg connection
  a=connection~memberA~string~upper; b=connection~memberB~string~upper
  if \members~hasIndex(a) | \members~hasIndex(b) then raise syntax 93.900 array('assembly connection references unknown member')
  ma=members[a]; mb=members[b]
  if ma~interface(connection~interfaceA)=.nil then raise syntax 93.900 array('unknown interface' connection~interfaceA 'on' connection~memberA)
  if mb~interface(connection~interfaceB)=.nil then raise syntax 93.900 array('unknown interface' connection~interfaceB 'on' connection~memberB)
  k=connection~id~string~upper
  if connections~hasIndex(k) then raise syntax 93.900 array('duplicate assembly connection' connection~id)
  connections[k]=connection
  return self

::method validate
  expose members connections
  if members~items=0 then raise syntax 93.900 array('assembly must contain members')
  do k over connections
    c=connections[k]
    if \members~hasIndex(c~memberA~string~upper) | \members~hasIndex(c~memberB~string~upper) then -
      raise syntax 93.900 array('invalid assembly connection member')
  end
  return .true

::class CommonPartInterfaces public
::method cylindrical class
  use strict arg id,diameter,length=.nil,fit='REFERENCE'
  g=.directory~new; g['DIAMETER']=diameter
  if length<>.nil then g['LENGTH']=length
  a=.directory~new; a['FIT']=fit
  return .PartInterface~new(id,'CYLINDRICAL',g,a)

::method bearingBore class
  use strict arg diameter
  return self~cylindrical('BORE',diameter,.nil,'BEARING_BORE')

::method shaftJournal class
  use strict arg diameter
  return self~cylindrical('JOURNAL',diameter,.nil,'SHAFT_JOURNAL')

::method boltAxis class
  use strict arg nominalSize,pitch
  g=.directory~new; g['NOMINAL_SIZE']=nominalSize; g['PITCH']=pitch
  return .PartInterface~new('THREAD','METRIC_THREAD',g)

::class CommonAssemblies public
::method shaftBearingPulley class
  use strict arg shaftLength='250 mm',shaftMaterial='STEEL-MILD-REFERENCE',bearingSeries='608',pulleyTeeth=20
  shaft=.CommonParts~roundShaft('8 mm',shaftLength,shaftMaterial)
  bearing=.CommonParts~bearingDeepGroove(bearingSeries,'2RS')
  pulley=.CommonParts~gt2Pulley(pulleyTeeth,'8 mm','6 mm')
  collar=.CommonParts~shaftCollar('8 mm')

  si=.directory~new; si['JOURNAL']=.CommonPartInterfaces~shaftJournal('8 mm')
  bi=.directory~new; bi['BORE']=.CommonPartInterfaces~bearingBore('8 mm')
  pi=.directory~new; pi['BORE']=.CommonPartInterfaces~bearingBore('8 mm')
  ci=.directory~new; ci['BORE']=.CommonPartInterfaces~bearingBore('8 mm')

  a=.PartAssembly~new('ASSEMBLY-SHAFT-BEARING-PULLEY','Reference shaft, bearing, collar and GT2 pulley assembly')
  a~addMember(.AssemblyMember~new('SHAFT',shaft,.nil,si))
  a~addMember(.AssemblyMember~new('BEARING',bearing,.nil,bi))
  a~addMember(.AssemblyMember~new('PULLEY',pulley,.nil,pi))
  a~addMember(.AssemblyMember~new('COLLAR',collar,.nil,ci))
  a~connect(.AssemblyConnection~new('SHAFT-BEARING','SHAFT','JOURNAL','BEARING','BORE','COAXIAL_FIT'))
  a~connect(.AssemblyConnection~new('SHAFT-PULLEY','SHAFT','JOURNAL','PULLEY','BORE','COAXIAL_FIT'))
  a~connect(.AssemblyConnection~new('SHAFT-COLLAR','SHAFT','JOURNAL','COLLAR','BORE','COAXIAL_FIT'))
  return a


::method redLaserModule class
  diode=.CommonParts~laserDiodeRed
  lens=.CommonParts~laserCollimator
  mount=.CommonParts~laserDiodeMount
  di=.directory~new
  di['OPTICAL_AXIS']=.PartInterface~new('OPTICAL_AXIS','OPTICAL_AXIS')
  li=.directory~new
  li['OPTICAL_AXIS']=.PartInterface~new('OPTICAL_AXIS','OPTICAL_AXIS')
  mi=.directory~new
  mi['DIODE_SEAT']=.PartInterface~new('DIODE_SEAT','CYLINDRICAL_MOUNT')
  a=.PartAssembly~new('ASSEMBLY-LASER-650NM-REFERENCE','Low-power red diode, mount and collimator assembly')
  a~addMember(.AssemblyMember~new('DIODE',diode,.nil,di))
  a~addMember(.AssemblyMember~new('COLLIMATOR',lens,.nil,li))
  a~addMember(.AssemblyMember~new('MOUNT',mount,.nil,mi))
  a~connect(.AssemblyConnection~new('DIODE-LENS-AXIS','DIODE','OPTICAL_AXIS','COLLIMATOR','OPTICAL_AXIS','COAXIAL_OPTICAL'))
  return a

::requires 'PartsCatalog.cls'
