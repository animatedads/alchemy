now=.DateTime~new
subject='CUSTOMER:DEMO'
context='SESSION:DEMO:WEB:REV=1'
policy=.SecurityPolicyFramework~new('COMMIT-DEMO','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')
r=.SecurityPolicyRule~new('COMMIT-NEW-RISK',100,'METHOD_INVOCATION','HOLD','new compromise evidence blocks irreversible commit')
r~addCriterion('SECURITY_PHASE','EQ','COMMIT')
r~requireFinding('ACCOUNT_TAKEOVER_CONFIRMED')
policy~addRule(r~seal)
policy~seal
invp=.SecurityInvocationPolicy~new('INV','1',30,5,.true,.true,.true,'SECURITY','RISK')~seal
contp=.SecurityContinuationPolicy~new('CONT','1',300,10,5,.true,.true,.true,'SECURITY','RISK')~seal
engine=.SecurityEffectEngine~new
inv=.SecurityInvocationEvidence~new('INV-START','AMOUNT=20000',context,now)~seal
a=.SecurityMethodActionFactory~createInvocation('START','CUSTOMER:DEMO','TRANSFER:1','TRANSFERSERVICE','STARTTRANSFER',inv,now,'HIGH','TRANSFER')~value~seal
ass=engine~evaluate(a,.SecuritySnapshot~new('SNAP-START',subject,now)~seal,policy)~value
binding=.SecurityPermissionBindingFactory~fromInvocationAssessment(ass)~value
v=.SecurityInvocationGuard~new~validate(binding,inv,invp,now+.SecurityCanonical~timeSpanSeconds(1))~value
cont=.SecurityContinuationFactory~open(v,'CONT-1','EXECUTION:START-1:1','TRANSFER:1','AMOUNT=20000',context,now+.SecurityCanonical~timeSpanSeconds(1))~value
commitAt=now+.SecurityCanonical~timeSpanSeconds(20)
state='TRANSFER:1:STAGED:AMOUNT=20000:REV=4'
ce=.SecurityCommitEvidence~new('CE-1',cont~semanticIdentity,'TRANSFER:1',state,context,commitAt)~seal
ci=.SecurityInvocationEvidence~new('INV-COMMIT','COMMIT:TRANSFER:1:REV=4',context,commitAt)~seal
ca=.SecurityCommitActionFactory~createInvocation('COMMIT',cont,ce,'TRANSFER:1','TRANSFERSERVICE','COMMIT',ci,commitAt,'HIGH','TRANSFER')~value~seal
safe=engine~evaluate(ca,.SecuritySnapshot~new('SNAP-COMMIT-SAFE',subject,commitAt)~seal,policy)~value
say 'Initial commit assessment:' safe~disposition
finding=.SecurityFinding~new('F-1','ACCOUNT_TAKEOVER_CONFIRMED','CONCERN',subject,100,commitAt,commitAt+.SecurityCanonical~timeSpanSeconds(120),'customer denied initiating transfer','SECURITY_EFFECT')~seal
snap=.SecuritySnapshot~new('SNAP-COMMIT-BLOCKED',subject,commitAt)
call snap~addFinding finding
snap~seal
blocked=engine~evaluate(ca,snap,policy)~value
say 'After new evidence:' blocked~disposition
say 'Same staged operation; current evidence changed the commit decision.'
::requires 'SecurityEffect.cls'
