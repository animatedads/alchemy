now=.DateTime~new
subject='CUSTOMER:BARBIE'
context='SESSION:BARBIE:WEB:REV=9'

/* The original invocation is admitted against its exact arguments/context. */
secPolicy=.SecurityPolicyFramework~new('COMMIT-SECURITY','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')
commitHold=.SecurityPolicyRule~new('COMMIT-ACCOUNT-TAKEOVER',100,'METHOD_INVOCATION','HOLD','new account-takeover evidence blocks irreversible commit')
commitHold~addCriterion('SECURITY_PHASE','EQ','COMMIT')
commitHold~requireFinding('ACCOUNT_TAKEOVER_CONFIRMED')
commitHold~addConstraint('ABORT_OR_REVIEW_COMMIT','OPERATION')
secPolicy~addRule(commitHold~seal)
secPolicy~seal
invPolicy=.SecurityInvocationPolicy~new('METHOD-FRESHNESS','1',30,5,.true,.true,.true,'SECURITY','RISK')~seal
continuationPolicy=.SecurityContinuationPolicy~new('COMMIT-FRESHNESS','1',300,10,5,.true,.true,.true,'SECURITY','RISK')~seal
originInv=.SecurityInvocationEvidence~new('INV-START-1','TRANSFER:FROM=A:TO=B:AMOUNT=20000',context,now)~seal
originAction=.SecurityMethodActionFactory~createInvocation('START-TRANSFER-1',subject,'OBJECT:TRANSFER:42','TRANSFERSERVICE','STARTTRANSFER',originInv,now,'HIGH','TRANSFER_FUNDS')~value~seal
originSnapshot=.SecuritySnapshot~new('SNAP-START-1',subject,now)~seal
originAssessment=.SecurityEffectEngine~new~evaluate(originAction,originSnapshot,secPolicy)~value
call assertEqual 'ALLOW',originAssessment~disposition,'original invocation is initially safe'
originBinding=.SecurityPermissionBindingFactory~fromInvocationAssessment(originAssessment)~value
originGuard=.SecurityInvocationGuard~new
originValidation=originGuard~validate(originBinding,originInv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(1))
call assertTrue originValidation~ok,'origin invocation validates'
missingExecution=.SecurityContinuationFactory~open(originValidation~value,'CONT-NO-EXEC','','TRANSFER:42','TRANSFER:FROM=A:TO=B:AMOUNT=20000',context,now+.SecurityCanonical~timeSpanSeconds(1))
call assertTrue \missingExecution~ok,'Security validation alone cannot claim that staged work actually started'
call assertEqual 'SECURITY_ORIGIN_EXECUTION_EVIDENCE_REQUIRED',missingExecution~code,'origin execution evidence identity required'
continuation=.SecurityContinuationFactory~open(originValidation~value,'CONT-TRANSFER-42','EXECUTION:START-TRANSFER-42:1','TRANSFER:42','TRANSFER:FROM=A:TO=B:AMOUNT=20000',context,now+.SecurityCanonical~timeSpanSeconds(1))~value
call assertEqual originBinding~semanticIdentity,continuation~originBindingIdentity,'continuation binds exact original Security invocation'

/* The staged state is separately sealed immediately before commit. */
commitAt=now+.SecurityCanonical~timeSpanSeconds(20)
state='TRANSFER:42:STAGED:DEBIT=A:20000:CREDIT=B:20000:REV=7'
commitEvidence=.SecurityCommitEvidence~new('COMMIT-EVIDENCE-42',continuation~semanticIdentity,continuation~operationId,state,context,commitAt)~seal
commitInv=.SecurityInvocationEvidence~new('INV-COMMIT-42','COMMIT:TRANSFER:42:REV=7',context,commitAt)~seal
commitAction=.SecurityCommitActionFactory~createInvocation('COMMIT-TRANSFER-42',continuation,commitEvidence,'OBJECT:TRANSFER:42','TRANSFERSERVICE','COMMIT',commitInv,commitAt,'HIGH','TRANSFER_FUNDS')~value~seal
commitSnapshot=.SecuritySnapshot~new('SNAP-COMMIT-42',subject,commitAt)~seal
commitAssessment=.SecurityEffectEngine~new~evaluate(commitAction,commitSnapshot,secPolicy)~value
call assertEqual 'ALLOW',commitAssessment~disposition,'fresh commit snapshot allows unchanged safe operation'
commitGuard=.SecurityContinuationGuard~new
ok=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(2),state,context)
call assertTrue ok~ok,'exact staged state plus current Security snapshot validates for commit'

/* A different live staged state cannot reuse the same commit assessment. */
badState=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(2),'TRANSFER:42:STAGED:DEBIT=A:2000000:CREDIT=B:2000000:REV=8',context)
call assertTrue \badState~ok,'changed staged state rejected'
call assertEqual 'SECURITY_COMMIT_STATE_MISMATCH',badState~code,'state mismatch explicit'

/* A changed session/workspace context also invalidates the commit. */
badContext=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(2),state,'SESSION:BARBIE:WEB:REV=10')
call assertTrue \badContext~ok,'changed commit context rejected'
call assertEqual 'SECURITY_COMMIT_CONTEXT_MISMATCH',badContext~code,'context mismatch explicit'

/* New security evidence after admission is evaluated at commit, not ignored. */
takeover=.SecurityFinding~new('F-TAKEOVER-42','ACCOUNT_TAKEOVER_CONFIRMED','CONCERN',subject,100,commitAt-.SecurityCanonical~timeSpanSeconds(1),commitAt+.SecurityCanonical~timeSpanSeconds(120),'out-of-band confirmation says customer did not initiate transaction','SECURITY_EFFECT')~seal
blockedSnapshot=.SecuritySnapshot~new('SNAP-COMMIT-BLOCKED',subject,commitAt)
call blockedSnapshot~addFinding takeover
blockedSnapshot~seal
blockedAssessment=.SecurityEffectEngine~new~evaluate(commitAction,blockedSnapshot,secPolicy)~value
call assertEqual 'HOLD',blockedAssessment~disposition,'new adverse evidence changes commit assessment'
blocked=commitGuard~validateCommit(originBinding,continuation,commitEvidence,blockedAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(2),state,context)
call assertTrue \blocked~ok,'commit blocked by current Security assessment'
call assertEqual 'SECURITY_COMMIT_NOT_ALLOWED',blocked~code,'commit hold is explicit'

/* Commit evidence freshness is anchored to when the staged state was observed. */
stale=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(11),state,context)
call assertTrue \stale~ok,'stale commit evidence rejected'
call assertEqual 'SECURITY_COMMIT_EVIDENCE_EXPIRED',stale~code,'commit evidence expiry explicit'

/* Successful commit is single-use and cannot be replayed. */
valid=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(3),state,context)
call assertTrue valid~ok,'fresh commit validation produced'
call assertTrue commitGuard~consume(valid~value)~ok,'successful commit validation consumed'
replay=commitGuard~validateCommit(originBinding,continuation,commitEvidence,commitAssessment,continuationPolicy,commitAt+.SecurityCanonical~timeSpanSeconds(4),state,context)
call assertTrue \replay~ok,'same continuation cannot commit twice'
call assertEqual 'SECURITY_CONTINUATION_ALREADY_COMMITTED',replay~code,'commit replay explicit'

say 'PASS test_commit_revalidation'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'SecurityEffect.cls'
