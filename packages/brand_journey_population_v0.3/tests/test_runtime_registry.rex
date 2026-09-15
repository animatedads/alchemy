parse arg root
if root='' then root=directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root || '/runtime/BrandJourneyPopulationRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath); call assertTrue load~ok,'runtime source loads'
artifactId='brand:journey:population:v0.3'; verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('brand.journey.population','BRAND_JOURNEY_POPULATION','0.2',artifactId,'BrandJourneyPopulationRuntimeModule',load~value,.BrandJourneyPopulationBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact); call assertTrue staged~ok,'runtime stages'
activated=kernel~activate('prod','brand.journey.population',staged~value~generationId); call assertTrue activated~ok,'runtime activates'
acquired=kernel~acquire('prod','brand.journey.population'); call assertTrue acquired~ok,'runtime acquires'
lease=acquired~value; module=lease~module
call assertEqual 'BRAND-JOURNEY-POPULATION-V0.3',module~generationLabel,'generation label'
call assertEqual 'brand.journey.population/0.3',module~apiVersion,'api version'
call assertTrue module~newAnalyzer~class == .BrandJourneyPopulationAnalyzer,'analyzer factory'
call assertTrue lease~release~ok,'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
::requires 'RuntimeRegistry.cls'
