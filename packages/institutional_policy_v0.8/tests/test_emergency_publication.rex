now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
profile=.InstitutionalPolicyAuthorityProfile~new('EMERGENCY-GOV','1.0',start,.nil)
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('AUTH','OPS-AUTHOR','AUTHOR','INCIDENT-POLICY',start,.nil)~seal),'author'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('APP','DUTY-MANAGER','APPROVER','INCIDENT-POLICY',start,.nil)~seal),'approver'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('EPUB','INCIDENT-COMMANDER','EMERGENCY_PUBLISHER','INCIDENT-POLICY',start,.nil,'BOARD','BREAKGLASS','EMERGENCY')~seal),'emergency publisher'
rule=.InstitutionalPolicyAuthorityRule~new('ERULE','INCIDENT-POLICY',.true,'OPTIONAL',.true,14400)
call must profile~addRule(rule~seal),'emergency rule'
ignored=profile~seal

goodEnd=now+.InstitutionalPolicyTime~seconds(7200)
policy=.InstitutionalPolicyRelease~new('INCIDENT-POLICY','E1',now,goodEnd,'OPS-AUTHOR','DUTY-MANAGER','',.nil,'INCIDENT-LOCKDOWN')~seal
request=.InstitutionalPolicyPublicationRequest~new(policy,'INCIDENT-COMMANDER',now,.true,'active credential-stuffing incident',goodEnd)
decision=.InstitutionalPolicyAuthorityEvaluator~new(profile)~evaluate(policy,request)
call assertTrue decision~ok,'bounded emergency publication succeeds'
call assertTrue decision~emergency,'emergency decision labelled'
call assertEqual 'EPUB',decision~emergencyGrantId,'emergency grant snapshotted'

badEnd=now+.InstitutionalPolicyTime~seconds(28800)
badPolicy=.InstitutionalPolicyRelease~new('INCIDENT-POLICY','E2',now,badEnd,'OPS-AUTHOR','DUTY-MANAGER','',.nil,'TOO-LONG')~seal
badReq=.InstitutionalPolicyPublicationRequest~new(badPolicy,'INCIDENT-COMMANDER',now,.true,'incident',badEnd)
bad=.InstitutionalPolicyAuthorityEvaluator~new(profile)~evaluate(badPolicy,badReq)
call assertTrue \bad~ok,'overlong emergency policy rejected'
call assertEqual 'EMERGENCY_AUTHORITY_EXCEEDS_MAX_LIFETIME',bad~code,'bounded emergency authority lifetime enforced'

normal=.InstitutionalPolicyPublicationRequest~new(policy,'INCIDENT-COMMANDER',now)
normalResult=.InstitutionalPolicyAuthorityEvaluator~new(profile)~evaluate(policy,normal)
call assertTrue \normalResult~ok,'emergency authority does not silently become normal publisher authority'
call assertEqual 'PUBLISHER_AUTHORITY_DENIED',normalResult~code,'normal publication requires normal publisher grant'

say 'PASS test_emergency_publication'
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
