e=.FBStaffTestSupport~engine
ctx=.FBStaffTestSupport~context("TELLER-04","TELLER","S-1","DOUGLAS","DESK-04")
a=.FBStaffTestSupport~action("A-BR","TELLER-04","S-1",100000,"RAMSEY","DESK-04")
r=e~decide(a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertFalse(r~ok,"wrong branch denied")
.FBStaffTestSupport~assertEq("STAFF_WORK_CONTEXT_MISMATCH",r~code,"work context failure")
a=.FBStaffTestSupport~action("A-SESS","TELLER-04","OTHER",100000,"DOUGLAS","DESK-04")
r=e~decide(a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertFalse(r~ok,"wrong session denied")
.FBStaffTestSupport~assertEq("STAFF_SESSION_MISMATCH",r~code,"session identity bound")
.FBStaffTestSupport~pass("branch/desk/session context is authority evidence")
::requires "TestSupport.cls"
