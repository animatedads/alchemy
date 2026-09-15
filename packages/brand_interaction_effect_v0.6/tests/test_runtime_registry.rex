parse arg root
if root='' then root=directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root || '/runtime/BrandInteractionRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath); call assertTrue load~ok,'runtime source loads'
artifactId='brand:interaction:effect:v0.6'; verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('brand.interaction.effect','BRAND_INTERACTION_EFFECT','0.6',artifactId,'BrandInteractionRuntimeModule',load~value,.BrandInteractionBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact); call assertTrue staged~ok,'runtime stages'
activated=kernel~activate('prod','brand.interaction.effect',staged~value~generationId); call assertTrue activated~ok,'runtime activates'
acquired=kernel~acquire('prod','brand.interaction.effect'); call assertTrue acquired~ok,'runtime acquires'
lease=acquired~value; module=lease~module
call assertEqual 'BRAND-INTERACTION-EFFECT-V0.6',module~generationLabel,'generation label'
call assertEqual 'brand.interaction.effect/0.6',module~apiVersion,'api version'
call assertTrue module~newEngine~class == .BrandInteractionEngine,'engine factory'
call assertTrue module~newEvidenceThreshold~minExposedCount > 0,'evidence threshold factory'
call assertTrue module~newEvidenceEngine~class~id <> '','evidence engine factory'
cohort=module~newCohortAccumulator('runtime-cohort','SUPPORT_INTERACTION','2026-08-01','2026-08-14',14,'CANCELLATION','SASS','HIGH')
call assertEqual 'BRANDEVIDENCECOHORTACCUMULATOR',cohort~class~id,'cohort accumulator factory'
prov=module~newCohortProvenance('runtime-prov','INTERACTION_EVENT','EVENT_STORE','INTERACTION','ALL_SUPPORT_V1','ALL_ELIGIBLE')
call assertEqual 'BRANDEVIDENCECOHORTPROVENANCE',prov~class~id,'cohort provenance factory'
call assertTrue lease~release~ok,'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
::requires 'RuntimeRegistry.cls'
