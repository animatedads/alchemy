now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
finish = now + .InstitutionalPolicyTime~seconds(3600)

profile = .InstitutionalPolicyAuthorityProfile~new('DEMO-GOV','1.0',start,.nil)
call grant profile,'A','AUTHOR','AUTHOR','DEMO-POLICY',start
call grant profile,'P','APPROVER','APPROVER','DEMO-POLICY',start
call grant profile,'R','RELEASE','PUBLISHER','DEMO-POLICY',start
call grant profile,'D','DEPLOYER','DEPLOY','DEMO-POLICY',start
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE','DEMO-POLICY',.true,'OPTIONAL')~seal)
ignored = profile~seal

policy = .InstitutionalPolicyRelease~new('DEMO-POLICY','1.0',start,finish,'AUTHOR','APPROVER','',.nil,'DEMO-PAYLOAD')~seal
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.InstitutionalPolicyAuthorityEvaluator~new(profile),.nil,.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile))
ignored = catalog~publish(policy,.InstitutionalPolicyPublicationRequest~new(policy,'RELEASE',now))

global = .InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
kzWeb = .InstitutionalPolicyDeploymentScope~new('KZ-WEB','COMMERCE','KZ','WEB')~seal
pilot = .InstitutionalPolicyDeploymentScope~new('KZ-PILOT','COMMERCE','KZ','WEB','*','PILOT')~seal
call deploy catalog,policy,'D1',global,'ACTIVE',now,'global'
call deploy catalog,policy,'D2',kzWeb,'STAGED',now,'regional staging'
call deploy catalog,policy,'D3',pilot,'CANARY',now,'pilot canary'

call show catalog,policy,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','GB','WEB','RETAIL','GENERAL'),now,'London web'
call show catalog,policy,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','GENERAL'),now,'Kazakhstan web'
call show catalog,policy,.InstitutionalPolicyDeploymentPoint~new('COMMERCE','KZ','WEB','RETAIL','PILOT'),now,'Kazakhstan pilot'
call show catalog,policy,.InstitutionalPolicyDeploymentPoint~new('OURLADYAIR','KZ','SHANNON','RETAIL','GENERAL'),now,'Shannon'

exit 0
grant: procedure
 use arg profile,id,principal,action,policyId,start
 ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new(id,principal,action,policyId,start,.nil,'BOARD','DEMO')~seal)
 return
deploy: procedure
 use arg catalog,policy,id,scope,mode,when,reason
 req=.InstitutionalPolicyDeploymentRequest~new(id,policy,'DEPLOYER',scope,mode,when,.nil,reason,'DEMO',when)
 ignored=catalog~applyDeployment(policy~policyId,policy~version,req)
 return
show: procedure
 use arg catalog,policy,point,when,label
 state=catalog~topologyState(policy~policyId,policy~version,point,when)
 if state~ok then say label':' state~value~mode 'operative='state~value~operative
 else say label':' state~code
 return
::requires 'InstitutionalPolicy.cls'
