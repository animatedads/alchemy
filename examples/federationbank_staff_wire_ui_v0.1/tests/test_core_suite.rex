cat=.FBStaffWireTestFixtures~catalogue
.FBStaffWireTestSupport~assertEq(7,cat~definitions~items,"seven definitions")
say "PASS 1/5 Staff Banking Wire UI release compiles once"

/* Workspace/result authority. */
svc=.FBStaffWireFakeService~new
ignore=svc~seedWork("A","COMPLETED",125000)
ignore=svc~seedWork("B","APPROVAL_REQUIRED",900000)
app=.FBStaffWireTestFixtures~app(svc,.nil,"TELLER-04","S-TEL","DOUGLAS","DESK-04",cat)
.FBStaffWireTestSupport~assertEq(2,app~view~instance("summary")["slots"]["total"])
.FBStaffWireTestSupport~assertEq(1,app~view~instance("summary")["slots"]["approvalRequired"])
d=.directory~new; d["selectedIds"]=.array~of("WORK:BOGUS"); d["scopeRevision"]=app~workspaceQuery("FB.STAFF.WORK")~scopeRevision
r=app~receive(.FBStaffWireTestFixtures~action(app,"work-query","WORK.SELECT",d,.nil,"CORE-FORGE"))
.FBStaffWireTestSupport~assertFalse(r~ok); .FBStaffWireTestSupport~assertEq("FB_STAFF_SELECTION_OUT_OF_SCOPE",r~code)
.FBStaffWireTestSupport~ok(.FBStaffWireTestFixtures~selectWork(app,"WORK:B","CORE-SELECT"))
old=app~workspaceContext("FB.STAFF.WORK")
r=app~receive(.FBStaffWireTestFixtures~action(app,"work-query","WORK.REFRESH",.directory~new,.nil,"CORE-REFRESH")); .FBStaffWireTestSupport~assertTrue(r~ok)
d=.directory~new; d["workId"]="WORK:B"
r=app~receive(.FBStaffWireTestFixtures~action(app,"WORK:B","WORK.OPEN",d,old,"CORE-OLD")); .FBStaffWireTestSupport~assertFalse(r~ok); .FBStaffWireTestSupport~assertEq("WORKSPACE_RESULT_REVISION_MISMATCH",r~code)
ctx=app~workspaceContext("FB.STAFF.WORK")
r=app~receive(.FBStaffWireTestFixtures~action(app,"WORK:B","WORK.OPEN",d,ctx,"CORE-OPEN")); .FBStaffWireTestSupport~assertTrue(r~ok)
.FBStaffWireTestSupport~assertEq("WORK:B",app~view~instance("work-detail")["slots"]["workId"])
say "PASS 2/5 server scope and v0.17 result-revision authority"

/* Method permission is independent and browser identity cannot override server identity. */
svc=.FBStaffWireFakeService~new
app=.FBStaffWireTestFixtures~app(svc,.FBStaffWireDenyPermissionPort~new,"TELLER-04","S-TEL","DOUGLAS","DESK-04",cat)
r=app~receive(.FBStaffWireTestFixtures~action(app,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",.FBStaffWireTestFixtures~transferDetail,.nil,"CORE-DENY"))
.FBStaffWireTestSupport~assertFalse(r~ok); .FBStaffWireTestSupport~assertEq("FB_STAFF_METHOD_PERMISSION_REQUIRED",r~code); .FBStaffWireTestSupport~assertEq(0,svc~state~works~items)
svc2=.FBStaffWireFakeService~new; perm=.FBStaffWireAllowPermissionPort~new("TELLER-04","S-TEL")
app2=.FBStaffWireTestFixtures~app(svc2,perm,"TELLER-04","S-TEL","DOUGLAS","DESK-04",cat)
d=.FBStaffWireTestFixtures~transferDetail(175000); d["staffId"]="ATTACKER"; d["sessionId"]="OTHER"; d["branchId"]="OTHER"; d["operation"]="OPEN_ACCOUNT"
r=app2~receive(.FBStaffWireTestFixtures~action(app2,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"CORE-ALLOW")); .FBStaffWireTestSupport~assertTrue(r~ok)
env=svc2~lastEnvelope; req=env~payload["request"]
.FBStaffWireTestSupport~assertEq("TELLER-04",req~staffId); .FBStaffWireTestSupport~assertEq("S-TEL",req~sessionId); .FBStaffWireTestSupport~assertEq("DOUGLAS",req~branchId); .FBStaffWireTestSupport~assertEq("TRANSFER",req~command~operation); .FBStaffWireTestSupport~assertEq("STAFF",req~command~channel)
say "PASS 3/5 exact method permission plus server-owned banking identity"

/* Action binding, validation and replay/idempotency. */
svc3=.FBStaffWireFakeService~new; perm3=.FBStaffWireAllowPermissionPort~new
app3=.FBStaffWireTestFixtures~app(svc3,perm3,"TELLER-04","S-TEL","DOUGLAS","DESK-04",cat)
r=app3~receive(.FBStaffWireTestFixtures~action(app3,"customer-transfer","CORE.EXECUTE",.directory~new,.nil,"CORE-BAD-ACTION")); .FBStaffWireTestSupport~assertFalse(r~ok); .FBStaffWireTestSupport~assertEq("ACTION_NOT_BOUND_TO_ELEMENT",r~code); .FBStaffWireTestSupport~assertEq(0,perm3~calls)
d=.FBStaffWireTestFixtures~transferDetail; d["amountMinor"]="NOT-A-NUMBER"
r=app3~receive(.FBStaffWireTestFixtures~action(app3,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"CORE-BAD-AMOUNT")); .FBStaffWireTestSupport~assertFalse(r~ok); .FBStaffWireTestSupport~assertEq("FB_STAFF_TRANSFER_AMOUNT_INVALID",r~code); .FBStaffWireTestSupport~assertEq(0,perm3~calls)
d=.FBStaffWireTestFixtures~transferDetail; m=.FBStaffWireTestFixtures~action(app3,"customer-transfer","CUSTOMER.TRANSFER.SUBMIT",d,.nil,"CORE-DUP")
r1=app3~receive(m); r2=app3~receive(m); .FBStaffWireTestSupport~assertTrue(r1~ok); .FBStaffWireTestSupport~assertTrue(r2~ok); .FBStaffWireTestSupport~assertEq("DUPLICATE",r2~code); .FBStaffWireTestSupport~assertEq(1,perm3~calls); .FBStaffWireTestSupport~assertEq(1,svc3~state~works~items)
say "PASS 4/5 fail-closed binding/validation and idempotent UI receipt"

/* Actual ooRexx Security Manager path. */
agent=value("STAFF_METHOD_PERMISSION_AGENT",,"ENVIRONMENT")
if agent="" then do; say "FAIL STAFF_METHOD_PERMISSION_AGENT not set"; exit 2; end
fx=.FBStaffWireRealPermissionFixture~build
port=.FederationBankStaffWireMethodPermissionBoundaryPort~new(fx["boundary"],fx["ingress"],agent)
r=port~admit("FB-STAFF-WIRE-TRANSFER/1|CORE-SUITE"); .FBStaffWireTestSupport~assertTrue(r~ok)
a=r~value
.FBStaffWireTestSupport~assertEq("TELLER-04",a~staffId); .FBStaffWireTestSupport~assertEq("S-TEL",a~sessionId); .FBStaffWireTestSupport~assertEq("ADMIT",a~methodName)
.FBStaffWireTestSupport~assertFalse(a~businessAuthorityImplied); .FBStaffWireTestSupport~assertFalse(a~accessControlImplied); .FBStaffWireTestSupport~assertFalse(a~authenticationImplied)
say "PASS 5/5 actual r13196 Security Manager permission boundary"
say "FEDERATIONBANK STAFF WIRE UI CORE: PASS 5/5"
exit 0
::requires "TestSupport.cls"
