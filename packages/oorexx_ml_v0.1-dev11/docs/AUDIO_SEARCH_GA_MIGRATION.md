# Recovered-audio Strategy C migration to ooRexx ML dev4

The supplied `AudioSearchExperiment.rex` used a correct lower-is-better sign inversion and deterministic GA state, but its caller loop invoked `ga~step()` exactly `generations` times. Because `step()` evaluates the current population and then breeds the replacement, the final bred population was left unevaluated when the loop ended.

dev3 fixed the generic GA contract. dev4 carries a complete replacement caller under `integration/audio/AudioSearchExperiment.rex`.

## Old shape

```rexx
pop=.MLPopulation~new(initial,'AUDIO-C-POPULATION')
ga=.MLGeneticAlgorithm~new(pop,rng,exp,.25,.12,.80,2)
evaluator=.AudioGAEvaluator~new(ctx,records,cache)
do g=1 to generations
  step=ga~step(evaluator)
end
```

## dev4 shape

```rexx
plan=.MLGABudgetPlan~forCandidateLimit(limit,30,3,4)
policy=.MLGeneticPolicy~new(.25,.12,.80,2)
objective=.MLObjective~new('audio-recovered-reference-distance','MINIMIZE',formula,description)
scoreEvaluator=.AudioGAScoreEvaluator~new(ctx,records,cache)
evaluator=.MLObjectiveFitnessAdapter~new(objective,scoreEvaluator)
ga=.MLGeneticAlgorithm~fromPolicy(pop,policy,rng,exp)
run=ga~run(evaluator,plan~breedingSteps)
```

Changes are semantic, not cosmetic:

- the candidate budget now counts evaluated populations;
- low budgets still produce multiple evidence-bearing generations;
- the final offspring population is evaluated;
- hyperparameters are named;
- the audio evaluator returns the natural lower-is-better score;
- `MLObjectiveFitnessAdapter` owns the conversion to GA maximization fitness;
- the scoring formula records that its artefact penalty weights require perceptual calibration.

The existing cache remains valuable: `plannedEvaluationRequests` is a worst-case request count while `records~items` remains the honest number of unique normalized configurations actually scored.

The full replacement source compiles under ooRexx 5.3.0 r13196. Runtime DSP execution still depends on the recovered-audio `AudioSearchNative.cls`/native bridge, which is intentionally not duplicated inside ooRexx ML.
