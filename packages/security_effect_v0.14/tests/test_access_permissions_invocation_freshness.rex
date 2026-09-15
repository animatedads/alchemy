now=.DateTime~new
subject='CUSTOMER:BARBIE'
objectId='OBJECT:BAG-ORDER:42'
objectClass='BAGORDERSERVICE'
method='PURCHASEMOREBAGS'
secPolicy=.SecurityPolicyFramework~new('METHOD-SECURITY','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')~seal
invPolicy=.SecurityInvocationPolicy~new('METHOD-FRESHNESS','1',30,5,.true,.true,.true,'SECURITY','RISK')~seal
inv=.SecurityInvocationEvidence~new('INV-PERM-1','ORDER:QTY=4:TOTAL=20000','SESSION:BARBIE:WEB:REV=9',now)~seal
a=.SecurityMethodActionFactory~createInvocation('METHOD-PERM-INV',subject,objectId,objectClass,method,inv,now,'HIGH','PURCHASE_MORE_BAGS')~value~seal
snap=.SecuritySnapshot~new('SNAP-PERM-INV',subject,now)~seal
assessment=.SecurityEffectEngine~new~evaluate(a,snap,secPolicy)~value
call assertEqual 'ALLOW',assessment~disposition,'Security meaning baseline allows'
permPolicy=.PermissionPolicy~new('EXACT-BAG-METHOD','1','DENY',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')
permPolicy~addRule(.PermissionRule~new('ALLOW-EXACT',100,'ALLOW',subject,objectId,objectClass,method,'ALLOW','*','')~seal)
permPolicy~seal
denyPolicy=.PermissionPolicy~new('DENY-BAG-METHOD','1','DENY',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')~seal
authority=.PermissionAuthority~new
bridge=.SecurityAccessPermissionsBridge~new
guard=.SecurityInvocationGuard~new
prepResult=bridge~permissionRequestForInvocation('PERM-INV-1',assessment,inv,invPolicy,guard,now+.SecurityCanonical~timeSpanSeconds(5))
call assertTrue prepResult~ok,'fresh invocation prepares permission request'
prep=prepResult~value
decision=authority~decide(prep~request,permPolicy)
call assertTrue decision~ok,'Permission authority evaluates exact request'
call assertTrue decision~value~decision~allowed,'exact Permission policy allows'
commit=prep~commitIfAllowed(decision)
call assertTrue commit~ok,'allowed Permission decision consumes invocation binding'
call assertTrue guard~used(prep~binding),'binding marked used only after Permission allow'
again=bridge~permissionRequestForInvocation('PERM-INV-REPLAY',assessment,inv,invPolicy,guard,now+.SecurityCanonical~timeSpanSeconds(6))
call assertTrue \again~ok,'same Security evidence cannot be replayed for another permission request'
call assertEqual 'SECURITY_INVOCATION_ALREADY_USED',again~code,'replay refusal explicit'
/* Altered argument evidence cannot be attached to the old Security assessment. */
changed=.SecurityInvocationEvidence~new('INV-PERM-1','ORDER:QTY=400:TOTAL=2000000',inv~contextIdentity,now)~seal
guard2=.SecurityInvocationGuard~new
bad=bridge~permissionRequestForInvocation('PERM-INV-BADARGS',assessment,changed,invPolicy,guard2,now+.SecurityCanonical~timeSpanSeconds(5))
call assertTrue \bad~ok,'changed arguments rejected before Permission authority'
call assertEqual 'SECURITY_INVOCATION_EVIDENCE_MISMATCH',bad~code,'changed-argument refusal explicit'
/* A Permission deny does not consume Security evidence; a later authorized retry may still evaluate it within freshness window. */
inv2=.SecurityInvocationEvidence~new('INV-PERM-2','ORDER:QTY=1:TOTAL=5000','SESSION:BARBIE:WEB:REV=9',now)~seal
a2=.SecurityMethodActionFactory~createInvocation('METHOD-PERM-INV-2',subject,objectId,objectClass,method,inv2,now,'HIGH','PURCHASE_MORE_BAGS')~value~seal
assessment2=.SecurityEffectEngine~new~evaluate(a2,snap,secPolicy)~value
guard3=.SecurityInvocationGuard~new
prep2=bridge~permissionRequestForInvocation('PERM-INV-2',assessment2,inv2,invPolicy,guard3,now+.SecurityCanonical~timeSpanSeconds(5))~value
denied=authority~decide(prep2~request,denyPolicy)
call assertTrue denied~ok,'deny policy evaluates'
call assertTrue \denied~value~decision~allowed,'Permission denies independently of Security ALLOW'
notCommitted=prep2~commitIfAllowed(denied)
call assertTrue \notCommitted~ok,'denied Permission is not consumed as successful invocation'
call assertEqual 'PERMISSION_DENIED',notCommitted~code,'permission denial remains explicit'
call assertTrue \guard3~used(prep2~binding),'denied method does not burn invocation evidence'
allowedRetry=authority~decide(prep2~request,permPolicy)
call assertTrue allowedRetry~value~decision~allowed,'same fresh request can be evaluated by correct Permission authority'
call assertTrue prep2~commitIfAllowed(allowedRetry)~ok,'successful permission path then consumes binding'
/* Stale Security evidence is stopped before Access Permissions evaluates it. */
inv3=.SecurityInvocationEvidence~new('INV-PERM-3','ORDER:QTY=1:TOTAL=5000','SESSION:BARBIE:WEB:REV=9',now)~seal
a3=.SecurityMethodActionFactory~createInvocation('METHOD-PERM-INV-3',subject,objectId,objectClass,method,inv3,now,'HIGH','PURCHASE_MORE_BAGS')~value~seal
assessment3=.SecurityEffectEngine~new~evaluate(a3,snap,secPolicy)~value
expired=bridge~permissionRequestForInvocation('PERM-INV-3',assessment3,inv3,invPolicy,.SecurityInvocationGuard~new,now+.SecurityCanonical~timeSpanSeconds(31))
call assertTrue \expired~ok,'stale Security binding rejected before Permission evaluation'
call assertEqual 'SECURITY_INVOCATION_EXPIRED',expired~code,'stale failure explicit'
say 'PASS test_access_permissions_invocation_freshness'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'SecurityEffect.cls'
::requires 'SecurityAccessPermissionsBridge.cls'
