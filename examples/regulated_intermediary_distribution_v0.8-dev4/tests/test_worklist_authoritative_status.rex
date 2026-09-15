fx = .RIDWorkIntegrationFixtures~setup("MORTGAGE")
approved = .RIDWorkIntegrationFixtures~providerStatus(fx, "MTG-STATUS-10", 10, "APPROVED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, approved))
wr = fx["SERVICE"]~processStatusOne
.RIDTestSupport~ok(wr)
item = wr~value
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_APPROVAL", item~workType)
.RIDTestSupport~assertEq("OPEN", item~status)
.RIDTestSupport~assertEq("APPROVED", item~providerStatus)

attention = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("regulated.intermediary.case-attention/1", attention["schema"])
.RIDTestSupport~assertEq("APPROVED", attention["provider_status"], "UI projection must show the actual provider state")
.RIDTestSupport~assertEq("ACTION_REQUIRED", attention["attention_state"])
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_APPROVAL", attention["next_action"])
.RIDTestSupport~assertEq("INTERMEDIARY", attention["waiting_on"])

work = fx["MANAGER"]~get(fx["SERVICE"]~wireWorkQueue, "RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("APPROVED", work["provider_status"])
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_APPROVAL", work["work_type"])

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS intermediary worklist carries authoritative mortgage status"
exit 0

::requires "WorkTestSupport.cls"
