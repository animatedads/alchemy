fx = .RIDWorkIntegrationFixtures~setup("INSURANCE", "ALL_JAPAN_INSURANCE_CO_LTD", "ALL_JAPAN_POLICY_ADMIN", "HOME", "AJI-HOME|2026.08|SEM")
approved = .RIDWorkIntegrationFixtures~providerStatus(fx, "AJI-STATUS-20", 20, "APPROVED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, approved))
first = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("REVIEW_INSURANCE_APPROVAL", first~workType)

/* discard first attention publication */
ignore = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")

declined = .RIDWorkIntegrationFixtures~providerStatus(fx, "AJI-STATUS-21", 21, "DECLINED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, declined))
second = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("SUPERSEDED", first~status, "new provider state must supersede stale broker action")
.RIDTestSupport~assertEq("REVIEW_INSURANCE_DECLINE", second~workType)
.RIDTestSupport~assertEq("OPEN", second~status)

attention = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("DECLINED", attention["provider_status"])
.RIDTestSupport~assertEq("REVIEW_INSURANCE_DECLINE", attention["next_action"])
.RIDTestSupport~assertEq(second~workItemId, attention["work_item_id"])

/* Late provider event never republishes case status, therefore creates no work. */
late = .RIDWorkIntegrationFixtures~providerStatus(fx, "AJI-STATUS-19", 19, "UNDERWRITING")
.RIDTestSupport~ok(fx["BRIDGE"]~enqueueProviderStatus(fx["CASE"]~caseId, late))
.RIDTestSupport~ok(fx["BRIDGE"]~canonicalizeOne)
lr = fx["BRIDGE"]~projectOne
.RIDTestSupport~assertTrue(lr~ok)
.RIDTestSupport~assertEq("STALE_IGNORED", lr~detail)
empty = fx["SERVICE"]~processStatusOne
.RIDTestSupport~assertTrue(\empty~ok)
.RIDTestSupport~assertEq("QUEUE_EMPTY", empty~code)
.RIDTestSupport~assertEq("DECLINED", fx["CASE"]~providerStatus)

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS decline supersedes approval work and late events create no stale work"
exit 0

::requires "WorkTestSupport.cls"
