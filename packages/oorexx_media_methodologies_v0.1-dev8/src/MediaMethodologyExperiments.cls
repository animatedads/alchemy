/* Media methodology experiment orchestration contracts.
 *
 * API: media.methodologies.experiment/0.1
 *
 * This layer coordinates scientific alternatives.  It does not choose a
 * scheduler, allocate Memory Fabric, move Storage material, execute a method,
 * or promote a reconstruction candidate into captured evidence.
 */

::class MediaExperimentMethodSelection public
::method init
  expose methodologyId implementationProfile lineageId parameters
  use strict arg methodologyIdArg, implementationProfileArg, lineageIdArg="", parametersArg=.nil
  methodologyId=translate(strip(methodologyIdArg))
  implementationProfile=implementationProfileArg
  if implementationProfile=.nil then raise syntax 93.900 array("Implementation profile is required")
  if \implementationProfile~isA(.MediaImplementationExecutionProfile) then raise syntax 93.900 array("MediaImplementationExecutionProfile required")
  if methodologyId="" then raise syntax 93.900 array("Methodology id must not be empty")
  if implementationProfile~methodologyId<>methodologyId then raise syntax 93.900 array("Implementation profile methodology mismatch")
  lineageId=strip(lineageIdArg)
  if lineageId="" then lineageId=methodologyId
  if parametersArg=.nil then parametersArg=.Directory~new
  parameters=parametersArg
::attribute methodologyId get
::attribute implementationProfile get
::attribute lineageId get
::method parameters
  expose parameters
  return parameters

::class MediaExperimentDefinition public
::method init
  expose experimentId goal sourceRefs methods metadata
  use strict arg experimentIdArg, goalArg="", sourceRefsArg=.nil, metadataArg=.nil
  experimentId=strip(experimentIdArg)
  goal=strip(goalArg)
  if experimentId="" then raise syntax 93.900 array("Experiment id must not be empty")
  sourceRefs=.Array~new
  if sourceRefsArg<>.nil then do sourceRef over sourceRefsArg
    sourceRefs~append(sourceRef)
  end
  methods=.Array~new
  if metadataArg=.nil then metadataArg=.Directory~new
  metadata=metadataArg
::attribute experimentId get
::attribute goal get
::method sourceRefs
  expose sourceRefs
  return sourceRefs~copy
::method metadata
  expose metadata
  return metadata
::method addMethod
  expose methods
  use strict arg selection
  if \selection~isA(.MediaExperimentMethodSelection) then raise syntax 93.900 array("MediaExperimentMethodSelection required")
  methods~append(selection)
  return self
::method methods
  expose methods
  return methods~copy
::method methodCount
  expose methods
  return methods~items
::method lineages
  expose methods
  answer=.Array~new
  seen=.Directory~new
  do selection over methods
    key=selection~lineageId
    if seen~hasIndex(key) then iterate
    seen[key]=.true
    answer~append(key)
  end
  return answer

::class MediaExperimentTask public
::method init
  expose experimentId lineageId selection workUnit
  use strict arg experimentIdArg, lineageIdArg, selectionArg, workUnitArg
  experimentId=strip(experimentIdArg)
  lineageId=strip(lineageIdArg)
  selection=selectionArg
  workUnit=workUnitArg
  if experimentId="" | lineageId="" then raise syntax 93.900 array("Experiment and lineage identity are required")
  if \selection~isA(.MediaExperimentMethodSelection) then raise syntax 93.900 array("MediaExperimentMethodSelection required")
  if \workUnit~isA(.MediaWorkUnit) then raise syntax 93.900 array("MediaWorkUnit required")
  if workUnit~methodologyId<>selection~methodologyId then raise syntax 93.900 array("Task methodology mismatch")
::attribute experimentId get
::attribute lineageId get
::attribute selection get
::attribute workUnit get
::method taskId
  expose experimentId lineageId workUnit
  return experimentId||":"||lineageId||":"||workUnit~workId

::class MediaExperimentPlan public
::method init
  expose definition tasks
  use strict arg definitionArg
  if \definitionArg~isA(.MediaExperimentDefinition) then raise syntax 93.900 array("MediaExperimentDefinition required")
  definition=definitionArg
  tasks=.Array~new
::attribute definition get
::method add
  expose tasks definition
  use strict arg task
  if \task~isA(.MediaExperimentTask) then raise syntax 93.900 array("MediaExperimentTask required")
  if task~experimentId<>definition~experimentId then raise syntax 93.900 array("Task belongs to another experiment")
  tasks~append(task)
  return self
::method tasks
  expose tasks
  return tasks~copy
::method count
  expose tasks
  return tasks~items
::method tasksForLineage
  expose tasks
  use strict arg lineageIdArg
  wanted=strip(lineageIdArg)
  answer=.Array~new
  do task over tasks
    if task~lineageId=wanted then answer~append(task)
  end
  return answer
::method lineageCount
  expose definition
  return definition~lineages~items

::class MediaExperimentPlanner public
/* Expand each selected methodology independently.  No task from one lineage
 * becomes a parent, state continuation or merge input of another lineage. */
::method plan
  use strict arg definition, shapeCatalogue, firstOrdinal, lastOrdinal, coreItems, ordinalKind="FRAME"
  if \definition~isA(.MediaExperimentDefinition) then raise syntax 93.900 array("MediaExperimentDefinition required")
  if \shapeCatalogue~isA(.MediaWorkShapeCatalogue) then raise syntax 93.900 array("MediaWorkShapeCatalogue required")
  answer=.MediaExperimentPlan~new(definition)
  planner=.MediaMethodologyExecutionPlanner~new
  do selection over definition~methods
    shape=shapeCatalogue~shape(selection~methodologyId)
    if shape=.nil then raise syntax 93.900 array("No work shape for methodology",selection~methodologyId)
    execution=planner~partition(shape,firstOrdinal,lastOrdinal,coreItems,ordinalKind,selection~parameters)
    do unit over execution~units
      answer~add(.MediaExperimentTask~new(definition~experimentId,selection~lineageId,selection,unit))
    end
  end
  return answer

::class MediaExperimentCandidate public
::method init
  expose candidateId experimentId lineageId methodologyId implementationId candidateKind workIds outputRef supportMapRef uncertaintyRef provenanceRefs metadata status
  use strict arg candidateIdArg, experimentIdArg, lineageIdArg, methodologyIdArg, implementationIdArg, candidateKindArg="ASSEMBLED", workIdsArg=.nil, outputRefArg="", supportMapRefArg=.nil, uncertaintyRefArg=.nil, provenanceRefsArg=.nil, metadataArg=.nil
  candidateId=strip(candidateIdArg)
  experimentId=strip(experimentIdArg)
  lineageId=strip(lineageIdArg)
  methodologyId=translate(strip(methodologyIdArg))
  implementationId=strip(implementationIdArg)
  candidateKind=translate(strip(candidateKindArg))
  outputRef=outputRefArg
  supportMapRef=supportMapRefArg
  uncertaintyRef=uncertaintyRefArg
  workIds=.Array~new
  if workIdsArg<>.nil then do workId over workIdsArg
    workIds~append(workId~string)
  end
  provenanceRefs=.Array~new
  if provenanceRefsArg<>.nil then do provenanceRef over provenanceRefsArg
    provenanceRefs~append(provenanceRef)
  end
  if metadataArg=.nil then metadataArg=.Directory~new
  metadata=metadataArg
  status="CANDIDATE"
  if candidateId="" | experimentId="" | lineageId="" | methodologyId="" then raise syntax 93.900 array("Candidate identity is incomplete")
::attribute candidateId get
::attribute experimentId get
::attribute lineageId get
::attribute methodologyId get
::attribute implementationId get
::attribute candidateKind get
::attribute outputRef get
::attribute supportMapRef get
::attribute uncertaintyRef get
::attribute status get
::method workIds
  expose workIds
  return workIds~copy
::method provenanceRefs
  expose provenanceRefs
  return provenanceRefs~copy
::method metadata
  expose metadata
  return metadata

/* Assembly is intentionally delegated.  COLLECT, OVERLAP_BLEND,
 * TRACK_COORDINATE_SUPPORT_MERGE and other merge modes are method semantics,
 * not generic orchestration semantics. */
::class MediaExperimentAssemblyRequest public
::method init
  expose experimentId lineageId methodologyId mergeMode candidates
  use strict arg experimentIdArg, lineageIdArg, methodologyIdArg, mergeModeArg, candidatesArg
  experimentId=strip(experimentIdArg)
  lineageId=strip(lineageIdArg)
  methodologyId=translate(strip(methodologyIdArg))
  mergeMode=translate(strip(mergeModeArg))
  candidates=.Array~new
  if candidatesArg<>.nil then do candidate over candidatesArg
    if \candidate~isA(.MediaExperimentCandidate) then raise syntax 93.900 array("MediaExperimentCandidate required")
    if candidate~experimentId<>experimentId then raise syntax 93.900 array("Candidate belongs to another experiment")
    if candidate~lineageId<>lineageId then raise syntax 93.900 array("Cross-lineage assembly is forbidden")
    candidates~append(candidate)
  end
::attribute experimentId get
::attribute lineageId get
::attribute methodologyId get
::attribute mergeMode get
::method candidates
  expose candidates
  return candidates~copy

::class MediaExperimentLineageAssembler public
::method assemble abstract

::class MediaExperimentComparisonObservation public
::method init
  expose leftId rightId relation metricId score evidenceRef metadata
  use strict arg leftIdArg, rightIdArg, relationArg, metricIdArg="", scoreArg=.nil, evidenceRefArg=.nil, metadataArg=.nil
  leftId=strip(leftIdArg)
  rightId=strip(rightIdArg)
  relation=translate(strip(relationArg))
  metricId=translate(strip(metricIdArg))
  score=scoreArg
  evidenceRef=evidenceRefArg
  if metadataArg=.nil then metadataArg=.Directory~new
  metadata=metadataArg
  if leftId="" | rightId="" then raise syntax 93.900 array("Comparison candidate ids are required")
  if relation<>"AGREE" then do
    if relation<>"DISAGREE" then do
      if relation<>"INCOMPARABLE" then do
        if relation<>"UNKNOWN" then raise syntax 93.900 array("Unknown comparison relation",relation)
      end
    end
  end
::attribute leftId get
::attribute rightId get
::attribute relation get
::attribute metricId get
::attribute score get
::attribute evidenceRef get
::method metadata
  expose metadata
  return metadata

::class MediaExperimentComparison public
::method init
  expose experimentId candidates observations
  use strict arg experimentIdArg
  experimentId=strip(experimentIdArg)
  candidates=.Directory~new
  observations=.Array~new
  if experimentId="" then raise syntax 93.900 array("Experiment id must not be empty")
::attribute experimentId get
::method addCandidate
  expose candidates experimentId
  use strict arg candidate
  if \candidate~isA(.MediaExperimentCandidate) then raise syntax 93.900 array("MediaExperimentCandidate required")
  if candidate~experimentId<>experimentId then raise syntax 93.900 array("Candidate belongs to another experiment")
  candidates[candidate~candidateId]=candidate
  return self
::method addObservation
  expose observations candidates
  use strict arg observation
  if \observation~isA(.MediaExperimentComparisonObservation) then raise syntax 93.900 array("MediaExperimentComparisonObservation required")
  if \candidates~hasIndex(observation~leftId) then raise syntax 93.900 array("Unknown left candidate")
  if \candidates~hasIndex(observation~rightId) then raise syntax 93.900 array("Unknown right candidate")
  observations~append(observation)
  return self
::method candidates
  expose candidates
  answer=.Array~new
  do candidate over candidates~allItems
    answer~append(candidate)
  end
  return answer
::method observations
  expose observations
  return observations~copy
::method relationCount
  expose observations
  use strict arg relationArg
  wanted=translate(strip(relationArg))
  count=0
  do observation over observations
    if observation~relation=wanted then count+=1
  end
  return count
::method disagreementPresent
  return self~relationCount("DISAGREE")>0
::method agreementPresent
  return self~relationCount("AGREE")>0
::method lineageCount
  expose candidates
  seen=.Directory~new
  do candidate over candidates~allItems
    seen[candidate~lineageId]=.true
  end
  return seen~items
::method winner
  /* Scientific comparison is evidence, not an automatic election. */
  return .nil

::class MediaExperimentComparator public
::method compare abstract

::class MediaExperimentComparisonEngine public
::method compareAll
  use strict arg experimentId, candidateList, comparator, context=.nil, crossLineageOnly=.true
  if comparator=.nil then raise syntax 93.900 array("Comparator is required")
  comparison=.MediaExperimentComparison~new(experimentId)
  do candidate over candidateList
    comparison~addCandidate(candidate)
  end
  count=candidateList~items
  leftIndex=1
  do while leftIndex<=count
    left=candidateList[leftIndex]
    rightIndex=leftIndex+1
    do while rightIndex<=count
      right=candidateList[rightIndex]
      comparePair=.true
      if crossLineageOnly then do
        if left~lineageId=right~lineageId then comparePair=.false
      end
      if comparePair then do
        observation=comparator~compare(left,right,context)
        if observation<>.nil then comparison~addObservation(observation)
      end
      rightIndex+=1
    end
    leftIndex+=1
  end
  return comparison

::requires "MediaMethodologyExecution.cls"
