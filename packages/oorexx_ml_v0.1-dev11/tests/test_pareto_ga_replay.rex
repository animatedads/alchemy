initial=.array~of(.array~of(.1,.2,.3),.array~of(.3,.4,.5),.array~of(.5,.6,.7),.array~of(.7,.8,.9))
pop=.MLPopulation~new(initial,'PARETO-REPLAY-POP')
rng=.MLDeterministicRNG~new(777,'PARETO-REPLAY-RNG')
exp=.MLExperiment~new('pareto-replay')
objectives=.MLObjectiveSet~new('REPLAY-OBJECTIVES',.array~of(.MLObjective~new('a','MINIMIZE'),.MLObjective~new('b','MINIMIZE')))
ga=.MLParetoGeneticAlgorithm~new(pop,objectives,rng,exp,.MLGeneticPolicy~new(.30,.10,.80,1))
e=.ReplayScores~new
root=exp~checkpoint('root','TEST')
step1=ga~step(e)
futurePop=pop~genomes; futureText=populationText(futurePop); futureRng=rng~snapshot~canonicalText
exp~rollback(root,'pareto-original-future')
step2=ga~step(e)
call eq populationText(pop~genomes),futureText,'rollback + replay reproduces identical Pareto offspring'
call eq rng~snapshot~canonicalText,futureRng,'rollback + replay reproduces identical RNG state'
exp~rollback(root,'pareto-replayed-future')
call true exp~branchNames~items>=3,'both Pareto futures are retained as branches'
say 'PASS test_pareto_ga_replay'
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
::class ReplayScores public
::method scores
 use strict arg genome
 d=.directory~new; d['a']=genome~gene(1); d['b']=1-genome~gene(2); return d
::requires "OorexxML.cls"
