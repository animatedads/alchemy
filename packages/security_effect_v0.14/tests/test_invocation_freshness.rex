now=.DateTime~new
subject='CUSTOMER:BARBIE'
objectId='OBJECT:BAG-ORDER:42'
objectClass='BAGORDERSERVICE'
method='PURCHASEMOREBAGS'
policy=.SecurityPolicyFramework~new('METHOD-SECURITY','1',now-.SecurityCanonical~timeSpanSeconds(60),.nil,'SECURITY','RISK')~seal
invPolicy=.SecurityInvocationPolicy~new('METHOD-FRESHNESS','1',30,5,.true,.true,.true,'SECURITY','RISK')~seal
inv=.SecurityInvocationEvidence~new('INV-100','ORDER:MORE-BAGS:QTY=4:TOTAL=20000','SESSION:BARBIE:WEB:REV=9',now)~seal
ar=.SecurityMethodActionFactory~createInvocation('METHOD-INV-1',subject,objectId,objectClass,method,inv,now,'HIGH','PURCHASE_MORE_BAGS')
call assertTrue ar~ok,'invocation-bound method action created'
a=ar~value~seal
snap=.SecuritySnapshot~new('SNAP-INV-1',subject,now)~seal
assessment=.SecurityEffectEngine~new~evaluate(a,snap,policy)~value
br=.SecurityPermissionBindingFactory~fromInvocationAssessment(assessment)
call assertTrue br~ok,'invocation-bound permission evidence created'
b=br~value
call assertTrue b~invocationBound,'binding declares invocation evidence'
call assertEqual inv~semanticIdentity,b~invocationEvidenceIdentity,'exact invocation evidence identity retained'
call assertEqual inv~argumentIdentity,b~argumentIdentity,'argument identity retained'
call assertEqual inv~contextIdentity,b~contextIdentity,'context identity retained'
call assertEqual a~canonicalText,b~actionIdentity,'full action identity retained'
call assertEqual snap~semanticIdentity,b~snapshotIdentity,'full snapshot identity retained'
call assertContains assessment~trace~canonicalText,'ACTION_IDENTITY=','trace binds full action identity'
call assertContains assessment~trace~canonicalText,'SNAPSHOT_IDENTITY=','trace binds full snapshot identity'
guard=.SecurityInvocationGuard~new
v=guard~validate(b,inv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(10))
call assertTrue v~ok,'fresh exact invocation validates'
/* Same invocation id with altered arguments is different sealed evidence and must fail. */
changedArgs=.SecurityInvocationEvidence~new('INV-100','ORDER:MORE-BAGS:QTY=400:TOTAL=2000000',inv~contextIdentity,now)~seal
bad=guard~validate(b,changedArgs,invPolicy,now+.SecurityCanonical~timeSpanSeconds(10))
call assertTrue \bad~ok,'argument substitution rejected'
call assertEqual 'SECURITY_INVOCATION_EVIDENCE_MISMATCH',bad~code,'argument mismatch fails at exact evidence identity'
/* Same arguments but a changed session / workspace context is equally distinct. */
changedContext=.SecurityInvocationEvidence~new('INV-100',inv~argumentIdentity,'SESSION:BARBIE:WEB:REV=10',now)~seal
bad=guard~validate(b,changedContext,invPolicy,now+.SecurityCanonical~timeSpanSeconds(10))
call assertTrue \bad~ok,'context substitution rejected'
call assertEqual 'SECURITY_INVOCATION_EVIDENCE_MISMATCH',bad~code,'context mismatch fails at exact evidence identity'
/* Expiry is based on evidence observation time, not on when someone asks again. */
expired=guard~validate(b,inv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(31))
call assertTrue \expired~ok,'stale Security assessment cannot be revived'
call assertEqual 'SECURITY_INVOCATION_EXPIRED',expired~code,'expiry explicit'
/* A successful authorization path may consume a single-use binding. */
valid=guard~validate(b,inv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(5))
call assertTrue valid~ok,'fresh validation before consume'
used=guard~consume(valid~value)
call assertTrue used~ok,'binding consumed'
replay=guard~validate(b,inv,invPolicy,now+.SecurityCanonical~timeSpanSeconds(6))
call assertTrue \replay~ok,'consumed binding cannot be replayed'
call assertEqual 'SECURITY_INVOCATION_ALREADY_USED',replay~code,'replay failure explicit'
/* Even the same action id generates a different Security trace when arguments differ. */
inv2=.SecurityInvocationEvidence~new('INV-101','ORDER:MORE-BAGS:QTY=1:TOTAL=5000',inv~contextIdentity,now)~seal
a2=.SecurityMethodActionFactory~createInvocation('METHOD-INV-1',subject,objectId,objectClass,method,inv2,now,'HIGH','PURCHASE_MORE_BAGS')~value~seal
assessment2=.SecurityEffectEngine~new~evaluate(a2,snap,policy)~value
call assertTrue assessment~trace~traceIdentity<>assessment2~trace~traceIdentity,'trace changes when invocation arguments change'
say 'PASS test_invocation_freshness'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg hay,needle,l; if hay~pos(needle)=0 then do; say 'FAIL:' l 'missing='needle; exit 1; end; return
::requires 'SecurityEffect.cls'
