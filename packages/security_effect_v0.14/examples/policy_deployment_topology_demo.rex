now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
profile=.InstitutionalPolicyAuthorityProfile~new('SEC-DEMO-GOV','1.0',start,.nil)
call grant profile,'A','SECURITY_TEAM','AUTHOR','SECURITY-POLICY-CORE',start
call grant profile,'P','RISK_COMMITTEE','APPROVER','SECURITY-POLICY-CORE',start
call grant profile,'R','SECURITY_RELEASE','PUBLISHER','SECURITY-POLICY-CORE',start
call grant profile,'D','PLATFORM_RELEASE','DEPLOY','SECURITY-POLICY-CORE',start
ignored=profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE','SECURITY-POLICY-CORE',.true,'OPTIONAL')~seal)
ignored=profile~seal
catalog=.SecurityPolicyCatalog~new(.nil,.nil,.InstitutionalPolicyAuthorityEvaluator~new(profile),.nil,.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile))
policy=.SecurityTestSupport~basePolicy(now)
ignored=catalog~publish(policy,.InstitutionalPolicyPublicationRequest~new(policy,'SECURITY_RELEASE',now))
call deploy catalog,policy,'GLOBAL',.InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal,'ACTIVE',now
call deploy catalog,policy,'KZ-WEB',.InstitutionalPolicyDeploymentScope~new('KZ-WEB','COMMERCE','KZ','WEB')~seal,'STAGED',now
call deploy catalog,policy,'KZ-PILOT',.InstitutionalPolicyDeploymentScope~new('KZ-PILOT','COMMERCE','KZ','WEB','*','PILOT')~seal,'CANARY',now
subject='CUSTOMER-DEMO'
module=.SecurityEffectRuntimeModule~new(catalog)
ignored=module~runtimeStart
ignored=module~evidenceStore~recordFinding(.SecurityTestSupport~geoFinding(subject,now))
call assess module,subject,now,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL'),'London web'
call assess module,subject,now,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','GENERAL'),'Kazakhstan web'
call assess module,subject,now,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','PILOT'),'Kazakhstan pilot'
exit 0
grant: procedure
 use arg profile,id,principal,action,policyId,start
 ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(id,principal,action,policyId,start,.nil,'SECURITY_BOARD','DEMO')~seal)
 return
deploy: procedure
 use arg catalog,policy,id,scope,mode,when
 req=.InstitutionalPolicyDeploymentRequest~new(id,policy,'PLATFORM_RELEASE',scope,mode,when,.nil,'demo deployment','DEMO',when)
 ignored=catalog~applyDeployment(policy~policyId,policy~version,req)
 return
assess: procedure
 use arg module,subject,when,point,label
 a=.SecurityActionSurface~new('A-' || label,subject,'PURCHASE',when,'HIGH','PAYMENT')
 a~putAttribute('PAYMENT_INSTRUMENT','STORED')
 a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
 a~putAttribute('AMOUNT',22000)
 a~seal
 result=module~assess(a,point)
 if result~ok then say label':' result~value~disposition
 else say label':' result~code
 return
::requires 'SecurityEffectRuntimeModule.cls'
::requires 'TestSupport.cls'
