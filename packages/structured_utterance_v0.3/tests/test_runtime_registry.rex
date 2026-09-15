parse arg root
if root = '' then root = directory()
verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
sourcePath = root || '/runtime/StructuredUtteranceRuntimeModule.cls'
load = .RuntimeSourceLoader~readFile(sourcePath)
call assertTrue load~ok, 'runtime source loads'
artifactId = 'structured:utterance:v0.3'
verifier~pin(artifactId, load~value)
artifact = .RuntimeArtifact~new('structured.utterance', 'STRUCTURED_UTTERANCE_LIBRARY', '0.3', artifactId, 'StructuredUtteranceRuntimeModule', load~value, .StructuredUtteranceBuild~API_VERSION, sourcePath)
staged = kernel~stage('prod', artifact)
call assertTrue staged~ok, 'runtime stages'
activated = kernel~activate('prod', 'structured.utterance', staged~value~generationId)
call assertTrue activated~ok, 'runtime activates'
acquired = kernel~acquire('prod', 'structured.utterance')
call assertTrue acquired~ok, 'runtime acquires'
lease = acquired~value
module = lease~module
call assertEqual 'STRUCTURED-UTTERANCE-V0.3', module~generationLabel, 'generation label'
call assertEqual 'structured.utterance/0.3', module~apiVersion, 'api version'
call assertTrue module~newLibrary~class == .StructuredUtteranceLibrary, 'library factory'
call assertTrue module~serviceAsSalesContext~isPromotionalWork, 'service-as-sales context factory'
call assertTrue module~starts >= 1, 'started'
call assertTrue lease~release~ok, 'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
::requires 'RuntimeRegistry.cls'
