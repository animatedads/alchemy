d=.FBIntermediaryStaffTestSupport~goodBundle
r=.FBIntermediaryStaffTestSupport~authoriseBundle(d)
.FBIntermediaryStaffTestSupport~assertTrue(r~ok,"active employee-to-RID representative binding authorises attribution")
.FBIntermediaryStaffTestSupport~assertTrue(r~value~binds(d["REQUEST"],d["ACTION"],d["CASE"],d["PRODUCT"]),"envelope binds exact request/action/case/product")
expired=.FBIntermediaryStaffTestSupport~repBinding("RID-STAFF-17","FIRM-1","REP-1",d["NOW"]-.TimeSpan~new(1,0),d["NOW"]-.TimeSpan~new(0,1))
d["BINDING"]=expired
x=.FBIntermediaryStaffTestSupport~authoriseBundle(d,"RID-STAFF-ENV-EXPIRED")
.FBIntermediaryStaffTestSupport~assertFalse(x~ok,"expired binding rejected")
.FBIntermediaryStaffTestSupport~assertEq("INTERMEDIARY_STAFF_BINDING_NOT_EFFECTIVE",x~code,"effective dating")
.FBIntermediaryStaffTestSupport~pass("employee to RID representative binding is effective-dated")
::requires "TestSupport.cls"
