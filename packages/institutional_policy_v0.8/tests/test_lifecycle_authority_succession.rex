now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(3600)
cut = now + .InstitutionalPolicyTime~seconds(600)
finish = now + .InstitutionalPolicyTime~seconds(3600)

p1 = .InstitutionalPolicyAuthorityProfile~new('OPS-GOV','1.0',start,cut)
call addBase p1,start
ignored = p1~addGrant(.InstitutionalPolicyAuthorityGrant~new('OLD-SUSP','OLD_DUTY','SUSPEND','OPS-POLICY',start,cut,'BOARD','AUTH:OLD')~seal)
ignored = p1~addRule(.InstitutionalPolicyAuthorityRule~new('R1','OPS-POLICY',.true,'OPTIONAL')~seal)
ignored = p1~seal
p2 = .InstitutionalPolicyAuthorityProfile~new('OPS-GOV','2.0',cut,.nil,.nil,.nil,.nil,'1.0')
call addBase p2,cut
ignored = p2~addGrant(.InstitutionalPolicyAuthorityGrant~new('NEW-RESUME','NEW_DUTY','RESUME','OPS-POLICY',cut,.nil,'BOARD','AUTH:NEW')~seal)
ignored = p2~addRule(.InstitutionalPolicyAuthorityRule~new('R2','OPS-POLICY',.true,'OPTIONAL')~seal)
ignored = p2~seal
profiles = .InstitutionalPolicyAuthorityProfileCatalog~new
call assertTrue profiles~publish(p1)~ok,'old governance published'
call assertTrue profiles~publish(p2)~ok,'new governance published'
binding = .InstitutionalPolicyAuthorityBinding~new(profiles,'OPS-GOV')
pubEval = .InstitutionalPolicyAuthorityEvaluator~new(binding)
lifeEval = .InstitutionalPolicyLifecycleAuthorityEvaluator~new(binding)
policy = .InstitutionalPolicyRelease~new('OPS-POLICY','1.0',start,finish,'AUTHOR','APPROVER','',.nil,'PAYLOAD')~seal
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,pubEval,lifeEval)
pre = now
call assertTrue catalog~publish(policy,.InstitutionalPolicyPublicationRequest~new(policy,'PUBLISHER',pre))~ok,'policy published under v1 governance'
suspendAt = now + .InstitutionalPolicyTime~seconds(300)
s = catalog~applyLifecycle(policy~policyId,policy~version,.InstitutionalPolicyLifecycleRequest~new('LS-1','SUSPEND',policy,'OLD_DUTY',suspendAt,'old team incident hold','INC-OLD',suspendAt))
call assertTrue s~ok,'old duty manager authorized before governance cutover'
call assertEqual p1~semanticIdentity,s~value~authorityDecision~authorityProfileIdentity,'event snapshots v1 governance identity'
resumeAt = now + .InstitutionalPolicyTime~seconds(900)
r = catalog~applyLifecycle(policy~policyId,policy~version,.InstitutionalPolicyLifecycleRequest~new('LS-2','RESUME',policy,'NEW_DUTY',resumeAt,'new team clears incident','INC-NEW',resumeAt))
call assertTrue r~ok,'new duty manager authorized after governance cutover'
call assertEqual p2~semanticIdentity,r~value~authorityDecision~authorityProfileIdentity,'later event snapshots v2 governance identity'
call assertEqual p1~semanticIdentity,s~value~authorityDecision~authorityProfileIdentity,'later governance does not rewrite old lifecycle authority evidence'
say 'PASS test_lifecycle_authority_succession'
exit 0
addBase: procedure
  use arg profile,start
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(profile~version || '-AUTH','AUTHOR','AUTHOR','OPS-POLICY',start,.nil,'BOARD','AUTH:AUTHOR')~seal)
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(profile~version || '-APP','APPROVER','APPROVER','OPS-POLICY',start,.nil,'BOARD','AUTH:APP')~seal)
  ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(profile~version || '-PUB','PUBLISHER','PUBLISHER','OPS-POLICY',start,.nil,'BOARD','AUTH:PUB')~seal)
  return
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
