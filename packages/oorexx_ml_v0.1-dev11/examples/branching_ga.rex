initial=.array~of(.array~of(0),.array~of(2),.array~of(4),.array~of(6),.array~of(8))
pop=.MLPopulation~new(initial)
rng=.MLDeterministicRNG~new(20260906)
exp=.MLExperiment~new('demo-ga')
ga=.MLGeneticAlgorithm~new(pop,rng,exp,0.5,0.5,0.8,1)
root=exp~currentCheckpoint
r=ga~step(.DemoFitness~new)
say 'first future:' pop~at('genomes')~canonicalText
exp~rollback(root,'first-future')
ga~mutationScale=2
r=ga~step(.DemoFitness~new)
say 'alternate future:' pop~at('genomes')~canonicalText
exp~rollForward('first-future')
say 'first future restored:' pop~at('genomes')~canonicalText
::class DemoFitness public
::method fitness
 use strict arg genome
 d=genome~gene(1)-5
 return -(d*d)
::requires "OorexxML.cls"
