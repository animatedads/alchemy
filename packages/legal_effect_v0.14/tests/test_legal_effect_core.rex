say "LEGAL EFFECT V0.14 CORE START"
a = .LegalEffectAcceptance~new
exit a~run

::class LegalEffectAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  legislation = .NormativeSource~new("SYN-LA-001", "LEGISLATION", "Synthetic LA delivery statute", "SYNTHETIC", "LA")
  contract = .NormativeSource~new("CONTRACT-DRIVER-7", "CONTRACT", "Driver services contract", "PARTIES", "*")
  treaty = .NormativeSource~new("TREATY-DEMO-1", "TREATY", "Synthetic treaty", "TREATY_PARTIES", "*")
  ok = self~assertEqual("LEGISLATION", legislation~sourceKind, "legislation source kind retained")
  ok = self~assertEqual("CONTRACT", contract~sourceKind, "contract source kind retained")
  ok = self~assertEqual("TREATY", treaty~sourceKind, "treaty source kind retained")
  ok = self~assertEqual("EXPLICIT", contract~applicabilityMode, "contract requires explicit applicability binding")
  ok = self~assertEqual("EXPLICIT", treaty~applicabilityMode, "treaty requires explicit applicability binding by safe default")

  facts = .LegalFactSet~new
  ignored = facts~putKnown("FORCED_BLOCKS", .false)
  context = .LegalContext~new("DELIVERY-POLICY-1", "2026-08-20", "2026-08-20", facts)
  ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("CALIFORNIA", "LOS_ANGELES", "WORK_RELATIONSHIP", "place of work"))

  generation = .LegalRuleGeneration~new("LEGAL-DEMO-G1", "1.0")
  ok = self~assertTrue(generation~addSource(legislation)~ok, "source added")
  ok = self~assertTrue(generation~addSource(contract)~ok, "contract added")
  ok = self~assertTrue(generation~addSource(treaty)~ok, "treaty added")

  statusNorm = .LegalNorm~new("LA-STATUS-1", legislation~sourceId, "Z.11.12", "STATUS", "SCHEDULING_CHANGE", "STATUS_EFFECT", "WORK_RELATIONSHIP", "Synthetic: forced blocks alter status predicates")
  ignored = statusNorm~addJurisdiction(.LegalJurisdictionClaim~new("CALIFORNIA", "LOS_ANGELES", "WORK_RELATIONSHIP"))
  ignored = statusNorm~addCondition(.LegalPredicate~new("FORCED_BLOCKS", "KNOWN_TRUE"))
  ok = self~assertTrue(generation~addNorm(statusNorm)~ok, "status norm added")

  breachNorm = .LegalNorm~new("CONTRACT-11-12", contract~sourceId, "11.12", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH", "CONTRACT", "Synthetic fixed-term rate protection")
  ignored = breachNorm~addCondition(.LegalPredicate~new("RATE_CHANGE_DURING_TERM", "KNOWN_TRUE"))
  ok = self~assertTrue(generation~addNorm(breachNorm)~ok, "contract norm added")

  ignored = generation~seal
  ok = self~assertTrue(generation~sealed, "generation sealed")
  ok = self~assertTrue(\generation~addNorm(.LegalNorm~new("X", "Y", "1", "TEST", "*", "REVIEW"))~ok, "sealed generation rejects mutation")

  action = .LegalAction~new("SCHEDULING_CHANGE", "Require fixed four-hour blocks")
  ignored = action~setFact("FORCED_BLOCKS", .true)
  evalResult = .LegalEffectEngine~new~evaluate(action, generation, context)
  ok = self~assertTrue(evalResult~ok, "effect evaluation succeeds")
  assessment = evalResult~value
  ok = self~assertEqual("REVIEW_REQUIRED", assessment~status, "status-changing action requires review")
  ok = self~assertEqual(1, assessment~newlyApplicable~items, "status norm becomes applicable only after action")
  ok = self~assertEqual("LA-STATUS-1", assessment~newlyApplicable[1]~norm~normId, "new norm identity retained")

  rateAction = .LegalAction~new("RATE_CHANGE", "Reduce contracted rate")
  ignored = rateAction~setFact("RATE_CHANGE_DURING_TERM", .true)
  unboundRate = .LegalEffectEngine~new~evaluate(rateAction, generation, context)
  ok = self~assertEqual("ADMISSIBLE", unboundRate~value~status, "unbound contract does not apply merely because it is loaded")

  ignored = context~bindSource(contract~sourceId, "driver is a party to current services contract")
  rateEval = .LegalEffectEngine~new~evaluate(rateAction, generation, context)
  ok = self~assertTrue(rateEval~ok, "contract evaluation succeeds")
  ok = self~assertEqual("BLOCKED", rateEval~value~status, "contract breach blocks candidate action")
  ok = self~assertEqual("CONTRACT_BREACH", rateEval~value~dispositions[1], "contract breach is machine-readable")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 CORE: OK"
  return 0

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then do
    say "ASSERTION FAILED:" label
    say " expected=" expected
    say " actual=" actual
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalEffect.cls"
