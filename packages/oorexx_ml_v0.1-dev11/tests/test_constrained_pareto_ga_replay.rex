initial=.array~of(.array~of(.1,.2,.3),.array~of(.3,.4,.5),.array~of(.5,.6,.7),.array~of(.7,.8,.9))
pop=.MLPopulation~new(initial,'CP-REPLAY-POP')
rng=.MLDeterministicRNG~new(6606,'CP-REPLAY-RNG')
exp=.MLExperiment~new('cp-replay')
objectives=.MLObjectiveSet~new('CP-REPLAY-OBJ',.array~of(.MLObjective~new('a','MINIMIZE'),.MLObjective~new('b','MINIMIZE')))
constraints=.MLConstraintSet~new('CP-REPLAY-HARD',.array~of(.MLDirectoryFieldConstraint~new('x-max','x','LE',.80)))
delegate=.ReplayDelegate~new
adapter=.MLConstrainedEvaluatorAdapter~new(objectives,constraints,delegate)
ga=.MLConstrainedParetoGeneticAlgorithm~new(pop,objectives,constraints,rng,exp,.MLGeneticPolicy~new(.30,.10,.80,1))
root=exp~checkpoint('root','TEST')
step1=ga~step(adapter); futureText=populationText(pop~genomes); futureRng=rng~snapshot~canonicalText
exp~rollback(root,'constrained-original-future')
step2=ga~step(adapter)
call eq populationText(pop~genomes),futureText,'constrained rollback + replay reproduces offspring'
call eq rng~snapshot~canonicalText,futureRng,'constrained rollback + replay reproduces RNG state'
exp~rollback(root,'constrained-replayed-future')
call true exp~branchNames~items>=3,'both constrained futures retained'
say 'PASS test_constrained_pareto_ga_replay'
exit 0
populationText: procedure
 use strict arg genomes
 lines=.array~new; do g over genomes; lines~append(g~genes~canonicalText); end; return lines~makeString('L')
eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::class ReplayDelegate public
::method constraintSubject
 use strict arg genome
 d=.directory~new; d['x']=genome~gene(1); return d
::method scores
 use strict arg genome
 d=.directory~new; d['a']=genome~gene(1); d['b']=1-genome~gene(2); return d
::requires "OorexxML.cls"
