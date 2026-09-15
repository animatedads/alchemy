parse arg root
if root='' then root=directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root || '/runtime/BrandJourneyRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath); call assertTrue load~ok,'runtime source loads'
artifactId='brand:journey:v0.1'; verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('brand.journey','BRAND_JOURNEY','0.1',artifactId,'BrandJourneyRuntimeModule',load~value,.BrandJourneyBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact); call assertTrue staged~ok,'runtime stages'
activated=kernel~activate('prod','brand.journey',staged~value~generationId); call assertTrue activated~ok,'runtime activates'
acquired=kernel~acquire('prod','brand.journey'); call assertTrue acquired~ok,'runtime acquires'
lease=acquired~value; module=lease~module
call assertEqual 'BRAND-JOURNEY-V0.1',module~generationLabel,'generation label'
call assertEqual 'brand.journey/0.1',module~apiVersion,'api version'
call assertTrue module~newEngine~class == .BrandJourneyEngine,'engine factory'
call assertTrue lease~release~ok,'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourney.cls'
::requires 'RuntimeRegistry.cls'
