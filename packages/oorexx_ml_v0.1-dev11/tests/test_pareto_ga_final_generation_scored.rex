initial=.array~of(.array~of(.10,.20),.array~of(.30,.40),.array~of(.50,.60),.array~of(.70,.80))
pop=.MLPopulation~new(initial,'PARETO-FINAL-POP')
rng=.MLDeterministicRNG~new(20903,'PARETO-FINAL-RNG')
exp=.MLExperiment~new('pareto-final-test')
policy=.MLGeneticPolicy~new(.25,.12,.80,1)
objectives=.MLObjectiveSet~new('TWO-OBJECTIVE',.array~of(.MLObjective~new('target','MINIMIZE'),.MLObjective~new('smooth','MINIMIZE')))
ga=.MLParetoGeneticAlgorithm~new(pop,objectives,rng,exp,policy)
evaluator=.RecordingScores~new
run=ga~run(evaluator,1)
call eq run~initialPopulationGeneration,0,'initial population generation'
call eq run~finalPopulationGeneration,1,'final population generation'
call eq run~finalEvaluation~populationGeneration,1,'bred Pareto population is evaluated'
call eq ga~generationRegistry~count,2,'initial and bred Pareto generations both published'
call true evaluator~sawPrefix('G0-'),'initial Pareto population scored'
call true evaluator~sawPrefix('G1-'),'bred Pareto population scored before return'
call eq evaluator~calls,8,'one Pareto breeding step scores exactly two populations'
call true run~finalEvaluation~analysis~front(1)~items>=1,'final Pareto frontier exists'
say 'PASS test_pareto_ga_final_generation_scored'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return

::class RecordingScores public
::method init
  expose ids callCount
  ids=.array~new; callCount=0
::method scores
  expose ids callCount
  use strict arg genome
  ids~append(genome~id); callCount=callCount+1
  x=genome~gene(1); y=genome~gene(2)
  d=.directory~new; d['target']=(x-.55)*(x-.55)+(y-.45)*(y-.45); d['smooth']=(x-y)*(x-y)
  return d
::method calls; expose callCount; return callCount
::method sawPrefix
  expose ids
  use strict arg prefix
  do id over ids
    if id~left(prefix~length)==prefix then return .true
  end
  return .false
::requires "OorexxML.cls"
