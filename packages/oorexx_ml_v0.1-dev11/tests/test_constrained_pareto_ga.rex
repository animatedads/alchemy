initial=.array~of(.array~of(.1,.2),.array~of(.4,.3),.array~of(.7,.1),.array~of(.95,.05))
pop=.MLPopulation~new(initial,'CP-POP')
rng=.MLDeterministicRNG~new(606,'CP-RNG')
exp=.MLExperiment~new('CP-GA')
objectives=.MLObjectiveSet~new('CP-OBJ',.array~of(.MLObjective~new('a','MINIMIZE'),.MLObjective~new('b','MINIMIZE')))
constraints=.MLConstraintSet~new('CP-HARD',.array~of(.MLDirectoryFieldConstraint~new('x-max','x','LE',.80)))
delegate=.CPDelegate~new
adapter=.MLConstrainedEvaluatorAdapter~new(objectives,constraints,delegate)
ga=.MLConstrainedParetoGeneticAlgorithm~new(pop,objectives,constraints,rng,exp,.MLGeneticPolicy~new(.20,.08,.80,1))
run=ga~run(adapter,1)
call eq ga~generationRegistry~count,2,'initial and final generations both evaluated'
call eq run~finalPopulationGeneration,1,'one bred generation produced'
call true run~finalEvaluation~feasibleCount>0,'final generation has feasible candidates'
call true run~finalEvaluation~nonDominatedCount>0,'final generation publishes feasible frontier'
/* Every non-dominated point is feasible by construction. */
do p over run~finalEvaluation~result~nonDominated
  call true run~finalEvaluation~result~record(p~subjectId)~feasible,'frontier point is feasible'
end
say 'PASS test_constrained_pareto_ga'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::class CPDelegate public
::method constraintSubject
  use strict arg genome
  d=.directory~new; d['x']=genome~gene(1); return d
::method scores
  use strict arg genome
  d=.directory~new; d['a']=genome~gene(1); d['b']=1-genome~gene(2); return d
::requires "OorexxML.cls"
