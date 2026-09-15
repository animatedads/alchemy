now=.DateTime~new
subject='STAFF:BOB'
policy=.SecurityPolicyFramework~new('METHOD-SECURITY','1',now-.TimeSpan~new(0,0,0,1,0),.nil,'SECURITY','RISK')~seal
ar=.SecurityMethodActionFactory~create('METHOD-A1',subject,'OBJECT:PAYMENT:42','PaymentAccount','releasePayment',now,'HIGH','PAYMENT_RELEASE')
call assertTrue ar~ok,'typed method action created'
a=ar~value; a~seal
call assertEqual 'METHOD_INVOCATION',a~actionType,'method action type fixed'
call assertEqual 'OBJECT:PAYMENT:42',a~attribute('OBJECT_ID'),'exact object retained'
call assertEqual 'PAYMENTACCOUNT',a~attribute('OBJECT_CLASS'),'class normalized'
call assertEqual 'RELEASEPAYMENT',a~attribute('METHOD'),'method normalized'
assessment=.SecurityEffectEngine~new~evaluate(a,.SecuritySnapshot~new('SNAP-METHOD',subject,now)~seal,policy)~value
call assertEqual 'ALLOW',assessment~disposition,'baseline assessment allow'
br=.SecurityPermissionBindingFactory~fromAssessment(assessment)
call assertTrue br~ok,'permission binding created'
b=br~value
call assertEqual subject,b~subjectId,'subject exact'
call assertEqual 'OBJECT:PAYMENT:42',b~objectId,'object exact'
call assertEqual 'PAYMENTACCOUNT',b~objectClass,'class exact'
call assertEqual 'RELEASEPAYMENT',b~methodName,'method exact'
call assertEqual assessment~policy~semanticIdentity,b~securityPolicyIdentity,'policy identity exact'
call assertEqual assessment~trace~traceIdentity,b~securityTraceIdentity,'trace identity exact'
other=.SecurityActionSurface~new('A-NOT-METHOD',subject,'VIEW_BOOKING',now)~seal
otherAssessment=.SecurityEffectEngine~new~evaluate(other,.SecuritySnapshot~new('S2',subject,now)~seal,policy)~value
bad=.SecurityPermissionBindingFactory~fromAssessment(otherAssessment)
call assertTrue bad~ok=.false,'non-method assessment cannot become permission binding'
call assertEqual 'SECURITY_ACTION_NOT_METHOD_INVOCATION',bad~code,'failure is explicit'
say 'PASS test_method_permission_binding'
exit 0
assertTrue: procedure; use arg v,l; if v=.false then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'SecurityEffect.cls'
