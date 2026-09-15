fx=.RIDWireUITestFixtures~setup("APPROVED")
app=.RIDWireUITestFixtures~app(fx)
row=app~view~instance("CASE-W")
.RIDTestSupport~assertTrue(row<>.nil,"case row projected")
.RIDTestSupport~assertEq("APPROVED",row["slots"]["providerStatus"],"actual provider state visible")
.RIDTestSupport~assertEq("ACTION_REQUIRED",row["slots"]["attentionState"])
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_APPROVAL",row["slots"]["nextAction"])

/* forged semantic selection never becomes command authority */
d=.directory~new; d["selectedIds"]=.array~of("CASE-BOGUS"); d["scopeRevision"]=app~workspaceQuery("RID.CASES")~scopeRevision
r=app~receive(.RIDWireUITestFixtures~action(app,"case-query","CASES.SELECT",d))
.RIDTestSupport~assertTrue(\r~ok,"forged case rejected")
.RIDTestSupport~assertEq("RID_SELECTION_OUT_OF_SCOPE",r~code)

.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))
old=app~workspaceContext("RID.CASES")
/* change authoritative order without changing the current view revision */
.RIDTestSupport~ok(app~setWorkspaceSort("RID.CASES","CASE_ID","ASC"))
d=.directory~new; d["caseId"]="CASE-W"
r=app~receive(.RIDWireUITestFixtures~action(app,"CASE-W","CASE.OPEN",d,old))
.RIDTestSupport~assertTrue(\r~ok,"stale workspace context rejected")
.RIDTestSupport~assertEq("WORKSPACE_QUERY_REVISION_MISMATCH",r~code)

/* Wire UI v0.17: query movement invalidates the authoritative result until republished. */
ctx=app~workspaceContext("RID.CASES")
r=app~receive(.RIDWireUITestFixtures~action(app,"CASE-W","CASE.OPEN",d,ctx))
.RIDTestSupport~assertTrue(\r~ok,"unrefreshed workspace result rejected")
.RIDTestSupport~assertEq("WORKSPACE_RESULT_NOT_CURRENT",r~code)
.RIDTestSupport~ok(app~refreshDashboard)
ctx=app~workspaceContext("RID.CASES")
r=app~receive(.RIDWireUITestFixtures~action(app,"CASE-W","CASE.OPEN",d,ctx))
.RIDTestSupport~assertTrue(r~ok,"refreshed exact result context opens case")
.RIDTestSupport~assertEq("APPROVED",app~view~instance("case-detail")["slots"]["providerStatus"])
.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS Wire UI dashboard carries provider truth and rejects forged/stale workspace authority"
exit 0
::requires "WireUITestSupport.cls"
