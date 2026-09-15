/* Cross-clip, source-scoped scene memory for Camera Behaviour v0.55.
   This memory stores recurring scene context and low-quality fragment evidence.
   It never turns transient LT<n> tracks into identities. */

::class CameraSceneFingerprint public
::attribute activeCellCount get
::attribute directionStepCount get

::method init
  expose activeCellCount directionStepCount keys directions
  use arg segment
  keys=.array~new
  do entry over segment~priors~entries
    keys~append(entry~column || ',' || entry~row)
  end
  keys~sort
  activeCellCount=keys~items

  profile=segment~directionProfile
  directions=.array~of(profile~upCount,profile~downCount,profile~leftCount,profile~rightCount,profile~upLeftCount,profile~upRightCount,profile~downLeftCount,profile~downRightCount,profile~stationaryCount)
  directionStepCount=profile~stepCount

::method containsKey private
  expose keys
  use arg wanted
  do key over keys
    if key==wanted then return .true
  end
  return .false

::method activeCoverage
  expose keys
  use arg other
  if other==.nil then return 0
  otherKeys=other~activeKeys
  if keys~items=0 & otherKeys~items=0 then return 1
  if keys~items=0 | otherKeys~items=0 then return 0
  intersection=0
  do key over keys
    if other~hasActiveKey(key) then intersection=intersection+1
  end
  smaller=keys~items
  if otherKeys~items<smaller then smaller=otherKeys~items
  if smaller=0 then return 0
  return intersection/smaller

::method directionSimilarity
  expose directions directionStepCount
  use arg other
  if other==.nil then return 0
  otherDirections=other~directionValues
  otherSteps=other~directionStepCount
  if directionStepCount=0 & otherSteps=0 then return 1
  if directionStepCount=0 | otherSteps=0 then return 0.5
  distance=0
  do i=1 to directions~items
    p=directions[i]/directionStepCount
    q=otherDirections[i]/otherSteps
    distance=distance+abs(p-q)
  end
  return 1-(distance/2)

::method similarityTo
  use arg other
  topology=self~activeCoverage(other)
  direction=self~directionSimilarity(other)
  return (topology*0.8)+(direction*0.2)

::method activeKeys
  expose keys
  out=.array~new
  do key over keys
    out~append(key)
  end
  return out

::method hasActiveKey
  use arg key
  return self~containsKey(key)

::method directionValues
  expose directions
  out=.array~new
  do value over directions
    out~append(value)
  end
  return out

::method compactText
  expose keys directions
  keyBody=''
  do key over keys
    if keyBody=='' then keyBody=key
    else keyBody=keyBody || ';' || key
  end
  dirBody=''
  do value over directions
    if dirBody=='' then dirBody=value
    else dirBody=dirBody || ',' || value
  end
  return 'CSF1|A=' || self~activeCellCount || '|D=' || self~directionStepCount || '|K=' || keyBody || '|V=' || dirBody


::class CameraSceneCellMemory public
::attribute column get
::attribute row get
::attribute observedSegments get
::attribute activeSegments get
::attribute persistenceTotal get
::attribute maximumDelta get

::method init
  expose column row observedSegments activeSegments persistenceTotal maximumDelta
  use arg col,rowIndex
  column=col
  row=rowIndex
  observedSegments=0
  activeSegments=0
  persistenceTotal=0
  maximumDelta=0

::method observe
  expose observedSegments activeSegments persistenceTotal maximumDelta
  use arg active,persistence,maxDelta
  observedSegments=observedSegments+1
  if active then do
    activeSegments=activeSegments+1
    persistenceTotal=persistenceTotal+persistence
    if maxDelta>maximumDelta then maximumDelta=maxDelta
  end
  return observedSegments

::method activeSegmentShare
  expose observedSegments activeSegments
  if observedSegments=0 then return 0
  return activeSegments/observedSegments

::method meanPersistenceWhenActive
  expose activeSegments persistenceTotal
  if activeSegments=0 then return 0
  return persistenceTotal/activeSegments

::method compactText
  return self~column || ',' || self~row || ':' || self~observedSegments || ':' || self~activeSegments || ':' || self~activeSegmentShare || ':' || self~meanPersistenceWhenActive || ':' || self~maximumDelta


::class CameraSceneArtifactMemory public
::attribute key get
::attribute reason get
::attribute column get
::attribute row get
::attribute occurrenceCount get
::attribute clipCount get
::attribute maximumScore get

::method init
  expose key reason column row occurrenceCount clipCount maximumScore clips
  use arg rejectionReason,col,rowIndex
  reason=rejectionReason
  column=col
  row=rowIndex
  key=reason || '@' || column || ',' || row
  occurrenceCount=0
  clipCount=0
  maximumScore=0
  clips=.directory~new

::method observe
  expose occurrenceCount clipCount maximumScore clips
  use arg clipToken,score
  occurrenceCount=occurrenceCount+1
  if clips[clipToken]==.nil then do
    clips[clipToken]=.true
    clipCount=clipCount+1
  end
  if score>maximumScore then maximumScore=score
  return occurrenceCount

::method recurring
  return self~clipCount>=2

::method compactText
  return self~key || ':' || self~occurrenceCount || ':' || self~clipCount || ':' || self~maximumScore


::class CameraSceneGenerationMemory public
::attribute id get
::attribute sourceKey get
::attribute segmentCount get
::attribute comparisonCount get
::attribute activeCellObservationCount get
::attribute artifactCount get
::attribute recurringArtifactCount get
::attribute lastFingerprint get

::method init
  expose id sourceKey segmentCount comparisonCount activeCellObservationCount artifactCount recurringArtifactCount gridColumns gridRows cells artifacts lastFingerprint
  use arg generationId,key,columns,rows
  id=generationId
  sourceKey=key
  gridColumns=columns
  gridRows=rows
  segmentCount=0
  comparisonCount=0
  activeCellObservationCount=0
  artifactCount=0
  recurringArtifactCount=0
  cells=.array~new
  do row=1 to rows
    do column=1 to columns
      cells~append(.CameraSceneCellMemory~new(column,row))
    end
  end
  artifacts=.directory~new
  lastFingerprint=.nil

::method cell
  expose cells gridColumns
  use arg column,row
  index=((row-1)*gridColumns)+column
  if index<1 | index>cells~items then return .nil
  return cells[index]

::method observeSegment
  expose segmentCount comparisonCount activeCellObservationCount gridColumns gridRows cells artifacts artifactCount recurringArtifactCount lastFingerprint
  use arg segment,qualitySet,clipToken
  segmentCount=segmentCount+1
  comparisonCount=comparisonCount+segment~priors~comparisonCount
  lastFingerprint=.CameraSceneFingerprint~new(segment)

  /* priors are exposed as canonical entry objects by v0.55 */
  priorByKey=.directory~new
  do entry over segment~priors~entries
    priorByKey[entry~column || ',' || entry~row]=entry
  end

  do row=1 to gridRows
    do column=1 to gridColumns
      key=column || ',' || row
      entry=priorByKey[key]
      cell=self~cell(column,row)
      if entry==.nil then ignored=cell~observe(.false,0,0)
      else do
        ignored=cell~observe(.true,entry~persistence,entry~maximumDelta)
        activeCellObservationCount=activeCellObservationCount+1
      end
    end
  end

  if qualitySet\==.nil then do assessment over qualitySet~assessments
    if assessment~admitted then iterate
    track=.nil
    do candidate over segment~trackSet~tracks
      if candidate~id==assessment~trackId then do
        track=candidate
        leave
      end
    end
    if track==.nil then iterate
    regions=track~regions
    if regions~items=0 then iterate
    sumX=0
    sumY=0
    do region over regions
      sumX=sumX+region~centerX
      sumY=sumY+region~centerY
    end
    column=trunc((sumX/regions~items)+0.5)
    row=trunc((sumY/regions~items)+0.5)
    if column<1 then column=1
    if column>gridColumns then column=gridColumns
    if row<1 then row=1
    if row>gridRows then row=gridRows
    artifactKey=assessment~reason || '@' || column || ',' || row
    artifact=artifacts[artifactKey]
    if artifact==.nil then do
      artifact=.CameraSceneArtifactMemory~new(assessment~reason,column,row)
      artifacts[artifactKey]=artifact
      artifactCount=artifactCount+1
    end
    wasRecurring=artifact~recurring
    ignoredArtifact=artifact~observe(clipToken,assessment~score)
    if \wasRecurring & artifact~recurring then recurringArtifactCount=recurringArtifactCount+1
  end
  return segmentCount

::method artifact
  expose artifacts
  use arg reason,column,row
  return artifacts[reason || '@' || column || ',' || row]

::method knownArtifactZone
  use arg column,row
  recurring=self~recurringArtifacts
  do artifact over recurring
    if artifact~column==column & artifact~row==row then return .true
  end
  return .false

::method recurringReasonsAt
  use arg column,row
  out=.array~new
  recurring=self~recurringArtifacts
  do artifact over recurring
    if artifact~column==column & artifact~row==row then out~append(artifact~reason)
  end
  out~sort
  return out

::method knownArtifact
  use arg reason,column,row
  artifact=self~artifact(reason,column,row)
  if artifact==.nil then return .false
  return artifact~recurring

::method recurringArtifacts
  expose artifacts
  out=.array~new
  values=artifacts~allItems
  do artifact over values
    if artifact~recurring then out~append(artifact)
  end
  return out

::method compactText
  expose cells artifacts
  recurring=self~recurringArtifacts
  recurringTokens=.array~new
  do artifact over recurring
    recurringTokens~append(artifact~compactText)
  end
  recurringTokens~sort
  artifactBody=''
  do token over recurringTokens
    if artifactBody=='' then artifactBody=token
    else artifactBody=artifactBody || ';' || token
  end

  stableTokens=.array~new
  do cell over cells
    if cell~observedSegments<2 then iterate
    if cell~activeSegmentShare=0 then iterate
    stableTokens~append(cell~compactText)
  end
  stableTokens~sort
  cellBody=''
  do token over stableTokens
    if cellBody=='' then cellBody=token
    else cellBody=cellBody || ';' || token
  end
  return 'CSGM1|ID=' || self~id || '|SRC=' || self~sourceKey || '|SEG=' || self~segmentCount || '|CMP=' || self~comparisonCount || '|ACO=' || self~activeCellObservationCount || '|ART=' || self~artifactCount || '|RART=' || self~recurringArtifactCount || '|CELLS=' || cellBody || '|RA=' || artifactBody


::class CameraSceneAwarePrimitiveAssessment public
::attribute trackId get
::attribute baseQuality get
::attribute sceneGenerationId get
::attribute sourceKey get
::attribute column get
::attribute row get
::attribute exactRecurringArtifact get
::attribute recurringArtifactZone get
::attribute contextState get
::attribute contextReason get

::method init
  expose trackId baseQuality sceneGenerationId sourceKey column row exactRecurringArtifact recurringArtifactZone contextState contextReason recurringReasons
  use arg quality,track,generation,expectedSourceKey

  trackId=''
  baseQuality=quality
  sceneGenerationId=''
  sourceKey=''
  column=0
  row=0
  exactRecurringArtifact=.false
  recurringArtifactZone=.false
  contextState='NO_SCENE_CONTEXT'
  contextReason='NO_GENERATION'
  recurringReasons=.array~new

  if quality\==.nil then trackId=quality~trackId
  if track\==.nil then do
    regions=track~regions
    if regions~items>0 then do
      sumX=0
      sumY=0
      do region over regions
        sumX=sumX+region~centerX
        sumY=sumY+region~centerY
      end
      column=trunc((sumX/regions~items)+0.5)
      row=trunc((sumY/regions~items)+0.5)
    end
  end

  if generation==.nil then return

  sceneGenerationId=generation~id
  sourceKey=generation~sourceKey
  if expectedSourceKey\=='' & sourceKey\==expectedSourceKey then do
    contextReason='SOURCE_KEY_MISMATCH'
    return
  end

  if quality==.nil then do
    contextReason='NO_QUALITY'
    return
  end

  if quality~admitted then do
    contextState='ADMITTED_MOTION'
    contextReason='QUALITY_ADMIT'
    return
  end

  if column<1 | row<1 then do
    contextState='NOVEL_LOW_QUALITY_FRAGMENT'
    contextReason='NO_SPATIAL_ZONE'
    return
  end

  exactRecurringArtifact=generation~knownArtifact(quality~reason,column,row)
  recurringArtifactZone=generation~knownArtifactZone(column,row)
  recurringReasons=generation~recurringReasonsAt(column,row)

  if recurringArtifactZone then do
    contextState='EXPECTED_SCENE_ACTIVITY'
    if exactRecurringArtifact then contextReason='EXACT_RECURRING_' || quality~reason
    else contextReason='RECURRING_ZONE'
  end
  else do
    contextState='NOVEL_LOW_QUALITY_FRAGMENT'
    contextReason='HISTORICALLY_UNSEEN_ZONE'
  end

::method recurringReasons
  expose recurringReasons
  out=.array~new
  do reason over recurringReasons
    out~append(reason)
  end
  return out

::method compactText
  expose recurringReasons baseQuality
  body=''
  do reason over recurringReasons
    if body=='' then body=reason
    else body=body || ',' || reason
  end
  if baseQuality==.nil then base=''
  else base=baseQuality~reason
  return 'CSAQ1|ID=' || self~trackId || '|G=' || self~sceneGenerationId || '|SRC=' || self~sourceKey || '|Z=' || self~column || ',' || self~row || '|BQ=' || base || '|EX=' || self~exactRecurringArtifact || '|RZ=' || self~recurringArtifactZone || '|STATE=' || self~contextState || '|WHY=' || self~contextReason || '|RR=' || body


::class CameraSceneAwareQualitySet public
::attribute totalCount get
::attribute expectedSceneCount get
::attribute novelFragmentCount get
::attribute admittedMotionCount get
::attribute noContextCount get

::method init
  expose totalCount expectedSceneCount novelFragmentCount admittedMotionCount noContextCount assessments
  use arg segment,generation,expectedSourceKey,minimumObservations,minimumScore
  if arg(4,'O') then minimumObservations=2
  if arg(5,'O') then minimumScore=4
  totalCount=0
  expectedSceneCount=0
  novelFragmentCount=0
  admittedMotionCount=0
  noContextCount=0
  assessments=.array~new
  if segment==.nil then return

  qualitySet=.CameraLumaBehaviourBridge~quality(segment~trackSet,16,9,minimumObservations,minimumScore)
  do track over segment~trackSet~tracks
    quality=qualitySet~assessment(track~id)
    assessment=.CameraSceneAwarePrimitiveAssessment~new(quality,track,generation,expectedSourceKey)
    assessments~append(assessment)
    totalCount=totalCount+1
    select
      when assessment~contextState=='EXPECTED_SCENE_ACTIVITY' then expectedSceneCount=expectedSceneCount+1
      when assessment~contextState=='NOVEL_LOW_QUALITY_FRAGMENT' then novelFragmentCount=novelFragmentCount+1
      when assessment~contextState=='ADMITTED_MOTION' then admittedMotionCount=admittedMotionCount+1
      otherwise noContextCount=noContextCount+1
    end
  end

::method expectedSceneAssessments
  expose assessments
  out=.array~new
  do assessment over assessments
    if assessment~contextState=='EXPECTED_SCENE_ACTIVITY' then out~append(assessment)
  end
  return out

::method novelFragmentAssessments
  expose assessments
  out=.array~new
  do assessment over assessments
    if assessment~contextState=='NOVEL_LOW_QUALITY_FRAGMENT' then out~append(assessment)
  end
  return out

::method admittedMotionAssessments
  expose assessments
  out=.array~new
  do assessment over assessments
    if assessment~contextState=='ADMITTED_MOTION' then out~append(assessment)
  end
  return out

::method assessments
  expose assessments
  out=.array~new
  do assessment over assessments
    out~append(assessment)
  end
  return out

::method assessment
  expose assessments
  use arg trackId
  do assessment over assessments
    if assessment~trackId==trackId then return assessment
  end
  return .nil

::method compactText
  expose assessments
  tokens=.array~new
  do assessment over assessments
    tokens~append(assessment~compactText)
  end
  tokens~sort
  body=''
  do token over tokens
    if body=='' then body=token
    else body=body || ';' || token
  end
  return 'CSAQSET1|N=' || self~totalCount || '|EXP=' || self~expectedSceneCount || '|NOV=' || self~novelFragmentCount || '|ADM=' || self~admittedMotionCount || '|NC=' || self~noContextCount || '|A=' || body


::class CameraSceneMemory public
::attribute generationCount get
::attribute observationCount get
::attribute sceneSimilarityThreshold get
::attribute lastSceneSimilarity get

::method init
  expose generationCount observationCount generations currentBySource nextGeneration sceneSimilarityThreshold lastSceneSimilarity
  generationCount=0
  observationCount=0
  generations=.array~new
  currentBySource=.directory~new
  nextGeneration=1
  sceneSimilarityThreshold=0.65
  lastSceneSimilarity=1

::method newGeneration private
  expose generationCount generations currentBySource nextGeneration
  use arg sourceKey,columns,rows
  id='SG' || nextGeneration
  nextGeneration=nextGeneration+1
  generation=.CameraSceneGenerationMemory~new(id,sourceKey,columns,rows)
  generations~append(generation)
  currentBySource[sourceKey]=generation
  generationCount=generationCount+1
  return generation

::method currentGeneration
  expose currentBySource
  use arg sourceKey
  return currentBySource[sourceKey]

::method generations
  expose generations
  out=.array~new
  do generation over generations
    out~append(generation)
  end
  return out

::method observeSegment
  expose observationCount currentBySource sceneSimilarityThreshold lastSceneSimilarity
  use arg sourceKey,segment,qualitySet,clipToken,forceNewGeneration
  if arg(4,'O') | clipToken=='' then clipToken=segment~id
  if arg(5,'O') then forceNewGeneration=.false
  generation=currentBySource[sourceKey]
  fingerprint=.CameraSceneFingerprint~new(segment)
  if generation==.nil then do
    generation=self~newGeneration(sourceKey,segment~priors~gridColumns,segment~priors~gridRows)
    lastSceneSimilarity=1
  end
  else if forceNewGeneration then do
    generation=self~newGeneration(sourceKey,segment~priors~gridColumns,segment~priors~gridRows)
    lastSceneSimilarity=0
  end
  else do
    previousFingerprint=generation~lastFingerprint
    if previousFingerprint==.nil then lastSceneSimilarity=1
    else lastSceneSimilarity=fingerprint~similarityTo(previousFingerprint)
    if lastSceneSimilarity<sceneSimilarityThreshold then generation=self~newGeneration(sourceKey,segment~priors~gridColumns,segment~priors~gridRows)
  end

  ignored=generation~observeSegment(segment,qualitySet,clipToken)
  observationCount=observationCount+1
  return generation

::method observeAnalysis
  use arg sourceKey,segmentedAnalysis,minimumObservations,minimumScore,clipToken
  if arg(3,'O') then minimumObservations=2
  if arg(4,'O') then minimumScore=4
  if arg(5,'O') | clipToken=='' then clipToken=segmentedAnalysis~sourcePath
  out=.array~new
  segmentIndex=0
  do segment over segmentedAnalysis~segments
    segmentIndex=segmentIndex+1
    quality=.CameraLumaBehaviourBridge~quality(segment~trackSet,16,9,minimumObservations,minimumScore)
    forceNew=(segmentIndex>1)
    generation=self~observeSegment(sourceKey,segment,quality,clipToken || ':' || segment~id,forceNew)
    out~append(generation)
  end
  return out

::method compactText
  expose generations
  body=''
  do generation over generations
    if body=='' then body=generation~compactText
    else body=body || ';' || generation~compactText
  end
  return 'CSM1|G=' || self~generationCount || '|O=' || self~observationCount || '|M=' || body

::method assessSegment
  expose currentBySource
  use arg sourceKey,segment,minimumObservations,minimumScore
  if arg(3,'O') then minimumObservations=2
  if arg(4,'O') then minimumScore=4
  generation=currentBySource[sourceKey]
  return .CameraSceneAwareQualitySet~new(segment,generation,sourceKey,minimumObservations,minimumScore)

::requires 'CameraLumaBehaviourBridge.cls'
