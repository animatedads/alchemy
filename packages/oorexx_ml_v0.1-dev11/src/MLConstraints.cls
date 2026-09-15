/* MLConstraints.cls - hard feasibility constraints and constrained Pareto evolution.
 *
 * Hard constraints are gates, not objectives.  An infeasible candidate may remain
 * useful search evidence, but it cannot enter a Pareto front or be promoted as a
 * valid answer merely because it is excellent on some objective.
 */

::class MLConstraintResult public
::attribute constraintId
::attribute passed
::attribute detail
::attribute evidence
::method init
  use strict arg constraintId,passed,detail='',evidence=.nil
  self~constraintId=constraintId; self~passed=(passed==.true); self~detail=detail; self~evidence=evidence
::method canonicalText
  return 'CONSTRAINT_RESULT='||self~constraintId||'|passed='||self~passed||'|detail='||self~detail

::class MLHardConstraint public
::attribute id
::attribute description
::method init
  use strict arg id,description=''
  if id='' then raise syntax 88.900 array('hard constraint id must not be empty')
  self~id=id; self~description=description
::method assess
  use strict arg subject
  raise syntax 88.900 array('hard constraint must implement assess()',self~id)
::method canonicalText
  return 'HARD_CONSTRAINT='||self~id||'|description='||self~description

::class MLDirectoryFieldConstraint subclass MLHardConstraint public
::attribute field
::attribute relation
::attribute expected
::method init
  expose target
  use strict arg id,field,relation,expected,description='',target='SELF'
  self~init:super(id,description)
  r=relation~translate
  if r<>'LE' & r<>'LT' & r<>'GE' & r<>'GT' & r<>'EQ' & r<>'NE' then raise syntax 88.900 array('unsupported hard-constraint relation',relation)
  t=target~translate
  if t<>'SELF' & t<>'CONFIGURATION' & t<>'EVIDENCE' then raise syntax 88.900 array('unsupported hard-constraint target',target)
  self~field=field; self~relation=r; self~expected=expected; target=t
::method target; expose target; return target
::method assess
  expose target
  use strict arg subject
  map=self~resolveMap(subject,target)
  if map==.nil then return .MLConstraintResult~new(self~id,.false,'TARGET_NOT_AVAILABLE:'||target)
  if \frozenOrDirectoryHas(map,self~field) then return .MLConstraintResult~new(self~id,.false,'MISSING_FIELD:'||self~field)
  actual=frozenOrDirectoryAt(map,self~field)
  ok=self~compare(actual,self~expected,self~relation)
  return .MLConstraintResult~new(self~id,ok,'field='||self~field||'|actual='||actual||'|relation='||self~relation||'|expected='||self~expected)
::method resolveMap private
  use strict arg subject,target
  if target='SELF' then map=subject
  else if target='CONFIGURATION' then do
    if \subject~hasMethod('CONFIGURATION') then return .nil
    map=subject~configuration
  end
  else do
    if \subject~hasMethod('EVIDENCE') then return .nil
    map=subject~evidence
  end
  if map==.nil then return .nil
  if map~isA(.Directory) | map~isA(.MLFrozenMap) then return map
  return .nil
::method compare private
  use strict arg actual,expected,relation
  if relation='LE' then return actual<=expected
  if relation='LT' then return actual<expected
  if relation='GE' then return actual>=expected
  if relation='GT' then return actual>expected
  if relation='EQ' then return actual==expected
  return actual\==expected
::method canonicalText
  return self~canonicalText:super||'|target='||self~target||'|field='||self~field||'|relation='||self~relation||'|expected='||self~expected

::class MLSearchSpaceConstraint subclass MLHardConstraint public
::method init
  expose searchSpace
  use strict arg id,searchSpace,description='configuration must be inside declared search space'
  self~init:super(id,description)
  if \searchSpace~isA(.MLSearchSpace) then raise syntax 88.900 array('search-space constraint requires MLSearchSpace')
::method searchSpace; expose searchSpace; return searchSpace
::method assess
  expose searchSpace
  use strict arg subject
  if subject~isA(.MLFrozenMap) then configuration=subject~toDirectory
  else if subject~isA(.Directory) then configuration=subject
  else if subject~hasMethod('CONFIGURATION') then do
    configuration=subject~configuration
    if configuration~isA(.MLFrozenMap) then configuration=configuration~toDirectory
  end
  else return .MLConstraintResult~new(self~id,.false,'CONFIGURATION_NOT_AVAILABLE')
  ok=searchSpace~containsConfiguration(configuration)
  return .MLConstraintResult~new(self~id,ok,'searchSpace='||searchSpace~id)
::method canonicalText
  expose searchSpace
  return self~canonicalText:super||'|searchSpace='||searchSpace~id

::class MLConstraintAssessment public
::attribute constraintSetId
::attribute feasible
::attribute passedCount
::attribute violationCount
::method init
  expose results violations
  use strict arg constraintSetId,sourceResults
  self~constraintSetId=constraintSetId; results=.array~new; violations=.array~new; self~passedCount=0
  do item over sourceResults
    if \item~isA(.MLConstraintResult) then raise syntax 88.900 array('constraint assessment requires MLConstraintResult')
    results~append(item)
    if item~passed then self~passedCount=self~passedCount+1
    else violations~append(item)
  end
  self~violationCount=violations~items; self~feasible=(violations~items=0)
::method results
  expose results
  out=.array~new; do r over results; out~append(r); end; return out
::method violations
  expose violations
  out=.array~new; do r over violations; out~append(r); end; return out
::method canonicalText
  expose results
  lines=.array~new; lines~append('CONSTRAINT_ASSESSMENT='||self~constraintSetId||'|feasible='||self~feasible||'|passed='||self~passedCount||'|violations='||self~violationCount)
  do r over results; lines~append(r~canonicalText); end
  return lines~makeString('L')

::class MLConstraintSet public
::attribute id
::attribute description
::method init
  expose constraints byId
  use strict arg id,sourceConstraints,description=''
  if id='' then raise syntax 88.900 array('constraint-set id must not be empty')
  if \sourceConstraints~isA(.Array) | sourceConstraints~items=0 then raise syntax 88.900 array('constraint set requires nonempty Array')
  self~id=id; self~description=description; constraints=.array~new; byId=.directory~new
  do constraint over sourceConstraints
    if \constraint~isA(.MLHardConstraint) then raise syntax 88.900 array('constraint set requires MLHardConstraint')
    if byId~hasIndex(constraint~id) then raise syntax 88.900 array('duplicate hard constraint id',constraint~id)
    constraints~append(constraint); byId[constraint~id]=constraint
  end
::method constraints
  expose constraints
  out=.array~new; do c over constraints; out~append(c); end; return out
::method constraint
  expose byId
  use strict arg id
  if byId~hasIndex(id) then return byId[id]
  return .nil
::method assess
  expose constraints
  use strict arg subject
  results=.array~new
  do constraint over constraints; results~append(constraint~assess(subject)); end
  return .MLConstraintAssessment~new(self~id,results)
::method canonicalText
  expose constraints
  lines=.array~new; lines~append('CONSTRAINT_SET='||self~id||'|description='||self~description)
  do c over constraints; lines~append(c~canonicalText); end
  return lines~makeString('L')

::class MLConstrainedObjectiveEvaluation public
::attribute subject
::attribute objectiveVector
::attribute constraintAssessment
::attribute evidence
::method init
  use strict arg subject,objectiveVector,constraintAssessment,evidence=.nil
  if \constraintAssessment~isA(.MLConstraintAssessment) then raise syntax 88.900 array('constrained evaluation requires MLConstraintAssessment')
  if constraintAssessment~feasible & \objectiveVector~isA(.MLObjectiveVector) then raise syntax 88.900 array('feasible constrained evaluation requires MLObjectiveVector')
  if \constraintAssessment~feasible & objectiveVector\==.nil then raise syntax 88.900 array('infeasible constrained evaluation must not publish objective vector')
  self~subject=subject; self~objectiveVector=objectiveVector; self~constraintAssessment=constraintAssessment; self~evidence=evidence
::method feasible; return self~constraintAssessment~feasible
::method canonicalText
  vectorText='<INFEASIBLE>'; if self~objectiveVector\==.nil then vectorText=self~objectiveVector~canonicalText
  return 'CONSTRAINED_EVALUATION=feasible='||self~feasible||'|'||vectorText||'0a'x||self~constraintAssessment~canonicalText

::class MLConstrainedEvaluatorAdapter public
::method init
  expose objectiveSet constraintSet delegate
  use strict arg objectiveSet,constraintSet,delegate
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('constrained evaluator requires MLObjectiveSet')
  if \constraintSet~isA(.MLConstraintSet) then raise syntax 88.900 array('constrained evaluator requires MLConstraintSet')
  if delegate==.nil | \delegate~hasMethod('SCORES') then raise syntax 88.900 array('constrained evaluator delegate must implement scores(subject)')
::method objectiveSet; expose objectiveSet; return objectiveSet
::method constraintSet; expose constraintSet; return constraintSet
::method evaluate
  expose objectiveSet constraintSet delegate
  use strict arg searchSubject
  if delegate~hasMethod('CONSTRAINTSUBJECT') then constraintSubject=delegate~constraintSubject(searchSubject)
  else constraintSubject=searchSubject
  assessment=constraintSet~assess(constraintSubject)
  if \assessment~feasible then return .MLConstrainedObjectiveEvaluation~new(searchSubject,.nil,assessment,.nil)
  scores=delegate~scores(searchSubject); vector=objectiveSet~vector(scores)
  evidence=.nil; if delegate~hasMethod('EVIDENCE') then evidence=delegate~evidence(searchSubject)
  return .MLConstrainedObjectiveEvaluation~new(searchSubject,vector,assessment,evidence)

::class MLConstrainedParetoRecord public
::attribute subjectId
::attribute subject
::attribute objectiveVector
::attribute constraintAssessment
::attribute evidence
::attribute paretoPoint
::method init
  use strict arg subjectId,subject,evaluation
  if subjectId='' then raise syntax 88.900 array('constrained Pareto record requires subject id')
  if \evaluation~isA(.MLConstrainedObjectiveEvaluation) then raise syntax 88.900 array('constrained Pareto record requires MLConstrainedObjectiveEvaluation')
  self~subjectId=subjectId; self~subject=subject; self~objectiveVector=evaluation~objectiveVector; self~constraintAssessment=evaluation~constraintAssessment; self~evidence=evaluation~evidence
  if self~constraintAssessment~feasible then self~paretoPoint=.MLParetoPoint~new(subjectId,subject,self~objectiveVector,self~evidence)
  else self~paretoPoint=.nil
::method feasible; return self~constraintAssessment~feasible
::method rank; if self~paretoPoint==.nil then return 999999; return self~paretoPoint~rank
::method crowdingDistance; if self~paretoPoint==.nil then return 0; return self~paretoPoint~crowdingDistance
::method canonicalText
  if self~feasible then p='rank='||self~rank||'|crowding='||self~crowdingDistance
  else p='INFEASIBLE|violations='||self~constraintAssessment~violationCount
  return 'CONSTRAINED_PARETO_RECORD='||self~subjectId||'|'||p

::class MLConstrainedSelectionComparator public
::method compare
  use strict arg a,b
  if a~feasible & \b~feasible then return -1
  if b~feasible & \a~feasible then return 1
  if \a~feasible then do
    if a~constraintAssessment~violationCount<b~constraintAssessment~violationCount then return -1
    if a~constraintAssessment~violationCount>b~constraintAssessment~violationCount then return 1
  end
  else do
    if a~rank<b~rank then return -1
    if a~rank>b~rank then return 1
    if a~crowdingDistance>b~crowdingDistance then return -1
    if a~crowdingDistance<b~crowdingDistance then return 1
  end
  if a~subjectId<b~subjectId then return -1
  if a~subjectId>b~subjectId then return 1
  return 0

::class MLConstrainedParetoResult public
::attribute objectiveSetId
::attribute constraintSetId
::attribute paretoResult
::attribute feasibleCount
::attribute infeasibleCount
::method init
  expose records recordsById
  use strict arg objectiveSet,constraintSet,sourceRecords
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('constrained Pareto result requires MLObjectiveSet')
  if \constraintSet~isA(.MLConstraintSet) then raise syntax 88.900 array('constrained Pareto result requires MLConstraintSet')
  self~objectiveSetId=objectiveSet~id; self~constraintSetId=constraintSet~id; records=.array~new; recordsById=.directory~new; points=.array~new
  self~feasibleCount=0; self~infeasibleCount=0
  do record over sourceRecords
    if \record~isA(.MLConstrainedParetoRecord) then raise syntax 88.900 array('constrained Pareto result requires MLConstrainedParetoRecord')
    if recordsById~hasIndex(record~subjectId) then raise syntax 88.900 array('duplicate constrained Pareto subject id',record~subjectId)
    records~append(record); recordsById[record~subjectId]=record
    if record~feasible then do; points~append(record~paretoPoint); self~feasibleCount=self~feasibleCount+1; end
    else self~infeasibleCount=self~infeasibleCount+1
  end
  if points~items>0 then self~paretoResult=.MLParetoAnalyzer~analyze(objectiveSet,points)
  else self~paretoResult=.nil
::method records
  expose records
  out=.array~new; do r over records; out~append(r); end; return out
::method record
  expose recordsById
  use strict arg id
  if recordsById~hasIndex(id) then return recordsById[id]
  return .nil
::method nonDominated
  if self~paretoResult==.nil then return .array~new
  return self~paretoResult~nonDominated
::method selectionRecords
  expose records
  out=.array~new; do r over records; out~append(r); end; out~sortWith(.MLConstrainedSelectionComparator~new); return out
::method canonicalText
  lines=.array~new; lines~append('CONSTRAINED_PARETO_RESULT='||self~objectiveSetId||'|constraints='||self~constraintSetId||'|feasible='||self~feasibleCount||'|infeasible='||self~infeasibleCount)
  if self~paretoResult\==.nil then lines~append(self~paretoResult~canonicalText)
  return lines~makeString('L')

::class MLConstrainedParetoAnalyzer public
::method analyze class
  use strict arg objectiveSet,constraintSet,sourcePoints
  if \sourcePoints~isA(.Array) | sourcePoints~items=0 then raise syntax 88.900 array('constrained Pareto analysis requires nonempty Array')
  records=.array~new
  do point over sourcePoints
    if \point~isA(.MLParetoPoint) then raise syntax 88.900 array('constrained Pareto analysis requires MLParetoPoint')
    assessment=constraintSet~assess(point)
    if assessment~feasible then eval=.MLConstrainedObjectiveEvaluation~new(point~subject,point~objectiveVector,assessment,point~evidence)
    else eval=.MLConstrainedObjectiveEvaluation~new(point~subject,.nil,assessment,point~evidence)
    records~append(.MLConstrainedParetoRecord~new(point~subjectId,point~subject,eval))
  end
  return .MLConstrainedParetoResult~new(objectiveSet,constraintSet,records)

::class MLConstrainedParetoRetentionSelector public
::method select class
  use strict arg paretoOutcome,retentionPolicy
  if \paretoOutcome~isA(.MLConstrainedParetoResult) then raise syntax 88.900 array('constrained Pareto retention requires MLConstrainedParetoResult')
  if paretoOutcome~paretoResult==.nil then return .array~new
  return .MLParetoRetentionSelector~select(paretoOutcome~paretoResult,retentionPolicy)

::class MLConstrainedParetoEvolutionGeneration public
::attribute id
::attribute populationGeneration
::attribute branch
::attribute checkpointId
::attribute result
::attribute feasibleCount
::attribute infeasibleCount
::attribute nonDominatedCount
::method init
  use strict arg id,populationGeneration,branch,checkpointId,paretoOutcome
  self~id=id; self~populationGeneration=populationGeneration; self~branch=branch; self~checkpointId=checkpointId; self~result=paretoOutcome
  self~feasibleCount=paretoOutcome~feasibleCount; self~infeasibleCount=paretoOutcome~infeasibleCount; self~nonDominatedCount=paretoOutcome~nonDominated~items
::method canonicalText
  return 'CONSTRAINED_PARETO_GENERATION='||self~id||'|population='||self~populationGeneration||'|branch='||self~branch||'|checkpoint='||self~checkpointId||'|feasible='||self~feasibleCount||'|infeasible='||self~infeasibleCount||'|front1='||self~nonDominatedCount

::class MLConstrainedParetoGenerationRegistry public
::method init
  expose generations nextId
  generations=.directory~new; nextId=1
::method publish
  expose generations nextId
  use strict arg populationGeneration,branch,checkpointId,paretoOutcome
  id='CPEG'||nextId; nextId=nextId+1; generation=.MLConstrainedParetoEvolutionGeneration~new(id,populationGeneration,branch,checkpointId,paretoOutcome); generations[id]=generation; return generation
::method generation
  expose generations
  use strict arg id
  if generations~hasIndex(id) then return generations[id]
  return .nil
::method count; expose generations; return generations~items
::method generations
  expose generations
  ids=generations~allIndexes; ids~sort; out=.array~new; do id over ids; out~append(generations[id]); end; return out

::class MLConstrainedParetoGARunResult public
::attribute breedingSteps
::attribute initialPopulationGeneration
::attribute finalPopulationGeneration
::attribute finalEvaluation
::attribute finalCheckpoint
::method init
  expose steps
  use strict arg sourceSteps,initialPopulationGeneration,finalPopulationGeneration,finalEvaluation,finalCheckpoint
  steps=.array~new; do s over sourceSteps; steps~append(s); end
  self~breedingSteps=steps~items; self~initialPopulationGeneration=initialPopulationGeneration; self~finalPopulationGeneration=finalPopulationGeneration; self~finalEvaluation=finalEvaluation; self~finalCheckpoint=finalCheckpoint
::method steps
  expose steps
  out=.array~new; do s over steps; out~append(s); end; return out
::method canonicalText
  return 'CONSTRAINED_PARETO_GA_RUN=steps='||self~breedingSteps||'|initial='||self~initialPopulationGeneration||'|final='||self~finalPopulationGeneration||'|feasible='||self~finalEvaluation~feasibleCount||'|front1='||self~finalEvaluation~nonDominatedCount||'|checkpoint='||self~finalCheckpoint~checkpointId

::class MLConstrainedParetoGeneticAlgorithm public
::method init
  expose experiment population rng objectiveSet constraintSet policy registry
  use strict arg population,objectiveSet,constraintSet,rng=.nil,experiment=.nil,policy=.nil
  if \population~isA(.MLPopulation) then raise syntax 88.900 array('constrained Pareto GA requires MLPopulation')
  if \objectiveSet~isA(.MLObjectiveSet) then raise syntax 88.900 array('constrained Pareto GA requires MLObjectiveSet')
  if \constraintSet~isA(.MLConstraintSet) then raise syntax 88.900 array('constrained Pareto GA requires MLConstraintSet')
  if rng==.nil then rng=.MLDeterministicRNG~new(1,'CONSTRAINED-PARETO-RNG')
  if experiment==.nil then experiment=.MLExperiment~new('CONSTRAINED-PARETO-GA')
  if policy==.nil then policy=.MLGeneticPolicy~new
  if \policy~isA(.MLGeneticPolicy) then raise syntax 88.900 array('constrained Pareto GA requires MLGeneticPolicy')
  registry=.MLConstrainedParetoGenerationRegistry~new
  if experiment~participant('population')==.nil then experiment~register('population',population)
  if experiment~participant('rng')==.nil then experiment~register('rng',rng)
  root=experiment~checkpoint('constrained-pareto-ga-initial','CONSTRAINED_PARETO_GA_INITIAL')
::method experiment; expose experiment; return experiment
::method population; expose population; return population
::method rng; expose rng; return rng
::method objectiveSet; expose objectiveSet; return objectiveSet
::method constraintSet; expose constraintSet; return constraintSet
::method policy; expose policy; return policy
::method generationRegistry; expose registry; return registry
::method evaluateCurrent
  expose experiment population registry
  use strict arg evaluator,tag='CONSTRAINED_PARETO_GA_FINAL_EVALUATION'
  before=experiment~checkpoint('before-constrained-pareto-evaluation',tag)
  signal on syntax name EvaluationFailed
  paretoOutcome=self~evaluatePopulation(evaluator)
  after=experiment~checkpoint('after-constrained-pareto-evaluation',tag)
  generation=registry~publish(population~generation,experiment~currentBranch,after~checkpointId,paretoOutcome)
  out=.directory~new; out['before']=before; out['after']=after; out['evaluatedGeneration']=generation; out['populationGeneration']=population~generation
  return out
EvaluationFailed:
  experiment~rollback(before,'failed-constrained-pareto-evaluation-'||(registry~count+1)); raise propagate
::method run
  expose population
  use strict arg evaluator,breedingSteps=1
  if breedingSteps<1 then raise syntax 88.900 array('constrained Pareto GA run requires at least one breeding step')
  startGeneration=population~generation; steps=.array~new
  do g=1 to breedingSteps; steps~append(self~step(evaluator)); end
  final=self~evaluateCurrent(evaluator,'CONSTRAINED_PARETO_GA_RUN_FINAL_EVALUATION')
  return .MLConstrainedParetoGARunResult~new(steps,startGeneration,population~generation,final['evaluatedGeneration'],final['after'])
::method step
  expose experiment population rng policy registry
  use strict arg evaluator
  before=experiment~checkpoint('before-constrained-pareto-generation','CONSTRAINED_PARETO_GA_GENERATION')
  signal on syntax name StepFailed
  paretoOutcome=self~evaluatePopulation(evaluator); ranked=paretoOutcome~selectionRecords
  cursor=rng~cursor; next=.array~new; eliteCount=policy~eliteCount; if eliteCount>population~populationSize then eliteCount=population~populationSize
  do e=1 to eliteCount
    record=ranked[e]; next~append(.MLGenome~new('G'||(population~generation+1)||'-E'||e,record~subject~genes~toArray))
  end
  childIndex=next~items+1
  do while next~items<population~populationSize
    p1=self~tournament(ranked,cursor); p2=self~tournament(ranked,cursor); genes=self~breed(p1~subject,p2~subject,cursor)
    next~append(.MLGenome~new('G'||(population~generation+1)||'-I'||childIndex,genes)); childIndex=childIndex+1
  end
  rng~commitCursor(cursor,'CONSTRAINED_PARETO_GA_RNG_GENERATION')
  evaluatedGeneration=population~generation; population~replaceGeneration(next,evaluatedGeneration+1,'CONSTRAINED_PARETO_GA_NEXT_GENERATION')
  after=experiment~checkpoint('after-constrained-pareto-generation','CONSTRAINED_PARETO_GA_GENERATION')
  generation=registry~publish(evaluatedGeneration,experiment~currentBranch,after~checkpointId,paretoOutcome)
  out=.directory~new; out['before']=before; out['after']=after; out['evaluatedGeneration']=generation; out['newPopulationGeneration']=population~generation; out['newPopulationEvaluated']=.false
  return out
StepFailed:
  experiment~rollback(before,'failed-constrained-pareto-generation-'||(registry~count+1)); raise propagate
::method evaluatePopulation private
  expose population objectiveSet constraintSet
  use strict arg evaluator
  records=.array~new
  do genome over population~genomes
    evaluation=evaluator~evaluate(genome); records~append(.MLConstrainedParetoRecord~new(genome~id,genome,evaluation))
  end
  return .MLConstrainedParetoResult~new(objectiveSet,constraintSet,records)
::method tournament private
  use strict arg ranked,cursor
  a=ranked[cursor~nextInt(ranked~items)]; b=ranked[cursor~nextInt(ranked~items)]; cmp=.MLConstrainedSelectionComparator~new~compare(a,b)
  if cmp<=0 then return a
  return b
::method breed private
  expose policy
  use strict arg g1,g2,cursor
  if g1~geneCount<>g2~geneCount then raise syntax 88.900 array('constrained Pareto GA parent gene-count mismatch')
  n=g1~geneCount; out=.array~new; useCross=cursor~nextUnit<policy~crossoverRate
  if n>1 & useCross then split=cursor~nextInt(n-1); else split=n
  do i=1 to n
    if useCross & i>split then value=g2~gene(i); else value=g1~gene(i)
    if cursor~nextUnit<policy~mutationRate then value=value+((cursor~nextUnit*2-1)*policy~mutationScale)
    out~append(value)
  end
  return out

::routine frozenOrDirectoryHas
  use strict arg map,key
  if map~isA(.Directory) then return map~hasIndex(key)
  if map~isA(.MLFrozenMap) then return map~hasIndex(key)
  return .false
::routine frozenOrDirectoryAt
  use strict arg map,key
  if map~isA(.Directory) then return map[key]
  if map~isA(.MLFrozenMap) then return map[key]
  return .nil

::requires "MLMultiObjective.cls"
