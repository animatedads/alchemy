/* Synthetic version of the recovered-audio Strategy C deployment shape.
 * It demonstrates a 20-candidate budget without the old unscored-final-generation gap.
 */
plan=.MLGABudgetPlan~forCandidateLimit(20,30,3,4)
say plan~canonicalText

rng=.MLDeterministicRNG~new(20903,'AUDIO-C-RNG')
cursor=rng~cursor; initial=.array~new
do i=1 to plan~populationSize
  genes=.array~new
  do j=1 to 3; genes~append(cursor~nextUnit); end
  initial~append(genes)
end
rng~commitCursor(cursor,'AUDIO_INITIAL_POPULATION')
pop=.MLPopulation~new(initial,'AUDIO-C-POPULATION')
exp=.MLExperiment~new('AUDIO-C-SEARCH')
policy=.MLGeneticPolicy~new(.25,.12,.80,2)
ga=.MLGeneticAlgorithm~fromPolicy(pop,policy,rng,exp)
run=ga~run(.SyntheticAudioFitness~new,plan~breedingSteps)
say run~canonicalText
say 'final best fitness='run~finalEvaluation~bestFitness

::class SyntheticAudioFitness public
::method fitness
  use strict arg genome
  /* stand-in for a lower-is-better audio distance objective */
  score=abs(genome~gene(1)-.66)+abs(genome~gene(2)-.31)+abs(genome~gene(3)-.82)
  return -score
::requires "OorexxML.cls"
