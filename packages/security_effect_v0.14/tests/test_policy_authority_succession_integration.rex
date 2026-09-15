t0=.DateTime~new
t1=t0+.InstitutionalPolicyTime~seconds(3600)
t2=t1+.InstitutionalPolicyTime~seconds(3600)
oldProfile=.InstitutionalPolicyAuthorityProfile~new('SEC-GOV','1.0',t0,t1)
ignored=oldProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('OA','TEAM','AUTHOR','SECURITY-CORE',t0,t1)~seal)
ignored=oldProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('OR','OLD-RISK','APPROVER','SECURITY-CORE',t0,t1)~seal)
ignored=oldProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('OP','OLD-BOT','PUBLISHER','SECURITY-CORE',t0,t1)~seal)
ignored=oldProfile~addRule(.InstitutionalPolicyAuthorityRule~new('OLD-RULE','SECURITY-CORE',.true,'OPTIONAL')~seal)
ignored=oldProfile~seal
newProfile=.InstitutionalPolicyAuthorityProfile~new('SEC-GOV','2.0',t1,.nil)
call assertTrue newProfile~setSupersedes('1.0')~ok,'successor declaration accepted'
ignored=newProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('NA','TEAM','AUTHOR','SECURITY-CORE',t1,.nil)~seal)
ignored=newProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('NR','NEW-RISK','APPROVER','SECURITY-CORE',t1,.nil)~seal)
ignored=newProfile~addGrant(.InstitutionalPolicyAuthorityGrant~new('NP','NEW-BOT','PUBLISHER','SECURITY-CORE',t1,.nil)~seal)
ignored=newProfile~addRule(.InstitutionalPolicyAuthorityRule~new('NEW-RULE','SECURITY-CORE',.true,'OPTIONAL')~seal)
ignored=newProfile~seal
profiles=.InstitutionalPolicyAuthorityProfileCatalog~new
call assertTrue profiles~publish(oldProfile)~ok,'old governance published'
call assertTrue profiles~publish(newProfile)~ok,'successor governance published'
binding=.InstitutionalPolicyAuthorityBinding~new(profiles,'SEC-GOV')
evaluator=.InstitutionalPolicyAuthorityEvaluator~new(binding)
catalog=.SecurityPolicyCatalog~new(.nil,.nil,evaluator)

oldFramework=.SecurityPolicyFramework~new('SECURITY-CORE','1.0',t0,t1,'TEAM','OLD-RISK','')~seal
oldRequest=.InstitutionalPolicyPublicationRequest~new(oldFramework,'OLD-BOT',t0+.InstitutionalPolicyTime~seconds(30))
call assertTrue catalog~publish(oldFramework,oldRequest)~ok,'historical security policy published under old governance'
oldRecord=catalog~publicationRecord('SECURITY-CORE','1.0')~value
oldGovIdentity=oldRecord~authorityDecision~authorityProfileIdentity
call assertEqual '1.0',oldRecord~authorityDecision~authorityProfileVersion,'old policy bound to old governance'

newFramework=.SecurityPolicyFramework~new('SECURITY-CORE','2.0',t1,t2,'TEAM','NEW-RISK','1.0')~seal
newRequest=.InstitutionalPolicyPublicationRequest~new(newFramework,'NEW-BOT',t1+.InstitutionalPolicyTime~seconds(30))
call assertTrue catalog~publish(newFramework,newRequest)~ok,'new security policy published under successor governance'
newRecord=catalog~publicationRecord('SECURITY-CORE','2.0')~value
call assertEqual '2.0',newRecord~authorityDecision~authorityProfileVersion,'new policy bound to new governance'
call assertEqual oldGovIdentity,oldRecord~authorityDecision~authorityProfileIdentity,'new governance does not rewrite old publication authority evidence'

say 'PASS test_policy_authority_succession_integration'
exit 0
assertTrue: procedure
 use arg v,l
 if v=.false then do; say 'FAIL:' l; exit 1; end
 return
assertEqual: procedure
 use arg e,a,l
 if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
 return
::requires 'SecurityEffect.cls'
