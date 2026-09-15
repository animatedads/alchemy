initial=.array~of(.array~of(.10,.20),.array~of(.30,.40),.array~of(.50,.60),.array~of(.70,.80))
pop=.MLPopulation~new(initial,'FINAL-SCORE-POP')
rng=.MLDeterministicRNG~new(20903,'FINAL-SCORE-RNG')
exp=.MLExperiment~new('final-score-test')
policy=.MLGeneticPolicy~new(.25,.12,.80,1)
ga=.MLGeneticAlgorithm~fromPolicy(pop,policy,rng,exp)
evaluator=.RecordingFitness~new
run=ga~run(evaluator,1)
call eq run~initialPopulationGeneration,0,'initial population generation'
call eq run~finalPopulationGeneration,1,'final population generation'
call eq run~finalEvaluation~populationGeneration,1,'bred final generation is evaluated'
call eq ga~generationRegistry~count,2,'initial and bred generations both published'
call true evaluator~sawPrefix('G0-'),'initial population was scored'
call true evaluator~sawPrefix('G1-'),'bred population was scored before run returned'
call eq evaluator~calls,8,'one breeding step scores exactly two populations'
say 'PASS test_ga_final_generation_scored'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return

::class RecordingFitness public
::method init
  expose ids callCount
  ids=.array~new; callCount=0
::method fitness
  expose ids callCount
  use strict arg genome
  ids~append(genome~id); callCount=callCount+1
  d=genome~gene(1)-.55
  return -(d*d)
::method calls; expose callCount; return callCount
::method sawPrefix
  expose ids
  use strict arg prefix
  do id over ids
    if id~left(prefix~length)==prefix then return .true
  end
  return .false

::requires "OorexxML.cls"
