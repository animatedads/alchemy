parse arg root
if root = '' then root = directory()
verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
sourcePath = root || '/runtime/InteractionEventRuntimeModule.cls'
load = .RuntimeSourceLoader~readFile(sourcePath)
call assertTrue load~ok, 'runtime source loads'
artifactId = 'interaction:event:v0.3'
verifier~pin(artifactId, load~value)
artifact = .RuntimeArtifact~new('interaction.event', 'INTERACTION_EVENT_LIBRARY', '0.3', artifactId, 'InteractionEventRuntimeModule', load~value, .InteractionEventBuild~API_VERSION, sourcePath)
staged = kernel~stage('prod', artifact)
call assertTrue staged~ok, 'runtime stages'
activated = kernel~activate('prod', 'interaction.event', staged~value~generationId)
call assertTrue activated~ok, 'runtime activates'
acquired = kernel~acquire('prod', 'interaction.event')
call assertTrue acquired~ok, 'runtime acquires'
lease = acquired~value
module = lease~module
call assertEqual 'INTERACTION-EVENT-V0.3', module~generationLabel, 'generation label'
call assertEqual 'interaction.event/0.3', module~apiVersion, 'api version'
call assertTrue module~newCaptureLibrary~class == .InteractionCaptureLibrary, 'library factory'
call assertTrue module~starts >= 1, 'started'
call assertTrue lease~release~ok, 'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
::requires 'RuntimeRegistry.cls'
