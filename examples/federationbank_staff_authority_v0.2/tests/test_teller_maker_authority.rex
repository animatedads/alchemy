e=.FBStaffTestSupport~engine
ctx=.FBStaffTestSupport~context("TELLER-04","TELLER","S-T4")
a=.FBStaffTestSupport~action("A-LOW","TELLER-04","S-T4",250000)
r=e~authorise("ENV-LOW",a,.FBStaffTestSupport~contexts(ctx))
.FBStaffTestSupport~assertTrue(r~ok,"under-limit teller action allowed")
.FBStaffTestSupport~assertEq("ALLOW",r~value["decision"]~outcome,"positive decision")
.FBStaffTestSupport~assertEq("TELLER-TRANSFER",r~value["decision"]~ruleId,"policy rule")
.FBStaffTestSupport~assertEq(0,r~value["decision"]~approvalIds~items,"no checker")
.FBStaffTestSupport~assertTrue(r~value["envelope"]~binds(a),"envelope exact action binding")
.FBStaffTestSupport~pass("teller maker authority is policy-bound")
::requires "TestSupport.cls"
