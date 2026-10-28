/* Media methodology execution-shape and work-unit contracts.
 *
 * API: media.methodologies.execution/0.1
 *
 * This is deliberately advisory.  It describes how a methodology can be split
 * into work and what an implementation says it needs.  It does not select a
 * RexxOS node, allocate Memory Fabric capacity, issue Job-to-Node leases, move
 * Storage Fabric material, or promote derived output into source evidence.
 */

::class MediaWorkShape public
::method init
  expose methodologyId shardAxis stateModel accessPattern haloBefore haloAfter mergeMode continuity materialization
  use strict arg methodologyIdArg, shardAxisArg="NONE", stateModelArg="STATELESS", accessPatternArg="WINDOWED", haloBeforeArg=0, haloAfterArg=0, mergeModeArg="COLLECT", continuityArg="NONE", materializationArg="REFERENCE_FIRST"
  methodologyId=translate(strip(methodologyIdArg))
  shardAxis=translate(strip(shardAxisArg))
  stateModel=translate(strip(stateModelArg))
  accessPattern=translate(strip(accessPatternArg))
  haloBefore=haloBeforeArg
  haloAfter=haloAfterArg
  mergeMode=translate(strip(mergeModeArg))
  continuity=translate(strip(continuityArg))
  materialization=translate(strip(materializationArg))
  if methodologyId="" then raise syntax 93.900 array("Methodology id must not be empty")
  if haloBefore<0 | haloAfter<0 then raise syntax 93.900 array("Halo sizes must be non-negative")
::attribute methodologyId get
::attribute shardAxis get
::attribute stateModel get
::attribute accessPattern get
::attribute haloBefore get
::attribute haloAfter get
::attribute mergeMode get
::attribute continuity get
::attribute materialization get

::class MediaWorkShapeCatalogue public
::method init
  expose shapes
  shapes=.Directory~new
::method register
  expose shapes
  use strict arg shape
  if \shape~isA(.MediaWorkShape) then raise syntax 93.900 array("MediaWorkShape required")
  shapes[shape~methodologyId]=shape
  return shape
::method shape
  expose shapes
  use strict arg methodologyId
  return shapes[translate(strip(methodologyId))]
::method count
  expose shapes
  return shapes~items
::method all
  expose shapes
  answer=.Array~new
  do item over shapes~allItems
    answer~append(item)
  end
  return answer

/* Provider/implementation requirements are intentionally separate from the
 * methodology semantic identity.  Two implementations of one methodology may
 * need very different runtimes, memory, accelerators or legal/trust domains. */
::class MediaImplementationExecutionProfile public
::method init
  expose implementationId methodologyId runtime requiredAbilities requiredTags architecture minimumMemoryMiB minimumDiskMiB minimumCpuUnits minimumFreeMemoryMiB minimumFreeDiskMiB minimumAvailableCpuUnits minimumWluRate expectedMicroWlu deterministic recoveryClass
  use strict arg implementationIdArg, methodologyIdArg, runtimeArg="OOREXX", requiredAbilitiesArg=.nil, requiredTagsArg=.nil, architectureArg="", minimumMemoryMiBArg=0, minimumDiskMiBArg=0, minimumCpuUnitsArg=0, minimumFreeMemoryMiBArg=0, minimumFreeDiskMiBArg=0, minimumAvailableCpuUnitsArg=0, minimumWluRateArg=0, expectedMicroWluArg=0, deterministicArg=.true, recoveryClassArg="RECONSTRUCTABLE"
  implementationId=strip(implementationIdArg)
  methodologyId=translate(strip(methodologyIdArg))
  runtime=translate(strip(runtimeArg))
  architecture=translate(strip(architectureArg))
  minimumMemoryMiB=minimumMemoryMiBArg
  minimumDiskMiB=minimumDiskMiBArg
  minimumCpuUnits=minimumCpuUnitsArg
  minimumFreeMemoryMiB=minimumFreeMemoryMiBArg
  minimumFreeDiskMiB=minimumFreeDiskMiBArg
  minimumAvailableCpuUnits=minimumAvailableCpuUnitsArg
  minimumWluRate=minimumWluRateArg
  expectedMicroWlu=expectedMicroWluArg
  deterministic=deterministicArg
  recoveryClass=translate(strip(recoveryClassArg))
  requiredAbilities=self~copyArray(requiredAbilitiesArg)
  requiredTags=self~copyArray(requiredTagsArg)
  if implementationId="" then raise syntax 93.900 array("Implementation id must not be empty")
  if methodologyId="" then raise syntax 93.900 array("Methodology id must not be empty")
::attribute implementationId get
::attribute methodologyId get
::attribute runtime get
::attribute architecture get
::attribute minimumMemoryMiB get
::attribute minimumDiskMiB get
::attribute minimumCpuUnits get
::attribute minimumFreeMemoryMiB get
::attribute minimumFreeDiskMiB get
::attribute minimumAvailableCpuUnits get
::attribute minimumWluRate get
::attribute expectedMicroWlu get
::attribute deterministic get
::attribute recoveryClass get
::method requiredAbilities
  expose requiredAbilities
  return requiredAbilities~copy
::method requiredTags
  expose requiredTags
  return requiredTags~copy
::method copyArray
  use arg source
  answer=.Array~new
  if source=.nil then return answer
  do item over source
    answer~append(item~string)
  end
  return answer

::class MediaWorkUnit public
::method init
  expose workId methodologyId ordinalKind coreFirst coreLast readFirst readLast sequence stateModel mergeMode parameters parentIds
  use strict arg workIdArg, methodologyIdArg, ordinalKindArg, coreFirstArg, coreLastArg, readFirstArg, readLastArg, sequenceArg, stateModelArg="STATELESS", mergeModeArg="COLLECT", parametersArg=.nil, parentIdsArg=.nil
  numeric digits 30
  workId=strip(workIdArg)
  methodologyId=translate(strip(methodologyIdArg))
  ordinalKind=translate(strip(ordinalKindArg))
  coreFirst=coreFirstArg
  coreLast=coreLastArg
  readFirst=readFirstArg
  readLast=readLastArg
  sequence=sequenceArg
  stateModel=translate(strip(stateModelArg))
  mergeMode=translate(strip(mergeModeArg))
  if parametersArg=.nil then parametersArg=.Directory~new
  parameters=parametersArg
  parentIds=.Array~new
  if parentIdsArg<>.nil then do p over parentIdsArg; parentIds~append(p~string); end
  if workId="" | methodologyId="" then raise syntax 93.900 array("Work unit identity must not be empty")
  if coreFirst<1 | coreLast<coreFirst then raise syntax 93.900 array("Invalid core range")
  if readFirst<1 | readLast<readFirst then raise syntax 93.900 array("Invalid read range")
  if readFirst>coreFirst | readLast<coreLast then raise syntax 93.900 array("Read range must cover core range")
::attribute workId get
::attribute methodologyId get
::attribute ordinalKind get
::attribute coreFirst get
::attribute coreLast get
::attribute readFirst get
::attribute readLast get
::attribute sequence get
::attribute stateModel get
::attribute mergeMode get
::method parameters
  expose parameters
  return parameters
::method parentIds
  expose parentIds
  return parentIds~copy

::class MediaExecutionPlan public
::method init
  expose methodologyId units
  use strict arg methodologyIdArg
  methodologyId=translate(strip(methodologyIdArg))
  units=.Array~new
::attribute methodologyId get
::method add
  expose units methodologyId
  use strict arg unit
  if \unit~isA(.MediaWorkUnit) then raise syntax 93.900 array("MediaWorkUnit required")
  if unit~methodologyId<>methodologyId then raise syntax 93.900 array("Work unit methodology mismatch")
  units~append(unit)
  return self
::method units
  expose units
  return units~copy
::method count
  expose units
  return units~items

::class MediaMethodologyExecutionPlanner public
/* Split one logical media range into core windows plus method-specific halos.
 * The planner is exact about the overlap it requests but makes no node choice. */
::method partition
  use strict arg shape, firstOrdinal, lastOrdinal, coreItems, ordinalKind="FRAME", parameters=.nil
  numeric digits 30
  if \shape~isA(.MediaWorkShape) then raise syntax 93.900 array("MediaWorkShape required")
  first=firstOrdinal
  last=lastOrdinal
  chunk=coreItems
  if first<1 | last<first | chunk<1 then raise syntax 93.900 array("Invalid logical media range")
  plan=.MediaExecutionPlan~new(shape~methodologyId)
  if shape~shardAxis="NONE" | shape~stateModel="GLOBAL" then chunk=last-first+1
  seq=0
  coreFirst=first
  do while coreFirst<=last
    seq+=1
    coreLast=coreFirst+chunk-1
    if coreLast>last then coreLast=last
    readFirst=coreFirst-shape~haloBefore
    if readFirst<first then readFirst=first
    readLast=coreLast+shape~haloAfter
    if readLast>last then readLast=last
    workId=shape~methodologyId||"#"||seq
    plan~add(.MediaWorkUnit~new(workId,shape~methodologyId,ordinalKind,coreFirst,coreLast,readFirst,readLast,seq,shape~stateModel,shape~mergeMode,parameters))
    coreFirst=coreLast+1
  end
  return plan

/* A detached record of execution provenance.  Placement and Memory Fabric
 * authorities remain external; this object merely records exact references. */
::class MediaExecutionProvenance public
::method init
  expose workId methodologyId implementationId nodeRef nodeIncarnation placementRef memoryObjectRef memoryEpoch sourceRefs outputRef status
  use strict arg workIdArg, methodologyIdArg, implementationIdArg, nodeRefArg="", nodeIncarnationArg="", placementRefArg="", memoryObjectRefArg="", memoryEpochArg="", sourceRefsArg=.nil, outputRefArg="", statusArg="COMPLETED"
  workId=strip(workIdArg)
  methodologyId=translate(strip(methodologyIdArg))
  implementationId=strip(implementationIdArg)
  nodeRef=strip(nodeRefArg)
  nodeIncarnation=strip(nodeIncarnationArg)
  placementRef=strip(placementRefArg)
  memoryObjectRef=strip(memoryObjectRefArg)
  memoryEpoch=memoryEpochArg~string
  sourceRefs=.Array~new
  if sourceRefsArg<>.nil then do s over sourceRefsArg; sourceRefs~append(s); end
  outputRef=strip(outputRefArg)
  status=translate(strip(statusArg))
::attribute workId get
::attribute methodologyId get
::attribute implementationId get
::attribute nodeRef get
::attribute nodeIncarnation get
::attribute placementRef get
::attribute memoryObjectRef get
::attribute memoryEpoch get
::attribute outputRef get
::attribute status get
::method sourceRefs
  expose sourceRefs
  return sourceRefs~copy
