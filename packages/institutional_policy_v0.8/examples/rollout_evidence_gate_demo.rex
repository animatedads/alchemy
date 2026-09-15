now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
rs=now+.InstitutionalPolicyTime~seconds(10)
re=now+.InstitutionalPolicyTime~seconds(3600)
profile=.InstitutionalPolicyAuthorityProfile~new('DEMO','1',start,.nil)
ignore=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('D','DEPLOYER','DEPLOY','DEMO-POL',start)~seal)
ignore=profile~seal
eval=.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
cat=.InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,eval)
v1=.InstitutionalPolicyRelease~new('DEMO-POL','1',start,.nil,'A','B','',.nil,'V1')~seal
ignore=cat~publish(v1)
v2=.InstitutionalPolicyRelease~new('DEMO-POL','2',rs,.nil,'A','B','1',.nil,'V2')~seal
pilot=.InstitutionalPolicyDeploymentScope~new('PILOT','APP','GB','WEB','*','PILOT')~seal
global=.InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
gate=.InstitutionalPolicyRolloutGate~new('GATE','1',pilot,300,300)
ignore=gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('N','EVALUATED_ACTIONS','GE',1000,1000)~seal)
ignore=gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('E','ERROR_RATE','LE',0.01,1000)~seal)
ignore=gate~seal
pr=.InstitutionalPolicyProgressiveRequest~new('ROLLOUT',v1,v2,'DEPLOYER',re,'measured rollout','CHG',now,gate)
ignore=cat~publish(v2,.nil,pr)
rollout=cat~progressiveBinding('DEMO-POL','2')~value
t=rs+.InstitutionalPolicyTime~seconds(600)
obs=.array~new
obs~append(.InstitutionalPolicyRolloutObservation~new('N1',rollout,'EVALUATED_ACTIONS',5000,5000,rs,t,'METRICS','N',pilot,t)~seal)
obs~append(.InstitutionalPolicyRolloutObservation~new('E1',rollout,'ERROR_RATE',0.002,5000,rs,t,'METRICS','E',pilot,t)~seal)
req=.InstitutionalPolicyDeploymentRequest~new('PROMOTE',v2,'DEPLOYER',global,'ACTIVE',t+.InstitutionalPolicyTime~seconds(10),.nil,'promote after gate','CHG',t,obs)
r=cat~applyDeployment('DEMO-POL','2',req)
say 'promotion=' r~ok 'assessment=' r~value~rolloutAssessment~outcome
::requires 'InstitutionalPolicy.cls'
