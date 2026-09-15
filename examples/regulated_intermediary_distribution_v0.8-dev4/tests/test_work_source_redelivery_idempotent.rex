fx = .RIDWorkIntegrationFixtures~setup("MORTGAGE")
approved = .RIDWorkIntegrationFixtures~providerStatus(fx, "MTG-WORK-IDEMP-1", 1, "APPROVED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, approved))
firstResult = fx["SERVICE"]~processStatusOne
.RIDTestSupport~ok(firstResult)
item = firstResult~value
.RIDTestSupport~assertEq("OPEN", item~status)

/* Simulate downstream redelivery of the already-materialised case projection. */
projection = .directory~new
projection["schema"] = "regulated.intermediary.case-status-projection/1"
projection["case_id"] = fx["CASE"]~caseId
projection["workflow_state"] = fx["CASE"]~state
projection["provider_status"] = fx["CASE"]~providerStatus
projection["provider_sequence"] = fx["CASE"]~providerSequence~string
projection["provider_event_id"] = fx["CASE"]~providerEventId
projection["provider_case_ref"] = fx["CASE"]~providerCaseRef
projection["product_ref_id"] = fx["CASE"]~productRefId
projection["product_semantic_identity"] = fx["CASE"]~productSemanticIdentity
projection["firm_id"] = fx["CASE"]~firmId
projection["representative_id"] = fx["CASE"]~representativeId
projection["source_event_id"] = "MTG-WORK-IDEMP-1"
projection["updated_at"] = fx["CASE"]~updatedAt~string
opts = .table~new; opts["persistent"] = .true; opts["correlationId"] = fx["CASE"]~caseId
.RIDTestSupport~assertTrue(fx["MANAGER"]~put(fx["SERVICE"]~statusInputQueue, projection, opts, "RID_ADMIN")~ok)
second = fx["SERVICE"]~processStatusOne
.RIDTestSupport~assertTrue(second~ok)
.RIDTestSupport~assertEq("WORK_SOURCE_EVENT_DUPLICATE", second~detail)
.RIDTestSupport~assertEq("OPEN", item~status, "a duplicate projection must not supersede its own work")
.RIDTestSupport~assertEq(item~workItemId, second~value~workItemId)

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS downstream case-status redelivery is work-projection idempotent"
exit 0
::requires "WorkTestSupport.cls"
