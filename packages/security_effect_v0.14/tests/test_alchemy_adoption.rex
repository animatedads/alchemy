store = .SecurityEvidenceStore~new
engine = .SecurityEffectEngine~new
catalog = .SecurityPolicyCatalog~new
replay = .SecurityPolicyReplayEngine~new
s = .AlchemyAdoptionVerifier~verify(store,'STANDARD')
e = .AlchemyAdoptionVerifier~verify(engine,'STANDARD')
c = .AlchemyAdoptionVerifier~verify(catalog,'STANDARD')
r = .AlchemyAdoptionVerifier~verify(replay,'STANDARD')
call assertTrue s~ok,'SecurityEvidenceStore STANDARD adoption'
call assertTrue e~ok,'SecurityEffectEngine STANDARD adoption'
call assertTrue c~ok,'SecurityPolicyCatalog STANDARD adoption'
call assertTrue r~ok,'SecurityPolicyReplayEngine STANDARD adoption'
call assertEqual 0,store~alchemyInheritanceIntegrity['reserved_override_count'],'store reserved surfaces clean'
call assertEqual 0,engine~alchemyInheritanceIntegrity['reserved_override_count'],'engine reserved surfaces clean'
call assertEqual 0,catalog~alchemyInheritanceIntegrity['reserved_override_count'],'catalog reserved surfaces clean'
call assertEqual 0,replay~alchemyInheritanceIntegrity['reserved_override_count'],'replay reserved surfaces clean'
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
::requires 'SecurityEffect.cls'
