clock = .RIDManualTimeSource~new(1000000)
p = .RIDWorkPolicy~new
.RIDTestSupport~ok(p~addRule(.RIDWorkRule~new("SHORT-APPROVAL", "MORTGAGE", "APPROVED", "REVIEW_FAST_APPROVAL", "INTERMEDIARY", 99, 5, "ACK")))
.RIDTestSupport~ok(p~seal)
fx = .RIDWorkIntegrationFixtures~setup("MORTGAGE", "FEDERATIONBANK_PLC", "FEDERATION_MORTGAGE", "HOME-1", "HOME-1|2026.08|A", clock, p)
approved = .RIDWorkIntegrationFixtures~providerStatus(fx, "MTG-SLA-1", 1, "APPROVED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, approved))
item = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("OPEN", item~status)
.RIDTestSupport~assertEq(1, fx["MANAGER"]~depth(fx["SERVICE"]~slaQueue, "RID_ADMIN")~value["ready"])

/* consume initial attention so the next one is specifically the SLA transition */
ignore = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")
ignore = clock~advance(6)
sweep = fx["MANAGER"]~sweepExpired(fx["SERVICE"]~slaQueue, "RID_ADMIN")
.RIDTestSupport~assertTrue(sweep~ok)
.RIDTestSupport~assertEq("OVERDUE", item~status, "Queue Fabric TTL trigger must drive overdue projection")
.RIDTestSupport~assertEq(1, fx["MANAGER"]~depth(fx["SERVICE"]~overdueQueue, "RID_ADMIN")~value["ready"])
attention = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("APPROVED", attention["provider_status"])
.RIDTestSupport~assertEq("OVERDUE", attention["attention_state"])
.RIDTestSupport~assertEq("REVIEW_FAST_APPROVAL", attention["next_action"])
.RIDTestSupport~assertEq("1", attention["overdue"])

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS Queue Fabric TTL expiry drives overdue intermediary work"
exit 0

::requires "WorkTestSupport.cls"
