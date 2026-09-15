now=.DateTime~new
subject='CUSTOMER:BARBIE'
context='SESSION:BARBIE:WEB:REV=9'
objectId='OBJECT:TRANSFER:42'
objectClass='TRANSFERSERVICE'

secPolicy=.SecurityPolicyFramework~new('COMMIT-SECURITY','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')
hold=.SecurityPolicyRule~new('COMMIT-TAKEOVER',100,'METHOD_INVOCATION','HOLD','new takeover evidence blocks commit')
hold~addCriterion('SECURITY_PHASE','EQ','COMMIT')
hold~requireFinding('ACCOUNT_TAKEOVER_CONFIRMED')
secPolicy~addRule(hold~seal)
secPolicy~seal
invPolicy=.SecurityInvocationPolicy~new('METHOD-FRESHNESS','1',30,5,.true,.true,.true,'SECURITY','RISK')~seal
contPolicy=.SecurityContinuationPolicy~new('COMMIT-FRESHNESS','1',300,10,5,.true,.true,.true,'SECURITY','RISK')~seal
engine=.SecurityEffectEngine~new

/* Admit original method and open continuation from its exact validation. */
originInv=.SecurityInvocationEvidence~new('INV-START-42','TRANSFER:FROM=A:TO=B:AMOUNT=20000',context,now)~seal
originAction=.SecurityMethodActionFactory~createInvocation('START-42',subject,objectId,objectClass,'STARTTRANSFER',originInv,now,'HIGH','TRANSFER_FUNDS')~value~seal
originAssessment=engine~evaluate(originAction,.SecuritySnapshot~new('SNAP-START',subject,now)~seal,secPolicy)~value
originBinding=.SecurityPermissionBindingFactory~fromInvocationAssessment(originAssessment)~value
originInvGuard=.SecurityInvocationGuard~new
originValidation=originInvGuard~validate(originBinding,originInv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(1))
call assertTrue originValidation~ok,'origin Security invocation validates'
continuation=.SecurityContinuationFactory~open(originValidation~value,'CONT-42','EXECUTION:START-42:1','TRANSFER:42','TRANSFER:FROM=A:TO=B:AMOUNT=20000',context,now+.SecurityCanonical~timeSpanSeconds(1))~value

/* Prepare exact irreversible commit. */
commitAt=now+.SecurityCanonical~timeSpanSeconds(20)
state='TRANSFER:42:STAGED:REV=7:AMOUNT=20000'
commitEvidence=.SecurityCommitEvidence~new('CE-42',continuation~semanticIdentity,'TRANSFER:42',state,context,commitAt)~seal
commitInv=.SecurityInvocationEvidence~new('INV-COMMIT-42','COMMIT:TRANSFER:42:REV=7',context,commitAt)~seal
commitAction=.SecurityCommitActionFactory~createInvocation('COMMIT-42',continuation,commitEvidence,objectId,objectClass,'COMMIT',commitInv,commitAt,'HIGH','TRANSFER_FUNDS')~value~seal
commitAssessment=engine~evaluate(commitAction,.SecuritySnapshot~new('SNAP-COMMIT',subject,commitAt)~seal,secPolicy)~value
call assertEqual 'ALLOW',commitAssessment~disposition,'Security currently allows exact commit'

permAllow=.PermissionPolicy~new('TRANSFER-COMMIT','1','DENY',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')
permAllow~addRule(.PermissionRule~new('ALLOW-COMMIT',100,'ALLOW',subject,objectId,objectClass,'COMMIT','ALLOW','*','')~seal)
permAllow~seal
permDeny=.PermissionPolicy~new('TRANSFER-COMMIT-DENY','1','DENY',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')~seal
authority=.PermissionAuthority~new
bridge=.SecurityContinuationAccessPermissionsBridge~new
commitInvGuard=.SecurityInvocationGuard~new
contGuard=.SecurityContinuationGuard~new
prepResult=bridge~permissionRequestForCommit('PERM-COMMIT-42',originBinding,continuation,commitEvidence,commitAssessment,commitInv,invPolicy,commitInvGuard,contPolicy,contGuard,commitAt+.SecurityCanonical~timeSpanSeconds(2),state,context)
call assertTrue prepResult~ok,'fresh continuation prepares exact commit Permission request'
prep=prepResult~value
decision=authority~decide(prep~request,permAllow)
call assertTrue decision~ok,'Permission authority evaluates COMMIT'
call assertTrue decision~value~decision~allowed,'exact COMMIT permission allows'
committed=prep~commitIfAllowed(decision)
call assertTrue committed~ok,'allowed Permission consumes invocation and continuation commit validations'
call assertTrue commitInvGuard~used(prep~binding),'commit METHOD invocation consumed'
call assertTrue contGuard~committed(continuation),'continuation marked committed'

/* Permission denial remains authority: Security ALLOW alone cannot commit. */
originInv2=.SecurityInvocationEvidence~new('INV-START-43','TRANSFER:FROM=A:TO=B:AMOUNT=10',context,now)~seal
originAction2=.SecurityMethodActionFactory~createInvocation('START-43',subject,'OBJECT:TRANSFER:43',objectClass,'STARTTRANSFER',originInv2,now,'NORMAL','TRANSFER_FUNDS')~value~seal
originAssessment2=engine~evaluate(originAction2,.SecuritySnapshot~new('SNAP-START-43',subject,now)~seal,secPolicy)~value
originBinding2=.SecurityPermissionBindingFactory~fromInvocationAssessment(originAssessment2)~value
originValidation2=.SecurityInvocationGuard~new~validate(originBinding2,originInv2,invPolicy,now+.SecurityCanonical~timeSpanSeconds(1))
cont2=.SecurityContinuationFactory~open(originValidation2~value,'CONT-43','EXECUTION:START-43:1','TRANSFER:43','AMOUNT=10',context,now+.SecurityCanonical~timeSpanSeconds(1))~value
state2='TRANSFER:43:STAGED:REV=2:AMOUNT=10'
ce2=.SecurityCommitEvidence~new('CE-43',cont2~semanticIdentity,'TRANSFER:43',state2,context,commitAt)~seal
ci2=.SecurityInvocationEvidence~new('INV-COMMIT-43','COMMIT:TRANSFER:43:REV=2',context,commitAt)~seal
ca2=.SecurityCommitActionFactory~createInvocation('COMMIT-43',cont2,ce2,'OBJECT:TRANSFER:43',objectClass,'COMMIT',ci2,commitAt,'NORMAL','TRANSFER_FUNDS')~value~seal
ass2=engine~evaluate(ca2,.SecuritySnapshot~new('SNAP-COMMIT-43',subject,commitAt)~seal,secPolicy)~value
ig2=.SecurityInvocationGuard~new
cg2=.SecurityContinuationGuard~new
prep2=bridge~permissionRequestForCommit('PERM-COMMIT-43',originBinding2,cont2,ce2,ass2,ci2,invPolicy,ig2,contPolicy,cg2,commitAt+.SecurityCanonical~timeSpanSeconds(2),state2,context)~value
denied=authority~decide(prep2~request,permDeny)
call assertTrue denied~ok,'deny policy evaluated'
call assertTrue \denied~value~decision~allowed,'Permission denies despite Security ALLOW'
notCommitted=prep2~commitIfAllowed(denied)
call assertTrue \notCommitted~ok,'Permission deny does not commit'
call assertEqual 'PERMISSION_DENIED',notCommitted~code,'Permission deny explicit'
call assertTrue \ig2~used(prep2~binding),'Permission deny does not consume commit invocation'
call assertTrue \cg2~committed(cont2),'Permission deny does not consume continuation'

/* New adverse evidence blocks before Permission authority is relevant. */
takeover=.SecurityFinding~new('F-TAKEOVER-43','ACCOUNT_TAKEOVER_CONFIRMED','CONCERN',subject,100,commitAt-.SecurityCanonical~timeSpanSeconds(1),commitAt+.SecurityCanonical~timeSpanSeconds(120),'customer denied initiating transfer','SECURITY_EFFECT')~seal
blockedSnap=.SecuritySnapshot~new('SNAP-BLOCKED-43',subject,commitAt)
call blockedSnap~addFinding takeover
blockedSnap~seal
blockedAss=engine~evaluate(ca2,blockedSnap,secPolicy)~value
call assertEqual 'HOLD',blockedAss~disposition,'current Bouncer evidence holds commit'
blocked=bridge~permissionRequestForCommit('PERM-COMMIT-BLOCKED',originBinding2,cont2,ce2,blockedAss,ci2,invPolicy,.SecurityInvocationGuard~new,contPolicy,.SecurityContinuationGuard~new,commitAt+.SecurityCanonical~timeSpanSeconds(2),state2,context)
call assertTrue \blocked~ok,'Security HOLD blocks preparation before Permission decision'
call assertEqual 'SECURITY_COMMIT_NOT_ALLOWED',blocked~code,'commit security hold explicit'

say 'PASS test_access_permissions_commit_boundary'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'SecurityEffect.cls'
::requires 'SecurityContinuationAccessPermissionsBridge.cls'
