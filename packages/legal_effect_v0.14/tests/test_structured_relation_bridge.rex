say "LEGAL EFFECT V0.14 STRUCTURED RELATION BRIDGE START"
a = .BridgeAcceptance~new
exit a~run

::class BridgeAcceptance
::method run
  sourceObject = .table~new
  sourceObject["origin"] = "synthetic structured evidence"
  richFact = .RichBusinessFact~new("DRIVER_RETENTION_BURDEN", 0.15, "PRESENT", sourceObject, .nil, "DECIMAL", "0.15")
  richFacts = .array~of(richFact)
  bridgeResult = .LegalStructuredRelationBridge~factSetFrom(richFacts)
  if \bridgeResult~ok then raise syntax 88.900 array(bridgeResult~detail)
  fact = bridgeResult~value~fact("DRIVER_RETENTION_BURDEN")
  if fact~state <> "KNOWN" then raise syntax 88.900 array("rich fact state not preserved")
  if fact~value <> 0.15 then raise syntax 88.900 array("rich fact value not preserved")
  if fact~source \== sourceObject then raise syntax 88.900 array("rich fact source identity not preserved")
  if fact~evidence \== richFact then raise syntax 88.900 array("complete RichBusinessFact envelope not preserved")
  clonedFact = bridgeResult~value~clone~fact("DRIVER_RETENTION_BURDEN")
  if clonedFact~evidence \== richFact then raise syntax 88.900 array("RichBusinessFact evidence lost across LegalFactSet clone")
  say "LEGAL EFFECT V0.14 STRUCTURED RELATION BRIDGE: OK"
  return 0

::requires "LegalEffect.cls"
::requires "RichSourceCore.cls"
