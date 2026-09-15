fx = .RIDWorkIntegrationFixtures~setup("INSURANCE", "ALL_JAPAN_INSURANCE_CO_LTD", "ALL_JAPAN_POLICY_ADMIN", "HOME", "AJI-HOME|2026.08|SEM")
quoted = .RIDWorkIntegrationFixtures~providerStatus(fx, "AJI-QUOTE-EVT-40", 40, "QUOTED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, quoted))
signTask = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("SIGNATURE", signTask~completionMode)
.RIDTestSupport~assertEq("PRESENT_INSURANCE_QUOTE_AND_SIGN", signTask~workType)
ignore = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")

/* Provider truth is not falsified: BOUND is accepted. But an unsigned completion
   becomes a critical intermediary/compliance exception instead of disappearing. */
bound = .RIDWorkIntegrationFixtures~providerStatus(fx, "AJI-BOUND-EVT-41", 41, "BOUND")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, bound))
exception = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("BOUND", fx["CASE"]~providerStatus)
.RIDTestSupport~assertEq("SUPERSEDED", signTask~status)
.RIDTestSupport~assertEq("REVIEW_UNSIGNED_PROVIDER_COMPLETION", exception~workType)
.RIDTestSupport~assertEq("EXCEPTION_REVIEW", exception~completionMode)
.RIDTestSupport~assertEq(100, exception~priority)
attention = fx["MANAGER"]~get(fx["SERVICE"]~wireAttentionQueue, "RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("BOUND", attention["provider_status"])
.RIDTestSupport~assertEq("ACTION_REQUIRED", attention["attention_state"])
.RIDTestSupport~assertEq("REVIEW_UNSIGNED_PROVIDER_COMPLETION", attention["next_action"])

.RIDTestSupport~ok(fx["SERVICE"]~completeWork(exception~workItemId, "COMPLIANCE:REVIEW:UNSIGNED-BOUND-41"))
.RIDTestSupport~assertEq("COMPLETE", exception~status)

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS terminal provider state with missing digital signature becomes explicit compliance work"
exit 0
::requires "WorkTestSupport.cls"
