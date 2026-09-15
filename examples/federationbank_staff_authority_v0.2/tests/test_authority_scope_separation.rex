e=.FBStaffTestSupport~engine
ctx=.FBStaffTestSupport~context("RID-STAFF-17","INTERMEDIARY_REPRESENTATIVE","S-RID-17")
contexts=.FBStaffTestSupport~contexts(ctx)

a=.FBStaffTestSupport~action("A-RID-ADVISE","RID-STAFF-17","S-RID-17",0,"DOUGLAS","DESK-04","INTERMEDIARY_ADVISE","GBP","INSTITUTIONAL")
r=e~authorise("ENV-RID-ADVISE",a,contexts)
.FBStaffTestSupport~assertTrue(r~ok,"institutional intermediary staff action is authorised by institutional rule")
.FBStaffTestSupport~assertEq("INSTITUTIONAL",r~value["decision"]~authorityScope,"decision scope")
.FBStaffTestSupport~assertEq("INSTITUTIONAL",r~value["envelope"]~authorityScope,"envelope scope")
.FBStaffTestSupport~assertEq("INTERMEDIARY-ADVISE",r~value["decision"]~ruleId,"institutional rule")

/* The same employee role does not obtain customer banking authority for the
 * intermediary operation merely because the operation name is the same. */
customerScoped=.FBStaffTestSupport~action("A-RID-WRONG-SCOPE","RID-STAFF-17","S-RID-17",0,"DOUGLAS","DESK-04","INTERMEDIARY_ADVISE","GBP","CUSTOMER")
wrong=e~authorise("ENV-RID-WRONG",customerScoped,contexts)
.FBStaffTestSupport~assertFalse(wrong~ok,"customer scope cannot consume institutional rule")
.FBStaffTestSupport~assertEq("STAFF_POLICY_NO_RULE_FOR_EFFECTIVE_ROLE",wrong~code,"scope-separated rule resolution")

/* Even a positive INSTITUTIONAL envelope can never be rebound as an ordinary
 * Core Banking STAFF command. */
cmd=.FederationBankCommand~new(a~commandId,a~operation,a~idempotencyKey,a~customerId,a~sourceAccountId,a~targetAccountId,a~currency,a~amountMinor,"STAFF",a~staffId,a~requestedAt)
b=.FederationBankStaffCommandBinder~bind(a,r~value["envelope"],cmd)
.FBStaffTestSupport~assertFalse(b~ok,"institutional authority is not core banking authority")
.FBStaffTestSupport~assertEq("STAFF_AUTHORITY_SCOPE_NOT_CORE_BANKING",b~code,"core binder scope guard")
.FBStaffTestSupport~pass("customer and institutional staff authority scopes remain disjoint")
::requires "TestSupport.cls"
