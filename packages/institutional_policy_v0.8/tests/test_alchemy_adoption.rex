catalog = .InstitutionalPolicyCatalog~new
result = .AlchemyAdoptionVerifier~verify(catalog,'STANDARD')
call assertTrue result~ok,'InstitutionalPolicyCatalog STANDARD adoption'
call assertEqual 0,catalog~alchemyInheritanceIntegrity['reserved_override_count'],'catalog reserved surfaces clean'
now = .DateTime~new
profile = .InstitutionalPolicyAuthorityProfile~new('ADOPTION','1.0',now - .TimeSpan~new(0,0,1,0,0),.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('A','P1','AUTHOR','*')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('B','P2','APPROVER','*')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('C','P3','PUBLISHER','*')~seal)
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('R','*',.true,'OPTIONAL')~seal)
ignored = profile~seal
profileCatalog = .InstitutionalPolicyAuthorityProfileCatalog~new
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile)
deploymentEvaluator = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
rolloutEvaluator = .InstitutionalPolicyRolloutEvaluator~new
pc = .AlchemyAdoptionVerifier~verify(profileCatalog,'STANDARD')
pr = .AlchemyAdoptionVerifier~verify(profile,'STANDARD')
ev = .AlchemyAdoptionVerifier~verify(evaluator,'STANDARD')
dv = .AlchemyAdoptionVerifier~verify(deploymentEvaluator,'STANDARD')
rv = .AlchemyAdoptionVerifier~verify(rolloutEvaluator,'STANDARD')
call assertTrue pc~ok,'InstitutionalPolicyAuthorityProfileCatalog STANDARD adoption'
call assertTrue pr~ok,'InstitutionalPolicyAuthorityProfile STANDARD adoption'
call assertTrue ev~ok,'InstitutionalPolicyAuthorityEvaluator STANDARD adoption'
call assertTrue dv~ok,'InstitutionalPolicyDeploymentAuthorityEvaluator STANDARD adoption'
call assertTrue rv~ok,'InstitutionalPolicyRolloutEvaluator STANDARD adoption'
call assertEqual 0,profileCatalog~alchemyInheritanceIntegrity['reserved_override_count'],'authority profile catalogue reserved surfaces clean'
call assertEqual 0,profile~alchemyInheritanceIntegrity['reserved_override_count'],'authority profile reserved surfaces clean'
call assertEqual 0,evaluator~alchemyInheritanceIntegrity['reserved_override_count'],'authority evaluator reserved surfaces clean'
call assertEqual 0,deploymentEvaluator~alchemyInheritanceIntegrity['reserved_override_count'],'deployment evaluator reserved surfaces clean'
call assertEqual 0,rolloutEvaluator~alchemyInheritanceIntegrity['reserved_override_count'],'rollout evaluator reserved surfaces clean'
say 'PASS test_alchemy_adoption'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'AlchemyAdoption.cls'
::requires 'InstitutionalPolicy.cls'
