svc=.FBStaffWireFakeService~new
ignore=svc~seedWork("A","COMPLETED",125000)
ignore=svc~seedWork("B","APPROVAL_REQUIRED",900000)
app=.FBStaffWireTestFixtures~app(svc)
.FBStaffWireTestSupport~assertEq(2,app~view~instance("summary")["slots"]["total"])
.FBStaffWireTestSupport~assertEq(1,app~view~instance("summary")["slots"]["approvalRequired"])
.FBStaffWireTestSupport~assertEq("APPROVAL_REQUIRED",app~view~instance("WORK:B")["slots"]["state"])
.FBStaffWireTestSupport~assertTrue(app~view~instance("WORK:B")["slots"]["checkerRequired"])

/* Browser cannot select a work id outside the current server query. */
d=.directory~new; d["selectedIds"]=.array~of("WORK:BOGUS"); d["scopeRevision"]=app~workspaceQuery("FB.STAFF.WORK")~scopeRevision
r=app~receive(.FBStaffWireTestFixtures~action(app,"work-query","WORK.SELECT",d,.nil,"MSG-FORGE"))
.FBStaffWireTestSupport~assertFalse(r~ok,"forged work selection rejected")
.FBStaffWireTestSupport~assertEq("FB_STAFF_SELECTION_OUT_OF_SCOPE",r~code)

.FBStaffWireTestSupport~ok(.FBStaffWireTestFixtures~selectWork(app,"WORK:B"))
old=app~workspaceContext("FB.STAFF.WORK")
/* Publishing a fresh result makes the old context stale even if selection is unchanged. */
r=app~receive(.FBStaffWireTestFixtures~action(app,"work-query","WORK.REFRESH",.directory~new,.nil,"MSG-REFRESH"))
.FBStaffWireTestSupport~assertTrue(r~ok)
d=.directory~new; d["workId"]="WORK:B"
r=app~receive(.FBStaffWireTestFixtures~action(app,"WORK:B","WORK.OPEN",d,old,"MSG-OLD"))
.FBStaffWireTestSupport~assertFalse(r~ok,"stale result revision rejected")
.FBStaffWireTestSupport~assertEq("WORKSPACE_RESULT_REVISION_MISMATCH",r~code)

ctx=app~workspaceContext("FB.STAFF.WORK")
r=app~receive(.FBStaffWireTestFixtures~action(app,"WORK:B","WORK.OPEN",d,ctx,"MSG-OPEN"))
.FBStaffWireTestSupport~assertTrue(r~ok)
.FBStaffWireTestSupport~assertEq("WORK:B",app~view~instance("work-detail")["slots"]["workId"])
.FBStaffWireTestSupport~assertEq("CUSTOMER",app~view~instance("work-detail")["slots"]["authorityScope"])
say "PASS Staff Banking worklist uses server scope and v0.17 result-revision authority"
exit 0
::requires "TestSupport.cls"
