parse arg root
if root='' then root=directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root || '/runtime/BrandInterventionGovernanceRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath); call assertTrue load~ok,'runtime source loads'
artifactId='brand:intervention:governance:v0.2'; verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('brand.intervention.governance','BRAND_INTERVENTION_GOVERNANCE','0.2',artifactId,'BrandInterventionGovernanceRuntimeModule',load~value,.BrandInterventionGovernanceBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact); call assertTrue staged~ok,'runtime stages'
activated=kernel~activate('prod','brand.intervention.governance',staged~value~generationId); call assertTrue activated~ok,'runtime activates'
acquired=kernel~acquire('prod','brand.intervention.governance'); call assertTrue acquired~ok,'runtime acquires'
lease=acquired~value; module=lease~module
call assertEqual 'BRAND-INTERVENTION-GOVERNANCE-V0.2',module~generationLabel,'generation label'
call assertEqual 'brand.intervention.governance/0.2',module~apiVersion,'api version'
call assertTrue module~newEngine~class == .BrandInterventionGovernanceEngine,'engine factory'
call assertTrue lease~release~ok,'lease release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInterventionGovernance.cls'
::requires 'RuntimeRegistry.cls'
