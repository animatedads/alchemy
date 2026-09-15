/* MLMultiObjective.cls - Pareto analysis and branchable multi-objective evolution. */

::class MLObjectiveSet public
::attribute id
::attribute description
::method init
  expose objectives objectiveById
  use strict arg id,sourceObjectives,description=''
  if \sourceObjectives~isA(.Array) | sourceObjectives~items<2 then raise syntax 88.900 array('objective set requires at least two MLObjective objects')
  self~id=id; self~description=description; objectives=.array~new; objectiveById=.directory~new
  do objective over sourceObjectives
    if \objective~isA(.MLObjective) then raise syntax 88.900 array('objective set requires MLObjective')
    if objectiveById~hasIndex(objective~id) then raise syntax 88.900 array('duplicate objective id',objective~id)
    objectives~append(objective); objectiveById[objective~id]=objective
  end
::method items; expose objectives; return objectives~items
::method objectives
  expose objectives
  out=.array~new; do o over objectives; out~append(o); end; return out
::method objectiveIds
  expose objectives
  out=.array~new; do o over objectives; out~append(o~id); end; return out
::method objective
  expose objectiveById
  use strict arg id
  if objectiveById~hasIndex(id) then return objectiveById[id]
  return .nil
::method vector
  use strict arg scores
  return .MLObjectiveVector~new(self,scores)
::method relation
  use strict arg left,right
  if \left~isA(.MLObjectiveVector) | \right~isA(.MLObjectiveVector) then raise syntax 88.900 array('objective relation requires MLObjectiveVector')
  if left~objectiveSet~id\==self~id | right~objectiveSet~id\==self~id then raise syntax 88.900 array('objective vector set mismatch',self~id)
  leftBetter=.false; rightBetter=.false
  do objective over self~objectives
    l=left~score(objective~id); r=right~score(objective~id)
    if objective~better(l,r) then leftBetter=.true
    else if objective~better(r,l) then rightBetter=.true
  end
  if leftBetter & \rightBetter then return 'LEFT_DOMINATES'
  if rightBetter & \leftBetter then return 'RIGHT_DOMINATES'
  if \leftBetter & \rightBetter then return 'EQUIVALENT'
  return 'NON_DOMINATED'
::method dominates
  use strict arg left,right
  return self~relation(left,right)='LEFT_DOMINATES'
::method canonicalText
  lines=.array~new; lines~append('OBJECTIVE_SET='||self~id||'|description='||self~description)
  do o over self~objectives; lines~append(o~canonicalText); end
  return lines~makeString('L')

::class MLObjectiveVector public
::method init
  expose objectiveSet scores
  use strict arg objectiveSet,sourceScores
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('objective vector requires MLObjectiveSet')
  if \sourceScores~isA(.Directory) then raise syntax 88.900 array('objective vector scores must be Directory')
  ids=objectiveSet~objectiveIds
  if sourceScores~items<>ids~items then raise syntax 88.900 array('objective vector score count mismatch',sourceScores~items,ids~items)
  do id over ids
    if \sourceScores~hasIndex(id) then raise syntax 88.900 array('objective vector missing score',id)
  end
  do key over sourceScores~allIndexes
    if objectiveSet~objective(key)==.nil then raise syntax 88.900 array('objective vector has unknown score',key)
  end
  scores=.MLFrozenMap~new(sourceScores)
::method objectiveSet; expose objectiveSet; return objectiveSet
::method score; expose scores; use strict arg id; return scores[id]
::method scores; expose scores; return scores
::method canonicalText
  expose objectiveSet scores
  return 'OBJECTIVE_VECTOR='||objectiveSet~id||'|'||scores~canonicalText
::method string; return self~canonicalText

::class MLParetoPoint public
::attribute subjectId
::attribute subject
::attribute objectiveVector
::attribute evidence
::attribute rank
::attribute crowdingDistance
::method init
  use strict arg subjectId,subject,objectiveVector,evidence=.nil
  if subjectId='' then raise syntax 88.900 array('Pareto point requires subject id')
  if \objectiveVector~isA(.MLObjectiveVector) then raise syntax 88.900 array('Pareto point requires MLObjectiveVector')
  self~subjectId=subjectId; self~subject=subject; self~objectiveVector=objectiveVector; self~evidence=evidence
  self~rank=0; self~crowdingDistance=0
::method score; use strict arg objectiveId; return self~objectiveVector~score(objectiveId)
::method canonicalText
  return 'PARETO_POINT='||self~subjectId||'|rank='||self~rank||'|crowding='||self~crowdingDistance||'|'||self~objectiveVector~canonicalText

::class MLParetoFront public
::attribute rank
::method init
  expose points
  use strict arg rank,sourcePoints
  self~rank=rank; points=.array~new; do p over sourcePoints; points~append(p); end
::method items; expose points; return points~items
::method points
  expose points
  out=.array~new; do p over points; out~append(p); end; return out
::method point; expose points; use strict arg i; return points[i]
::method canonicalText
  expose points
  lines=.array~new; lines~append('PARETO_FRONT='||self~rank||'|items='||points~items)
  do p over points; lines~append(p~canonicalText); end
  return lines~makeString('L')

::class MLParetoResult public
::attribute objectiveSetId
::method init
  expose fronts pointsById
  use strict arg objectiveSetId,sourceFronts
  self~objectiveSetId=objectiveSetId; fronts=.array~new; pointsById=.directory~new
  do front over sourceFronts
    fronts~append(front)
    do p over front~points
      if pointsById~hasIndex(p~subjectId) then raise syntax 88.900 array('duplicate Pareto subject id',p~subjectId)
      pointsById[p~subjectId]=p
    end
  end
::method frontCount; expose fronts; return fronts~items
::method front; expose fronts; use strict arg rank; if rank<1 | rank>fronts~items then return .nil; return fronts[rank]
::method nonDominated; return self~front(1)~points
::method point
  expose pointsById
  use strict arg id
  if pointsById~hasIndex(id) then return pointsById[id]
  return .nil
::method allPoints
  expose fronts
  out=.array~new; do f over fronts; do p over f~points; out~append(p); end; end; return out
::method canonicalText
  expose fronts
  lines=.array~new; lines~append('PARETO_RESULT='||self~objectiveSetId||'|fronts='||fronts~items)
  do f over fronts; lines~append(f~canonicalText); end
  return lines~makeString('L')

::class MLParetoAnalyzer public
::method analyze class
  use strict arg objectiveSet,sourcePoints
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('Pareto analysis requires MLObjectiveSet')
  if \sourcePoints~isA(.Array) | sourcePoints~items=0 then raise syntax 88.900 array('Pareto analysis requires nonempty Array')
  remaining=.array~new; seen=.directory~new
  do p over sourcePoints
    if \p~isA(.MLParetoPoint) then raise syntax 88.900 array('Pareto analysis requires MLParetoPoint')
    if p~objectiveVector~objectiveSet~id\==objectiveSet~id then raise syntax 88.900 array('Pareto point objective set mismatch',p~subjectId)
    if seen~hasIndex(p~subjectId) then raise syntax 88.900 array('duplicate Pareto point id',p~subjectId)
    seen[p~subjectId]=1; remaining~append(p)
  end
  fronts=.array~new; rank=1
  do while remaining~items>0
    members=.array~new
    do candidate over remaining
      dominated=.false
      do other over remaining
        if other~subjectId==candidate~subjectId then iterate
        if objectiveSet~dominates(other~objectiveVector,candidate~objectiveVector) then do; dominated=.true; leave; end
      end
      if \dominated then members~append(candidate)
    end
    if members~items=0 then raise syntax 88.900 array('Pareto analysis failed to find non-dominated front')
    self~assignCrowding(objectiveSet,members,rank)
    fronts~append(.MLParetoFront~new(rank,members))
    next=.array~new
    do candidate over remaining
      found=.false
      do member over members
        if member~subjectId==candidate~subjectId then do; found=.true; leave; end
      end
      if \found then next~append(candidate)
    end
    remaining=next; rank=rank+1
  end
  return .MLParetoResult~new(objectiveSet~id,fronts)
::method assignCrowding class private
  use strict arg objectiveSet,points,rank
  n=points~items
  do p over points; p~rank=rank; p~crowdingDistance=0; end
  if n<=2 then do; do p over points; p~crowdingDistance=1E99; end; return; end
  do objective over objectiveSet~objectives
    ordered=.array~new; do p over points; ordered~append(p); end
    ordered~sortWith(.MLParetoObjectiveComparator~new(objective~id))
    ordered[1]~crowdingDistance=1E99; ordered[n]~crowdingDistance=1E99
    low=ordered[1]~score(objective~id); high=ordered[n]~score(objective~id); span=high-low; if span<0 then span=-span
    if span=0 then iterate
    do i=2 to n-1
      if ordered[i]~crowdingDistance>=1E98 then iterate
      delta=ordered[i+1]~score(objective~id)-ordered[i-1]~score(objective~id); if delta<0 then delta=-delta
      ordered[i]~crowdingDistance=ordered[i]~crowdingDistance+(delta/span)
    end
  end

::class MLParetoObjectiveComparator public
::method init
  expose objectiveId
  use strict arg objectiveId
::method compare
  expose objectiveId
  use strict arg a,b
  av=a~score(objectiveId); bv=b~score(objectiveId)
  if av<bv then return -1
  if av>bv then return 1
  if a~subjectId<b~subjectId then return -1
  if a~subjectId>b~subjectId then return 1
  return 0

::class MLParetoSelectionComparator public
::method compare
  use strict arg a,b
  if a~rank<b~rank then return -1
  if a~rank>b~rank then return 1
  if a~crowdingDistance>b~crowdingDistance then return -1
  if a~crowdingDistance<b~crowdingDistance then return 1
  if a~subjectId<b~subjectId then return -1
  if a~subjectId>b~subjectId then return 1
  return 0

::class MLParetoRetentionSelector public
::method select class
  use strict arg result,retentionPolicy
  if \result~isA(.MLParetoResult) then raise syntax 88.900 array('Pareto retention requires MLParetoResult')
  if \retentionPolicy~isA(.MLRetentionPolicy) then raise syntax 88.900 array('Pareto retention requires MLRetentionPolicy')
  limit=retentionPolicy~retainCount; out=.array~new
  if limit=0 then return out
  do r=1 to result~frontCount
    members=result~front(r)~points; members~sortWith(.MLParetoSelectionComparator~new)
    do p over members
      out~append(p)
      if out~items>=limit then return out
    end
  end
  return out

::class MLParetoEvolutionGeneration public
::attribute id
::attribute populationGeneration
::attribute branch
::attribute checkpointId
::attribute analysis
::attribute nonDominatedCount
::method init
  use strict arg id,populationGeneration,branch,checkpointId,analysis
  self~id=id; self~populationGeneration=populationGeneration; self~branch=branch; self~checkpointId=checkpointId; self~analysis=analysis
  self~nonDominatedCount=analysis~front(1)~items
::method canonicalText
  return 'PARETO_GENERATION='||self~id||'|population='||self~populationGeneration||'|branch='||self~branch||'|checkpoint='||self~checkpointId||'|front1='||self~nonDominatedCount||'0a'x||self~analysis~canonicalText

::class MLParetoEvolutionGenerationRegistry public
::method init
  expose generations nextId
  generations=.directory~new; nextId=1
::method publish
  expose generations nextId
  use strict arg populationGeneration,branch,checkpointId,analysis
  id='PEG'||nextId; nextId=nextId+1
  generation=.MLParetoEvolutionGeneration~new(id,populationGeneration,branch,checkpointId,analysis)
  generations[id]=generation; return generation
::method generation
  expose generations
  use strict arg id
  if generations~hasIndex(id) then return generations[id]
  return .nil
::method generations
  expose generations
  ids=generations~allIndexes; ids~sort; out=.array~new; do id over ids; out~append(generations[id]); end; return out
::method count; expose generations; return generations~items

::class MLParetoGARunResult public
::attribute breedingSteps
::attribute initialPopulationGeneration
::attribute finalPopulationGeneration
::attribute finalEvaluation
::attribute finalCheckpoint
::method init
  expose steps
  use strict arg sourceSteps,initialPopulationGeneration,finalPopulationGeneration,finalEvaluation,finalCheckpoint
  steps=.array~new; do s over sourceSteps; steps~append(s); end
  self~breedingSteps=steps~items; self~initialPopulationGeneration=initialPopulationGeneration; self~finalPopulationGeneration=finalPopulationGeneration
  self~finalEvaluation=finalEvaluation; self~finalCheckpoint=finalCheckpoint
::method steps
  expose steps
  out=.array~new; do s over steps; out~append(s); end; return out
::method canonicalText
  return 'PARETO_GA_RUN=steps='||self~breedingSteps||'|initial='||self~initialPopulationGeneration||'|final='||self~finalPopulationGeneration||'|front1='||self~finalEvaluation~nonDominatedCount||'|checkpoint='||self~finalCheckpoint~checkpointId

::class MLParetoGeneticAlgorithm public
::method init
  expose experiment population rng objectiveSet policy registry
  use strict arg population,objectiveSet,rng=.nil,experiment=.nil,policy=.nil
  if \population~isA(.MLPopulation) then raise syntax 88.900 array('Pareto GA requires MLPopulation')
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('Pareto GA requires MLObjectiveSet')
  if rng==.nil then rng=.MLDeterministicRNG~new(1,'PARETO-RNG')
  if experiment==.nil then experiment=.MLExperiment~new('PARETO-GA')
  if policy==.nil then policy=.MLGeneticPolicy~new
  if \policy~isA(.MLGeneticPolicy) then raise syntax 88.900 array('Pareto GA requires MLGeneticPolicy')
  registry=.MLParetoEvolutionGenerationRegistry~new
  if experiment~participant('population')==.nil then experiment~register('population',population)
  if experiment~participant('rng')==.nil then experiment~register('rng',rng)
  root=experiment~checkpoint('pareto-ga-initial','PARETO_GA_INITIAL')
::method experiment; expose experiment; return experiment
::method population; expose population; return population
::method rng; expose rng; return rng
::method objectiveSet; expose objectiveSet; return objectiveSet
::method policy; expose policy; return policy
::method generationRegistry; expose registry; return registry
::method evaluateCurrent
  expose experiment population registry
  use strict arg evaluator,tag='PARETO_GA_FINAL_EVALUATION'
  before=experiment~checkpoint('before-pareto-evaluation',tag)
  signal on syntax name EvaluationFailed
  analysis=self~evaluatePopulation(evaluator)
  after=experiment~checkpoint('after-pareto-evaluation',tag)
  generation=registry~publish(population~generation,experiment~currentBranch,after~checkpointId,analysis)
  out=.directory~new; out['before']=before; out['after']=after; out['evaluatedGeneration']=generation; out['populationGeneration']=population~generation
  return out
EvaluationFailed:
  experiment~rollback(before,'failed-pareto-evaluation-'||(registry~count+1))
  raise propagate
::method run
  expose population
  use strict arg evaluator,breedingSteps=1
  if breedingSteps<1 then raise syntax 88.900 array('Pareto GA run requires at least one breeding step')
  startGeneration=population~generation; steps=.array~new
  do g=1 to breedingSteps; steps~append(self~step(evaluator)); end
  final=self~evaluateCurrent(evaluator,'PARETO_GA_RUN_FINAL_EVALUATION')
  return .MLParetoGARunResult~new(steps,startGeneration,population~generation,final['evaluatedGeneration'],final['after'])
::method step
  expose experiment population rng policy registry
  use strict arg evaluator
  before=experiment~checkpoint('before-pareto-generation','PARETO_GA_GENERATION')
  signal on syntax name StepFailed
  analysis=self~evaluatePopulation(evaluator)
  ranked=analysis~allPoints; ranked~sortWith(.MLParetoSelectionComparator~new)
  cursor=rng~cursor; next=.array~new
  eliteCount=policy~eliteCount; if eliteCount>population~populationSize then eliteCount=population~populationSize
  do e=1 to eliteCount
    point=ranked[e]; next~append(.MLGenome~new('G'||(population~generation+1)||'-E'||e,point~subject~genes~toArray))
  end
  childIndex=next~items+1
  do while next~items<population~populationSize
    p1=self~tournament(ranked,cursor); p2=self~tournament(ranked,cursor)
    genes=self~breed(p1~subject,p2~subject,cursor)
    next~append(.MLGenome~new('G'||(population~generation+1)||'-I'||childIndex,genes)); childIndex=childIndex+1
  end
  rng~commitCursor(cursor,'PARETO_GA_RNG_GENERATION')
  evaluatedGeneration=population~generation
  population~replaceGeneration(next,evaluatedGeneration+1,'PARETO_GA_NEXT_GENERATION')
  after=experiment~checkpoint('after-pareto-generation','PARETO_GA_GENERATION')
  generation=registry~publish(evaluatedGeneration,experiment~currentBranch,after~checkpointId,analysis)
  out=.directory~new; out['before']=before; out['after']=after; out['evaluatedGeneration']=generation; out['newPopulationGeneration']=population~generation; out['newPopulationEvaluated']=.false
  return out
StepFailed:
  experiment~rollback(before,'failed-pareto-generation-'||(registry~count+1))
  raise propagate
::method evaluatePopulation private
  expose population objectiveSet
  use strict arg evaluator
  points=.array~new
  do genome over population~genomes
    scores=evaluator~scores(genome)
    vector=objectiveSet~vector(scores)
    points~append(.MLParetoPoint~new(genome~id,genome,vector))
  end
  return .MLParetoAnalyzer~analyze(objectiveSet,points)
::method tournament private
  use strict arg ranked,cursor
  a=ranked[cursor~nextInt(ranked~items)]; b=ranked[cursor~nextInt(ranked~items)]
  cmp=.MLParetoSelectionComparator~new~compare(a,b)
  if cmp<=0 then return a
  return b
::method breed private
  expose policy
  use strict arg g1,g2,cursor
  if g1~geneCount<>g2~geneCount then raise syntax 88.900 array('Pareto GA parent gene-count mismatch')
  n=g1~geneCount; out=.array~new; useCross=cursor~nextUnit<policy~crossoverRate
  if n>1 & useCross then split=cursor~nextInt(n-1); else split=n
  do i=1 to n
    if useCross & i>split then value=g2~gene(i); else value=g1~gene(i)
    if cursor~nextUnit<policy~mutationRate then value=value+((cursor~nextUnit*2-1)*policy~mutationScale)
    out~append(value)
  end
  return out

::class MLParetoSearchCandidate public
::attribute id
::attribute laneId
::attribute configuration
::attribute objectiveVector
::attribute evidence
::attribute materialRefs
::method init
  use strict arg id,laneId,configuration,objectiveVector,evidence=.nil,materialRefs=.nil
  if \configuration~isA(.Directory) then raise syntax 88.900 array('Pareto candidate configuration must be Directory')
  if \objectiveVector~isA(.MLObjectiveVector) then raise syntax 88.900 array('Pareto candidate requires MLObjectiveVector')
  if materialRefs==.nil then materialRefs=.array~new
  self~id=id; self~laneId=laneId; self~configuration=.MLFrozenMap~new(configuration); self~objectiveVector=objectiveVector; self~evidence=evidence; self~materialRefs=.MLFrozenVector~new(materialRefs)
::method paretoPoint
  return .MLParetoPoint~new(self~id,self,self~objectiveVector,self~evidence)
::method canonicalText
  return 'PARETO_CANDIDATE='||self~id||'|lane='||self~laneId||'|'||self~objectiveVector~canonicalText||'|'||self~configuration~canonicalText

::class MLParetoSearchAnalysis public
::method analyze class
  use strict arg objectiveSet,candidates
  if \candidates~isA(.Array) | candidates~items=0 then raise syntax 88.900 array('Pareto search analysis requires nonempty Array')
  points=.array~new
  do c over candidates
    if \c~isA(.MLParetoSearchCandidate) then raise syntax 88.900 array('Pareto search analysis requires MLParetoSearchCandidate')
    points~append(c~paretoPoint)
  end
  return .MLParetoAnalyzer~analyze(objectiveSet,points)

::requires "MLSearch.cls"
::requires "MLEvolution.cls"
