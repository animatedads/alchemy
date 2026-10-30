parse arg root
if root = '' then root = directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root || '/runtime/StructuredUtteranceProducerRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath)
call assertTrue load~ok,'runtime source loads'
artifactId='structured:utterance:producer:v0.1'
verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('structured.utterance.producer','STRUCTURED_UTTERANCE_PRODUCER','0.1',artifactId,'StructuredUtteranceProducerRuntimeModule',load~value,.StructuredUtteranceProducerBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact);call assertTrue staged~ok,'runtime stages'
activated=kernel~activate('prod','structured.utterance.producer',staged~value~generationId);call assertTrue activated~ok,'runtime activates'
acquired=kernel~acquire('prod','structured.utterance.producer');call assertTrue acquired~ok,'runtime acquires'
lease=acquired~value;module=lease~module
call assertEqual 'STRUCTURED-UTTERANCE-PRODUCER-V0.1',module~generationLabel,'generation label'
call assertEqual 'structured.utterance.producer/0.1',module~apiVersion,'api version'
call assertTrue module~newProducer~isA(.StructuredUtteranceProducer),'producer factory'
call assertTrue module~starts >= 1,'started'
call assertTrue lease~release~ok,'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
::requires 'RuntimeRegistry.cls'
