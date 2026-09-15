now=.DateTime~new
subject='STAFF:BOB'
objectId='OBJECT:PAYMENT:42'
objectClass='PAYMENTACCOUNT'
method='RELEASEPAYMENT'
allowFramework=.SecurityPolicyFramework~new('METHOD-SECURITY','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')~seal
snap=.SecuritySnapshot~new('SNAP-ALLOW',subject,now)~seal
a=.SecurityMethodActionFactory~create('METHOD-ALLOW',subject,objectId,objectClass,method,now,'HIGH','PAYMENT_RELEASE')~value; a~seal
allowAssessment=.SecurityEffectEngine~new~evaluate(a,snap,allowFramework)~value
call assertEqual 'ALLOW',allowAssessment~disposition,'Security Effect allows method semantics'
bridge=.SecurityAccessPermissionsBridge~new
reqResult=bridge~permissionRequest('PERM-ALLOW',allowAssessment)
call assertTrue reqResult~ok,'typed Security assessment becomes permission request'
request=reqResult~value
/* Security ALLOW is evidence, never authority: empty permission policy defaults DENY. */
emptyPolicy=.PermissionPolicy~new('METHOD-PERM','1','DENY',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')~seal
emptyDecision=.PermissionAuthority~new~decide(request,emptyPolicy)
call assertTrue emptyDecision~ok,'empty permission policy evaluates'
call assertTrue emptyDecision~value~decision~allowed=.false,'Security ALLOW alone grants no method authority'
/* Exact Permission rule plus Security ALLOW permits this one method/object. */
permPolicy=.PermissionPolicy~new('METHOD-PERM','2','DENY',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
permPolicy~addRule(.PermissionRule~new('ALLOW-EXACT',100,'ALLOW',subject,objectId,objectClass,method,'ALLOW','*','')~seal)
permPolicy~seal
permitted=.PermissionAuthority~new~decide(request,permPolicy)
call assertTrue permitted~value~decision~allowed,'exact Permission + Security ALLOW permits method'
call assertEqual allowAssessment~policy~semanticIdentity,permitted~value~decision~securityPolicyIdentity,'permission receipt binds exact Security policy'
/* Same permission cannot override Security HOLD. */
holdRule=.SecurityPolicyRule~new('HOLD-RELEASE',100,'METHOD_INVOCATION','HOLD','high consequence release held')
holdRule~addCriterion('METHOD','EQ',method)
holdRule~addConstraint('OUT_OF_BAND_CONFIRMATION','ACTION','hold before release')
holdRule~seal
holdFramework=.SecurityPolicyFramework~new('METHOD-SECURITY','2',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')
holdFramework~addRule(holdRule); holdFramework~seal
holdAssessment=.SecurityEffectEngine~new~evaluate(a,snap,holdFramework)~value
call assertEqual 'HOLD',holdAssessment~disposition,'Bouncer holds same exact method'
holdRequest=bridge~permissionRequest('PERM-HOLD',holdAssessment)~value
held=.PermissionAuthority~new~decide(holdRequest,permPolicy)
call assertTrue held~value~decision~allowed=.false,'Permission ALLOW cannot erase Security HOLD'
/* A different object is not covered by exact object authority. */
a2=.SecurityMethodActionFactory~create('METHOD-OTHER',subject,'OBJECT:PAYMENT:43',objectClass,method,now,'HIGH','PAYMENT_RELEASE')~value; a2~seal
assessment2=.SecurityEffectEngine~new~evaluate(a2,snap,allowFramework)~value
request2=bridge~permissionRequest('PERM-OTHER',assessment2)~value
other=.PermissionAuthority~new~decide(request2,permPolicy)
call assertTrue other~value~decision~allowed=.false,'permission does not float across object identity'
say 'PASS test_access_permissions_integration'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'SecurityEffect.cls'
::requires 'SecurityAccessPermissionsBridge.cls'
