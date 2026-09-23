/* MLEvolution.cls - deterministic, branchable genetic algorithms. */

::class MLGenome public
::attribute id
::method init
  expose genes
  use strict arg id,sourceGenes
  self~id=id; genes=.MLFrozenVector~new(sourceGenes)
::method genes; expose genes; return genes
::method gene; expose genes; use strict arg i; return genes[i]
::method geneCount; expose genes; return genes~items
::method canonicalText; expose genes; return 'GENOME='||self~id||'|genes='||genes~canonicalText

::class MLIndividual public
::attribute genome
::attribute fitness
::attribute evidence
::method init
  use strict arg genome,fitness,evidence=.nil
  self~genome=genome; self~fitness=fitness; self~evidence=evidence
::method canonicalText; return self~genome~canonicalText||'|fitness='||self~fitness

::class MLFrozenPopulation public
::method init
  expose genomes
  use strict arg source
  genomes=.array~new; do genome over source; genomes~append(genome); end
::method items; expose genomes; return genomes~items
::method at; expose genomes; use strict arg i; return genomes[i]
::method '[]'; expose genomes; use strict arg i; return genomes[i]
::method toArray
  expose genomes
  out=.array~new; do genome over genomes; out~append(genome); end; return out
::method canonicalText
  expose genomes
  lines=.array~new; do genome over genomes; lines~append(genome~canonicalText); end; return lines~makeString('L')

::class MLDeterministicRNG subclass MLDriveableObject public
::method init
  use strict arg seed=1,stableId='RNG'
  initial=.directory~new; initial['state']=seed; initial['draws']=0
  self~init:super(stableId,'DETERMINISTIC_RNG',initial)
::method cursor
  return .MLRNGCursor~new(self~at('state'),self~at('draws'))
::method commitCursor
  use strict arg cursor,tag='RNG_BATCH'
  changes=.directory~new; changes['state']=cursor~state; changes['draws']=cursor~draws
  return self~mutate(changes,tag)

::class MLRNGCursor public
::attribute state
::attribute draws
::method init
  use strict arg state,draws=0
  self~state=state; self~draws=draws
::method nextUnit
  numeric digits 30
  next=(1103515245*self~state+12345)//2147483648
  self~state=next; self~draws=self~draws+1
  return next/2147483648
::method nextInt
  use strict arg maximum
  if maximum<1 then raise syntax 88.900 array('nextInt maximum must be positive')
  return trunc(self~nextUnit*maximum)+1

::class MLPopulation subclass MLDriveableObject public
::method init
  use strict arg sourceGenomes,stableId='POPULATION'
  if \sourceGenomes~isA(.Array) | sourceGenomes~items=0 then raise syntax 88.900 array('MLPopulation requires nonempty Array')
  genomes=.array~new; index=1
  do item over sourceGenomes
    if item~isA(.MLGenome) then genome=item
    else do; genome=.MLGenome~new('G0-I'||index,item); end
    genomes~append(genome); index=index+1
  end
  initial=.directory~new; initial['generation']=0; initial['genomes']=.MLFrozenPopulation~new(genomes)
  self~init:super(stableId,'EVOLUTION_POPULATION',initial)
::method generation; return self~at('generation')
::method genomes; return self~at('genomes')~toArray
::method populationSize; return self~at('genomes')~items
::method replaceGeneration
  use strict arg sourceGenomes,generationNumber,tag='EVOLVE'
  changes=.directory~new; changes['generation']=generationNumber; changes['genomes']=.MLFrozenPopulation~new(sourceGenomes)
  return self~mutate(changes,tag)

::class MLEvolutionGeneration public
::attribute id
::attribute populationGeneration
::attribute branch
::attribute checkpointId
::attribute bestFitness
::attribute bestGenome
::attribute individuals
::method init
  use strict arg id,populationGeneration,branch,checkpointId,individuals
  self~id=id; self~populationGeneration=populationGeneration; self~branch=branch; self~checkpointId=checkpointId; self~individuals=individuals
  best=.nil
  do individual over individuals
    if best==.nil then best=individual
    else if individual~fitness>best~fitness then best=individual
  end
  self~bestFitness=best~fitness; self~bestGenome=best~genome
::method canonicalText
  lines=.array~new; lines~append('GENERATION='||self~id||'|population='||self~populationGeneration||'|branch='||self~branch||'|checkpoint='||self~checkpointId||'|best='||self~bestFitness)
  do individual over self~individuals; lines~append(individual~canonicalText); end
  return lines~makeString('L')

::class MLEvolutionGenerationRegistry public
::method init
  expose generations nextId
  generations=.directory~new; nextId=1
::method publish
  expose generations nextId
  use strict arg populationGeneration,branch,checkpointId,individuals
  id='EG'||nextId; nextId=nextId+1
  generation=.MLEvolutionGeneration~new(id,populationGeneration,branch,checkpointId,individuals)
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

::class MLGeneticPolicy public
::attribute mutationRate
::attribute mutationScale
::attribute crossoverRate
::attribute eliteCount
::method init
  use strict arg mutationRate=0.10,mutationScale=0.25,crossoverRate=0.80,eliteCount=1
  if mutationRate<0 | mutationRate>1 then raise syntax 88.900 array('GA mutationRate must be between 0 and 1')
  if mutationScale<0 then raise syntax 88.900 array('GA mutationScale must be non-negative')
  if crossoverRate<0 | crossoverRate>1 then raise syntax 88.900 array('GA crossoverRate must be between 0 and 1')
  if eliteCount<0 then raise syntax 88.900 array('GA eliteCount must be non-negative')
  self~mutationRate=mutationRate; self~mutationScale=mutationScale; self~crossoverRate=crossoverRate; self~eliteCount=eliteCount
::method canonicalText
  return 'GA_POLICY=mutationRate='||self~mutationRate||'|mutationScale='||self~mutationScale||'|crossoverRate='||self~crossoverRate||'|eliteCount='||self~eliteCount

::class MLGABudgetPlan public
::attribute candidateLimit
::attribute populationSize
::attribute breedingSteps
::attribute evaluatedGenerations
::attribute plannedEvaluationRequests
::attribute unusedBudget
::attribute minimumEvaluatedGenerations
::method init
  use strict arg candidateLimit,populationSize,breedingSteps,minimumEvaluatedGenerations=3
  self~candidateLimit=candidateLimit; self~populationSize=populationSize; self~breedingSteps=breedingSteps
  self~evaluatedGenerations=breedingSteps+1
  self~plannedEvaluationRequests=populationSize*(breedingSteps+1)
  self~unusedBudget=candidateLimit-self~plannedEvaluationRequests
  self~minimumEvaluatedGenerations=minimumEvaluatedGenerations
::method canonicalText
  return 'GA_BUDGET=limit='||self~candidateLimit||'|population='||self~populationSize||'|breedingSteps='||self~breedingSteps||'|evaluatedGenerations='||self~evaluatedGenerations||'|planned='||self~plannedEvaluationRequests||'|unused='||self~unusedBudget
::method forCandidateLimit class
  use strict arg candidateLimit,preferredPopulation=30,minimumEvaluatedGenerations=3,minimumPopulation=4
  if candidateLimit<1 then raise syntax 88.900 array('GA candidate limit must be positive')
  if preferredPopulation<2 then raise syntax 88.900 array('GA preferred population must be at least 2')
  if minimumPopulation<2 then raise syntax 88.900 array('GA minimum population must be at least 2')
  if minimumEvaluatedGenerations<2 then raise syntax 88.900 array('GA requires at least two evaluated generations')
  minimumRequired=minimumPopulation*minimumEvaluatedGenerations
  if candidateLimit<minimumRequired then raise syntax 88.900 array('GA candidate budget too small for minimum evaluated generations',candidateLimit,minimumRequired)
  populationSize=trunc(candidateLimit/minimumEvaluatedGenerations)
  if populationSize>preferredPopulation then populationSize=preferredPopulation
  if populationSize<minimumPopulation then populationSize=minimumPopulation
  evaluatedGenerations=trunc(candidateLimit/populationSize)
  if evaluatedGenerations<minimumEvaluatedGenerations then evaluatedGenerations=minimumEvaluatedGenerations
  breedingSteps=evaluatedGenerations-1
  return self~new(candidateLimit,populationSize,breedingSteps,minimumEvaluatedGenerations)

::class MLGARunResult public
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
  return 'GA_RUN=steps='||self~breedingSteps||'|initial='||self~initialPopulationGeneration||'|final='||self~finalPopulationGeneration||'|finalEvaluation='||self~finalEvaluation~id||'|checkpoint='||self~finalCheckpoint~checkpointId

::class MLGeneticAlgorithm public
::attribute mutationRate
::attribute mutationScale
::attribute crossoverRate
::method init
  expose experiment population rng mutationRate mutationScale crossoverRate eliteCount registry
  use strict arg population,rng=.nil,experiment=.nil,mutationRate=0.10,mutationScale=0.25,crossoverRate=0.80,eliteCount=1
  if rng==.nil then rng=.MLDeterministicRNG~new(1)
  if experiment==.nil then experiment=.MLExperiment~new('GA')
  policy=.MLGeneticPolicy~new(mutationRate,mutationScale,crossoverRate,eliteCount)
  mutationRate=policy~mutationRate; mutationScale=policy~mutationScale; crossoverRate=policy~crossoverRate; eliteCount=policy~eliteCount
  registry=.MLEvolutionGenerationRegistry~new
  if experiment~participant('population')==.nil then experiment~register('population',population)
  if experiment~participant('rng')==.nil then experiment~register('rng',rng)
  root=experiment~checkpoint('ga-initial','GA_INITIAL')
::method fromPolicy class
  use strict arg population,policy,rng=.nil,experiment=.nil
  if \policy~isA(.MLGeneticPolicy) then raise syntax 88.900 array('GA fromPolicy requires MLGeneticPolicy')
  return self~new(population,rng,experiment,policy~mutationRate,policy~mutationScale,policy~crossoverRate,policy~eliteCount)
::method policy
  expose mutationRate mutationScale crossoverRate eliteCount
  return .MLGeneticPolicy~new(mutationRate,mutationScale,crossoverRate,eliteCount)
::method eliteCount
  expose eliteCount
  return eliteCount
::method experiment; expose experiment; return experiment
::method population; expose population; return population
::method rng; expose rng; return rng
::method generationRegistry; expose registry; return registry
::method evaluateCurrent
  expose experiment population registry
  use strict arg evaluator,tag='GA_FINAL_EVALUATION'
  before=experiment~checkpoint('before-evaluation',tag)
  signal on syntax name EvaluationFailed
  individuals=self~evaluatePopulation(evaluator)
  after=experiment~checkpoint('after-evaluation',tag)
  generation=registry~publish(population~generation,experiment~currentBranch,after~checkpointId,individuals)
  out=.directory~new
  out['before']=before; out['after']=after; out['evaluatedGeneration']=generation; out['populationGeneration']=population~generation
  return out
EvaluationFailed:
  experiment~rollback(before,'failed-evaluation-'||(registry~count+1))
  raise propagate
::method run
  expose population
  use strict arg evaluator,breedingSteps=1
  if breedingSteps<1 then raise syntax 88.900 array('GA run requires at least one breeding step')
  startGeneration=population~generation
  steps=.array~new
  do g=1 to breedingSteps
    steps~append(self~step(evaluator))
  end
  final=self~evaluateCurrent(evaluator,'GA_RUN_FINAL_EVALUATION')
  return .MLGARunResult~new(steps,startGeneration,population~generation,final['evaluatedGeneration'],final['after'])
::method step
  expose experiment population rng mutationRate mutationScale crossoverRate eliteCount registry
  use strict arg evaluator
  before=experiment~checkpoint('before-generation','GA_GENERATION')
  signal on syntax name StepFailed
  individuals=self~evaluatePopulation(evaluator)
  cursor=rng~cursor
  next=.array~new
  do e=1 to eliteCount
    elite=self~bestNotAlready(individuals,next)
    if elite\==.nil then next~append(.MLGenome~new('G'||(population~generation+1)||'-E'||e,elite~genome~genes~toArray))
  end
  childIndex=next~items+1
  do while next~items<population~populationSize
    p1=self~tournament(individuals,cursor)
    p2=self~tournament(individuals,cursor)
    genes=self~breed(p1~genome,p2~genome,cursor,mutationRate,mutationScale,crossoverRate)
    next~append(.MLGenome~new('G'||(population~generation+1)||'-I'||childIndex,genes))
    childIndex=childIndex+1
  end
  rng~commitCursor(cursor,'GA_RNG_GENERATION')
  population~replaceGeneration(next,population~generation+1,'GA_NEXT_GENERATION')
  after=experiment~checkpoint('after-generation','GA_GENERATION')
  generation=registry~publish(population~generation-1,experiment~currentBranch,after~checkpointId,individuals)
  out=.directory~new
  out['before']=before
  out['after']=after
  out['evaluatedGeneration']=generation
  out['newPopulationGeneration']=population~generation
  out['newPopulationEvaluated']=.false
  return out
StepFailed:
  experiment~rollback(before,'failed-generation-'||(registry~count+1))
  raise propagate
::method evaluatePopulation private
  expose population
  use strict arg evaluator
  genomes=population~genomes; individuals=.array~new
  do genome over genomes
    fitness=evaluator~fitness(genome)
    individuals~append(.MLIndividual~new(genome,fitness))
  end
  return individuals
::method tournament private
  use strict arg individuals,cursor
  a=individuals[cursor~nextInt(individuals~items)]; b=individuals[cursor~nextInt(individuals~items)]
  if a~fitness>=b~fitness then return a
  return b
::method bestNotAlready private
  use strict arg individuals,next
  best=.nil
  do individual over individuals
    used=.false
    do genome over next
      if genome~genes~canonicalText==individual~genome~genes~canonicalText then do; used=.true; leave; end
    end
    if used then iterate
    if best==.nil then best=individual
    else if individual~fitness>best~fitness then best=individual
  end
  return best
::method breed private
  use strict arg g1,g2,cursor,mutationRate,mutationScale,crossoverRate
  if g1~geneCount<>g2~geneCount then raise syntax 88.900 array('GA parent gene-count mismatch')
  n=g1~geneCount; out=.array~new
  useCross=cursor~nextUnit<crossoverRate
  if n>1 & useCross then split=cursor~nextInt(n-1); else split=n
  do i=1 to n
    if useCross & i>split then value=g2~gene(i); else value=g1~gene(i)
    if cursor~nextUnit<mutationRate then value=value+((cursor~nextUnit*2-1)*mutationScale)
    out~append(value)
  end
  return out

::requires "MLCore.cls"
