initial=.array~of(.array~of(0),.array~of(2),.array~of(4),.array~of(6),.array~of(8))
pop=.MLPopulation~new(initial,'P')
rng=.MLDeterministicRNG~new(12345,'R')
exp=.MLExperiment~new('ga-test')
ga=.MLGeneticAlgorithm~new(pop,rng,exp,0.80,0.50,0.90,1)
start=exp~currentCheckpoint
r1=ga~step(.TargetFiveFitness~new)
after1=r1['after']
canon1=pop~at('genomes')~canonicalText
rng1=rng~at('state')

exp~rollback(start,'first-future')
r2=ga~step(.TargetFiveFitness~new)
canon2=pop~at('genomes')~canonicalText
rng2=rng~at('state')
call eq canon1,canon2,'deterministic replay population'
call eq rng1,rng2,'deterministic replay rng'

exp~rollback(start,'replay-future')
ga~mutationScale=3.0
r3=ga~step(.TargetFiveFitness~new)
canon3=pop~at('genomes')~canonicalText
call true canon3\==canon1,'alternate policy creates different future'
exp~rollForward('first-future')
call eq canon1,pop~at('genomes')~canonicalText,'first future restorable'
call true ga~generationRegistry~count>=3,'all evaluated generations retained'
say 'PASS test_ga_replay_branching'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return

::class TargetFiveFitness public
::method fitness
 use strict arg genome
 d=genome~gene(1)-5
 return -(d*d)

::requires "OorexxML.cls"
