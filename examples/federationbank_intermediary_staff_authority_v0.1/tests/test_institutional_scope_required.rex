now=.DateTime~new
a=.FBIntermediaryStaffTestSupport~staffAction("CUST-ACT","TELLER-04","S-TELLER","TRANSFER","RID-CASE-1","CUSTOMER",now)
ctx=.FBIntermediaryStaffTestSupport~staffContext("TELLER-04","TELLER","S-TELLER")
auth=.FBIntermediaryStaffTestSupport~staffAuthority(a,ctx,"STAFF-CUSTOMER-ENV")
.FBIntermediaryStaffTestSupport~assertTrue(auth~ok,"customer staff authority fixture")
req=.FBIntermediaryStaffTestSupport~request(a,"ADVISE")
r=.FBIntermediaryStaffTestSupport~engine~authorise("RID-WRONG-SCOPE",req,a,auth~value["envelope"],.FBIntermediaryStaffTestSupport~repBinding("TELLER-04"),.FBIntermediaryStaffTestSupport~ridCase(,,,,,,now),.FBIntermediaryStaffTestSupport~product,.FBIntermediaryStaffTestSupport~ridRegistry)
.FBIntermediaryStaffTestSupport~assertFalse(r~ok,"customer staff authority cannot enter intermediary authority")
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_STAFF_SCOPE_REQUIRED",r~code,"institutional scope required")
.FBIntermediaryStaffTestSupport~pass("customer staff authority cannot masquerade as institutional intermediary authority")
::requires "TestSupport.cls"
