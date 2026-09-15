now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(60)
rs=now+.InstitutionalPolicyTime~seconds(10)
re=now+.InstitutionalPolicyTime~seconds(3600)
profile=.InstitutionalPolicyAuthorityProfile~new('SEC-DEMO','1',start,.nil)
ignore=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('D','DEPLOYER','DEPLOY','SECURITY-DEMO',start)~seal)
ignore=profile~seal
de=.InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
cat=.SecurityPolicyCatalog~new(.nil,.nil,.nil,.nil,de)
v1=makePolicy('1',start,'HOLD','')
ignore=cat~publish(v1)
v2=makePolicy('2',rs,'REVIEW_REQUIRED','1')
pilot=.InstitutionalPolicyDeploymentScope~new('PILOT','COMMERCE','GB','WEB','*','PILOT')~seal
global=.InstitutionalPolicyDeploymentScope~new('GLOBAL')~seal
gate=.InstitutionalPolicyRolloutGate~new('BOUNCER-GATE','1',pilot,300,300)
ignore=gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('N','EVALUATED_ACTIONS','GE',1000,1000)~seal)
ignore=gate~addCriterion(.InstitutionalPolicyRolloutCriterion~new('F','FALSE_POSITIVE_RATE','LE',0.01,1000)~seal)
ignore=gate~seal
pr=.InstitutionalPolicyProgressiveRequest~new('R',v1,v2,'DEPLOYER',re,'measured Bouncer rollout','CHG',now,gate)
ignore=cat~publish(v2,.nil,pr)
rollout=cat~progressiveBinding('SECURITY-DEMO','2')~value
t=rs+.InstitutionalPolicyTime~seconds(600)
obs=.array~new
obs~append(.InstitutionalPolicyRolloutObservation~new('N1',rollout,'EVALUATED_ACTIONS',6000,6000,rs,t,'BOUNCER-METRICS','N',pilot,t)~seal)
obs~append(.InstitutionalPolicyRolloutObservation~new('F1',rollout,'FALSE_POSITIVE_RATE',0.003,6000,rs,t,'BOUNCER-METRICS','F',pilot,t)~seal)
req=.InstitutionalPolicyDeploymentRequest~new('CUTOVER',v2,'DEPLOYER',global,'ACTIVE',t+.InstitutionalPolicyTime~seconds(10),.nil,'promote measured canary','CHG',t,obs)
r=cat~applyDeployment('SECURITY-DEMO','2',req)
say 'cutover=' r~ok 'assessment=' r~value~rolloutAssessment~outcome
exit 0
makePolicy: procedure
  use arg v,start,disp,super
  p=.SecurityPolicyFramework~new('SECURITY-DEMO',v,start,.nil,'A','B',super)
  r=.SecurityPolicyRule~new('R',1,'PURCHASE',disp,'demo')
  r~addCriterion('AMOUNT','GE',20000)
  ignore=p~addRule(r~seal)
  return p~seal
::requires 'SecurityEffect.cls'
