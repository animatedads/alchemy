say "LEGAL EFFECT V0.14 HARDWORLD BRIDGE START"
a = .HardWorldBridgeAcceptance~new
exit a~run

::class HardWorldBridgeAcceptance
::method run
  source = .NormativeSource~new("C-1", "CONTRACT", "Synthetic contract")
  norm = .LegalNorm~new("C-1-11", "C-1", "11.12", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH")
  ignored = norm~addCondition(.LegalPredicate~new("RATE_CHANGE", "KNOWN_TRUE"))
  gen = .LegalRuleGeneration~new("G-HW", "1")
  ignored = gen~addSource(source)
  ignored = gen~addNorm(norm)
  ignored = gen~seal
  context = .LegalContext~new("E-1", "2026-08-20")
  ignored = context~bindSource(source~sourceId, "contract applies to actor")
  action = .LegalAction~new("RATE_CHANGE")
  ignored = action~setFact("RATE_CHANGE", .true)
  assessment = .LegalEffectEngine~new~evaluate(action, gen, context)~value
  world = .RYTAWorldState~new("LEGAL-HW-DEMO")
  bridgeResult = .LegalHardWorldBridge~applyAssessment(assessment, world)
  if \bridgeResult~ok then raise syntax 88.900 array(bridgeResult~detail)
  if \world~isKnownTrue("LEGAL_ACTION_BLOCKED") then raise syntax 88.900 array("blocked fact not projected")
  projected = world~fact("LEGAL_ACTION_BLOCKED")
  if projected~source \== assessment then raise syntax 88.900 array("assessment evidence identity lost")
  say "LEGAL EFFECT V0.14 HARDWORLD BRIDGE: OK"
  return 0

::requires "LegalEffect.cls"
::requires "HardWorld.cls"
