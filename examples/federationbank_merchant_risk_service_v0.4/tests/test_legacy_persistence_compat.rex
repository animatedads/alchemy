codec=.FederationBankMerchantRiskPersistence~newCodec
legacyWork=.LegacyRiskWork~new("W-OLD","HEDGE_REMEDIATION","H-RS","REM-OLD","MSE-OLD","10:00","POL-OLD","OPEN")
works=.directory~new; works["W-OLD"]=legacyWork
legacyState=.LegacyRiskState~new(.directory~new,works,.array~new,.directory~new,7)
graph=codec~encode(legacyState)
restored=codec~decode(graph)
.MBRiskServiceTestSupport~assertTrue(restored~isA(.MBRiskServiceState),"legacy state type restores into current state")
w=restored~workItems["W-OLD"]
.MBRiskServiceTestSupport~assertTrue(w~isA(.MBRiskWorkItem),"legacy work type restores into current work item")
.MBRiskServiceTestSupport~assertEq("",w~rootTradeId,"legacy work defaults root trade")
.MBRiskServiceTestSupport~assertEq("",w~bookAssessmentId,"legacy work defaults book assessment")
.MBRiskServiceTestSupport~assertEq(7,restored~sequence,"legacy state sequence retained")
say "PASS test_legacy_persistence_compat"
exit 0

::class LegacyRiskWork
::method init
  expose workId workType hedgeId remediationId sourceEventId createdAt policyRef state
  use strict arg workId,workType,hedgeId,remediationId,sourceEventId,createdAt,policyRef,state
::method queuePersistentType; return "federationbank.merchant.risk.work/1"
::method queuePersistentState
  expose workId workType hedgeId remediationId sourceEventId createdAt policyRef state
  s=.table~new; s["workId"]=workId; s["workType"]=workType; s["hedgeId"]=hedgeId; s["remediationId"]=remediationId; s["sourceEventId"]=sourceEventId; s["createdAt"]=createdAt; s["policyRef"]=policyRef; s["state"]=state; return s

::class LegacyRiskState
::method init
  expose watches workItems events receipts sequence
  use strict arg watches,workItems,events,receipts,sequence
::method queuePersistentType; return "federationbank.merchant.risk.service.state/1"
::method queuePersistentState
  expose watches workItems events receipts sequence
  s=.table~new; s["watches"]=watches; s["workItems"]=workItems; s["events"]=events; s["receipts"]=receipts; s["sequence"]=sequence; return s

::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskPersistence.cls"
