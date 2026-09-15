fx=.RIDWireUITestFixtures~setup("APPROVED")
viewer=.RIDWireSecurityPolicyFixtures~context("VIEWER","RID:VIEWER:REP-1")
app=.RIDWireUITestFixtures~app(fx,.nil,.nil,viewer)
shell=app~view~instance("root")["slots"]
.RIDTestSupport~assertEq("VIEWER",shell["roleName"],"role is presentation context")
.RIDTestSupport~assertTrue(shell["accessDecisionRef"]<>"","coarse platform entry has cryptographic proof reference")
.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))
detail=app~view~instance("case-detail")["slots"]
.RIDTestSupport~assertTrue(\detail["canAcknowledge"],"viewer is not offered acknowledgement")

/* Even if a compromised renderer tries to re-enable the button, method/object permission still denies it. */
app~view~setActionAvailable("case-detail","WORK.ACK",.true)
d=.directory~new; d["caseId"]="CASE-W"; ctx=app~workspaceContext("RID.CASES")
r=app~receive(.RIDWireUITestFixtures~action(app,"case-detail","WORK.ACK",d,ctx))
.RIDTestSupport~assertTrue(\r~ok,"viewer acknowledgement denied by server permission")
.RIDTestSupport~assertEq("RID_PERMISSION_DENIED",r~code,"permission gate is independent of button availability")

/* Access Control is separately default-deny: valid role policy is not permission to enter. */
denied=.RIDWireSecurityPolicyFixtures~context("ADVISER","RID:ADVISER:DENIED",.false,.false)
r=.RIDWireRuntimeFactory~build("RID-DENIED","S-DENIED","WEB",fx["ENGINE"],fx["ENV"]["CATALOG"],fx["SERVICE"],fx["FEED"],.nil,.nil,"FIRM-1","REP-1",denied)
.RIDTestSupport~assertTrue(\r~ok,"coarse domain entry denied")
.RIDTestSupport~assertEq("RID_ACCESS_CONTROL_DENIED",r~code,"Access Control is separate from Permissions")
.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS Access Control and exact method/object Permissions gate intermediary Wire UI independently"
::requires "WireUITestSupport.cls"
