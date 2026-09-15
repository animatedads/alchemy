/* A visible/enabled form does not bypass exact method permission. */
svc=.FBStaffWireFakeService~new
app=.FBStaffWireTestFixtures~app(svc,.FBStaffWireDenyPermissionPort~new)
r=app~receive(.FBStaffWireTestFixtures~action(app,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",.FBStaffWireTestFixtures~transferDetail,.nil,"TX-DENY"))
.FBStaffWireTestSupport~assertFalse(r~ok,"method permission deny blocks transfer")
.FBStaffWireTestSupport~assertEq("FB_STAFF_METHOD_PERMISSION_REQUIRED",r~code)
.FBStaffWireTestSupport~assertEq(0,svc~state~works~items,"no Staff Channel work created")

/* On allow, browser-supplied staff/session/operation fields are ignored. */
svc2=.FBStaffWireFakeService~new
perm=.FBStaffWireAllowPermissionPort~new("TELLER-04","S-TEL")
app2=.FBStaffWireTestFixtures~app(svc2,perm)
d=.FBStaffWireTestFixtures~transferDetail(175000); d["staffId"]="ATTACKER"; d["sessionId"]="OTHER"; d["branchId"]="OTHER"; d["operation"]="OPEN_ACCOUNT"
r=app2~receive(.FBStaffWireTestFixtures~action(app2,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"TX-ALLOW"))
.FBStaffWireTestSupport~assertTrue(r~ok,"admitted transfer reaches Staff Channel")
.FBStaffWireTestSupport~assertEq(1,perm~calls)
.FBStaffWireTestSupport~assertTrue(perm~lastPayload~pos("TRANSFER")>0,"permission payload binds server operation")
env=svc2~lastEnvelope; req=env~payload["request"]
.FBStaffWireTestSupport~assertEq("TELLER-04",req~staffId,"staff id is server-owned")
.FBStaffWireTestSupport~assertEq("S-TEL",req~sessionId,"channel session is server-owned")
.FBStaffWireTestSupport~assertEq("DOUGLAS",req~branchId,"branch is server-owned")
.FBStaffWireTestSupport~assertEq("TRANSFER",req~command~operation,"operation is fixed by semantic action")
.FBStaffWireTestSupport~assertEq("STAFF",req~command~channel,"Core command channel is server-owned")
.FBStaffWireTestSupport~assertEq(1,svc2~state~works~items)
.FBStaffWireTestSupport~assertEq(1,app2~view~instance("summary")["slots"]["received"])
say "PASS Staff Banking transfer requires method permission and preserves server-owned identity"
exit 0
::requires "TestSupport.cls"
