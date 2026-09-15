fx=.RIDWireUITestFixtures~setup("APPROVED")
app=.RIDWireUITestFixtures~app(fx)
.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))
old=app~workspaceContext("RID.CASES")
oldResult=old["resultRevision"]

/* Same query/scope/selection; only authoritative business result changes. */
signed=.RIDWorkIntegrationFixtures~providerStatus(fx,"WIRE-STATUS-2",2,"DECLINED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx,signed))
.RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~ok(app~refreshDashboard)
current=app~workspaceContext("RID.CASES")
.RIDTestSupport~assertEq(old["queryRevision"],current["queryRevision"],"query unchanged")
.RIDTestSupport~assertEq(old["scopeRevision"],current["scopeRevision"],"scope unchanged")
.RIDTestSupport~assertEq(old["selectionRevision"],current["selectionRevision"],"selection retained")
.RIDTestSupport~assertTrue(current["resultRevision"]>oldResult,"business result revision advances")

d=.directory~new; d["caseId"]="CASE-W"
r=app~receive(.RIDWireUITestFixtures~action(app,"CASE-W","CASE.OPEN",d,old))
.RIDTestSupport~assertTrue(\r~ok,"stale result context rejected")
.RIDTestSupport~assertEq("WORKSPACE_RESULT_REVISION_MISMATCH",r~code,"exact stale-result failure")
r=app~receive(.RIDWireUITestFixtures~action(app,"CASE-W","CASE.OPEN",d,current))
.RIDTestSupport~assertTrue(r~ok,"current result context accepted")
.RIDTestSupport~assertEq("DECLINED",app~view~instance("case-detail")["slots"]["providerStatus"],"provider truth remains exact")
.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS Wire UI result revision prevents action on refreshed provider/work truth"
::requires "WireUITestSupport.cls"
