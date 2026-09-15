clock = .RIDManualTimeSource~new(1000000)
p = .RIDWorkPolicy~new
.RIDTestSupport~ok(p~addRule(.RIDWorkRule~new("RECOVER-APPROVAL", "MORTGAGE", "APPROVED", "RECOVERABLE_ACTION", "INTERMEDIARY", 77, 60, "ACK")))
.RIDTestSupport~ok(p~seal)
fx = .RIDWorkIntegrationFixtures~setup("MORTGAGE", "FEDERATIONBANK_PLC", "FEDERATION_MORTGAGE", "HOME-1", "HOME-1|2026.08|A", clock, p)
approved = .RIDWorkIntegrationFixtures~providerStatus(fx, "MTG-REC-1", 1, "APPROVED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, approved))
item = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
workId = item~workItemId
root = fx["ROOT"]
engine = fx["ENGINE"]
catalog = fx["ENV"]["CATALOG"]

/* Re-open the durable queue manager. Topic state and work audit are recovered;
   the direct TTL trigger is re-registered by configure(). */
manager2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "RID_ADMIN", .nil, .nil, "STRICT", clock)
bridge2 = .RIDQueueEventBridge~new(manager2, engine, fx["SIGNATURES"], "RID_ADMIN")
.RIDTestSupport~ok(bridge2~configure)
service2 = .RIDIntermediaryWorkService~new(manager2, bridge2~topicFabric, engine, catalog, p, "RID_ADMIN", clock)
.RIDTestSupport~ok(service2~configure)
recovered = service2~workItem(workId)
.RIDTestSupport~assertTrue(recovered <> .nil)
.RIDTestSupport~assertEq("OPEN", recovered~status)
.RIDTestSupport~assertEq("RECOVERABLE_ACTION", recovered~workType)
deadlineFound = .false
do pkg over manager2~authorisedPackages("RID_ADMIN")
  if pkg~currentQueue <> service2~slaQueue then iterate
  if pkg~payload["work_item_id"] = workId then deadlineFound = .true
end
.RIDTestSupport~assertTrue(deadlineFound, "SLA package must survive/recover without extending due time")

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS durable work audit and SLA deadline recover after restart"
exit 0

::requires "WorkTestSupport.cls"
