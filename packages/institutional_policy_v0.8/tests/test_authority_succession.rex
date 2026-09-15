t0 = .DateTime~new
t1 = t0 + .InstitutionalPolicyTime~seconds(3600)
t2 = t1 + .InstitutionalPolicyTime~seconds(3600)

p1 = .InstitutionalPolicyAuthorityProfile~new('CORP-GOV','1.0',t0,t1)
call must p1~addGrant(.InstitutionalPolicyAuthorityGrant~new('A1','ALICE','AUTHOR','OPS-POLICY',t0,t1)~seal),'p1 author'
call must p1~addGrant(.InstitutionalPolicyAuthorityGrant~new('R1','BOB','APPROVER','OPS-POLICY',t0,t1)~seal),'p1 approver'
call must p1~addGrant(.InstitutionalPolicyAuthorityGrant~new('P1','BOT1','PUBLISHER','OPS-POLICY',t0,t1)~seal),'p1 publisher'
call must p1~addRule(.InstitutionalPolicyAuthorityRule~new('RULE1','OPS-POLICY',.true,'OPTIONAL')~seal),'p1 rule'
ignored=p1~seal

p2 = .InstitutionalPolicyAuthorityProfile~new('CORP-GOV','2.0',t1,.nil)
call must p2~setSupersedes('1.0'),'p2 supersedes'
call must p2~addGrant(.InstitutionalPolicyAuthorityGrant~new('A2','ALICE','AUTHOR','OPS-POLICY',t1,.nil)~seal),'p2 author'
call must p2~addGrant(.InstitutionalPolicyAuthorityGrant~new('R2','CAROL','APPROVER','OPS-POLICY',t1,.nil)~seal),'p2 approver'
call must p2~addGrant(.InstitutionalPolicyAuthorityGrant~new('P2','BOT2','PUBLISHER','OPS-POLICY',t1,.nil)~seal),'p2 publisher'
call must p2~addRule(.InstitutionalPolicyAuthorityRule~new('RULE2','OPS-POLICY',.true,'OPTIONAL')~seal),'p2 rule'
ignored=p2~seal

catalog = .InstitutionalPolicyAuthorityProfileCatalog~new
call must catalog~publish(p1),'publish p1'
call must catalog~publish(p2),'publish p2'
call assertEqual '1.0',catalog~resolve('CORP-GOV',t0 + .InstitutionalPolicyTime~seconds(10))~value~version,'historical governance resolves v1'
call assertEqual '2.0',catalog~resolve('CORP-GOV',t1)~value~version,'boundary resolves v2'

binding = .InstitutionalPolicyAuthorityBinding~new(catalog,'CORP-GOV')
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(binding)
oldPolicy = .InstitutionalPolicyRelease~new('OPS-POLICY','1.0',t0,t1,'ALICE','BOB','',.nil,'OLD')~seal
oldReq = .InstitutionalPolicyPublicationRequest~new(oldPolicy,'BOT1',t0 + .InstitutionalPolicyTime~seconds(20))
oldDecision = evaluator~evaluate(oldPolicy,oldReq)
call assertTrue oldDecision~ok,'old publication uses old profile'
call assertEqual '1.0',oldDecision~authorityProfileVersion,'old decision snapshots v1 profile'
oldIdentity = oldDecision~authorityProfileIdentity

newPolicy = .InstitutionalPolicyRelease~new('OPS-POLICY','2.0',t1,t2,'ALICE','CAROL','1.0',.nil,'NEW')~seal
newReq = .InstitutionalPolicyPublicationRequest~new(newPolicy,'BOT2',t1 + .InstitutionalPolicyTime~seconds(20))
newDecision = evaluator~evaluate(newPolicy,newReq)
call assertTrue newDecision~ok,'new publication uses successor profile'
call assertEqual '2.0',newDecision~authorityProfileVersion,'new decision snapshots v2 profile'
call assertTrue oldIdentity <> newDecision~authorityProfileIdentity,'successor governance identity differs'
call assertEqual oldIdentity,oldDecision~authorityProfileIdentity,'old authority evidence remains unchanged'

say 'PASS test_authority_succession'
exit 0
must: procedure
  use arg r,l
  if \r~ok then do; say 'FAIL:' l r~code r~detail; exit 1; end
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
