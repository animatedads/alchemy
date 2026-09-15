parse arg root
if root = '' then root = directory()
verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
sourcePath = root || '/runtime/ReputationRuntimeModule.cls'
load = .RuntimeSourceLoader~readFile(sourcePath)
call assertTrue load~ok, 'runtime source loads'
artifactId = 'reputation:effect:v0.2'
verifier~pin(artifactId, load~value)
artifact = .RuntimeArtifact~new('reputation.effect', 'REPUTATION_RULES', '0.2', artifactId, 'ReputationRuntimeModule', load~value, .ReputationEffectBuild~API_VERSION, sourcePath)
staged = kernel~stage('prod', artifact)
call assertTrue staged~ok, 'reputation runtime stages'
activated = kernel~activate('prod', 'reputation.effect', staged~value~generationId)
call assertTrue activated~ok, 'reputation runtime activates'
acquired = kernel~acquire('prod', 'reputation.effect')
call assertTrue acquired~ok, 'reputation runtime acquires'
lease = acquired~value
module = lease~module
call assertEqual 'REPUTATION-EFFECT-V0.2', module~generationLabel, 'runtime module generation label'
call assertEqual 'reputation.effect/0.2', module~apiVersion, 'runtime API version'
call assertTrue module~newEngine~class == .ReputationEngine, 'runtime creates reputation engine'
call assertTrue module~starts >= 1, 'runtimeStart called'
releaseResult = lease~release
call assertTrue releaseResult~ok, 'runtime lease releases'
say 'PASS test_reputation_runtime_registry'
exit 0

assertTrue: procedure
  use arg v,l
  if \v then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return

::requires 'ReputationEffect.cls'
::requires 'RuntimeRegistry.cls'
