now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(3600)
endAt=now+.InstitutionalPolicyTime~seconds(7200)
revokeAt=now+.InstitutionalPolicyTime~seconds(1800)
profile=.InstitutionalPolicyAuthorityProfile~new('DELEGATION-GOV','1.0',start,endAt)
parent=.InstitutionalPolicyAuthorityGrant~new('PARENT','RISK-DIRECTOR','APPROVER','SECURITY-CORE',start,endAt,'BOARD','','SECURITY')~seal
delegate=.InstitutionalPolicyAuthorityGrant~new('DELEGATE','DEPUTY-RISK','APPROVER','SECURITY-CORE',now,endAt,'RISK-DIRECTOR','DELEGATION-77','SECURITY','PARENT')~seal
call must profile~addGrant(parent),'parent'
call must profile~addGrant(delegate),'delegate'
call must profile~addRevocation(.InstitutionalPolicyAuthorityRevocation~new('REVOKE-DELEGATE','DELEGATE',revokeAt,'RISK-DIRECTOR','REV-88')~seal),'revocation'
call must profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE','SECURITY-CORE',.true,'OPTIONAL')~seal),'rule'
ignored=profile~seal
before=profile~authorityGrant('DEPUTY-RISK','APPROVER','SECURITY-CORE',now+.InstitutionalPolicyTime~seconds(60),'SECURITY')
call assertTrue before~ok,'delegated grant valid before revocation'
after=profile~authorityGrant('DEPUTY-RISK','APPROVER','SECURITY-CORE',revokeAt+.InstitutionalPolicyTime~seconds(1),'SECURITY')
call assertTrue \after~ok,'delegated grant denied after revocation'
call assertEqual 'POLICY_AUTHORITY_NOT_GRANTED',after~code,'revocation removes grant operationally'
parentStill=profile~authorityGrant('RISK-DIRECTOR','APPROVER','SECURITY-CORE',revokeAt+.InstitutionalPolicyTime~seconds(1),'SECURITY')
call assertTrue parentStill~ok,'parent authority remains valid'

profile2=.InstitutionalPolicyAuthorityProfile~new('DELEGATION-GOV-2','1.0',start,endAt)
parent2=.InstitutionalPolicyAuthorityGrant~new('PARENT2','RISK-DIRECTOR','APPROVER','SECURITY-CORE',start,endAt,'BOARD','','SECURITY')~seal
delegate2=.InstitutionalPolicyAuthorityGrant~new('DELEGATE2','DEPUTY-RISK','APPROVER','SECURITY-CORE',now,endAt,'RISK-DIRECTOR','DELEGATION-78','SECURITY','PARENT2')~seal
call must profile2~addGrant(parent2),'parent2'
call must profile2~addGrant(delegate2),'delegate2'
call must profile2~addRevocation(.InstitutionalPolicyAuthorityRevocation~new('REVOKE-PARENT','PARENT2',revokeAt,'BOARD','REV-89')~seal),'parent revocation'
call must profile2~addRule(.InstitutionalPolicyAuthorityRule~new('RULE2','SECURITY-CORE',.true,'OPTIONAL')~seal),'rule2'
ignored=profile2~seal
transitive=profile2~authorityGrant('DEPUTY-RISK','APPROVER','SECURITY-CORE',revokeAt+.InstitutionalPolicyTime~seconds(1),'SECURITY')
call assertTrue \transitive~ok,'revoking parent authority transitively revokes delegation'

say 'PASS test_authority_delegation_revocation'
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
