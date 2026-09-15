say "LEGAL EFFECT V0.14 TEMPORAL/JURISDICTION START"
a = .TemporalAcceptance~new
exit a~run

::class TemporalAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  source = .NormativeSource~new("SYN-AU-ORDER", "REGULATION", "Synthetic delivery minimum standards order", "SYNTHETIC", "AU-NSW")
  temporal = .LegalTemporalScope~new("2026-08-17", "2026-08-17", "", "2026-08-17", "")
  norm = .LegalNorm~new("NSW-RATE-1", source~sourceId, "4.1", "OBLIGATION", "RATE_CHANGE", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "Synthetic commencement boundary", temporal)
  ignored = norm~addJurisdiction(.LegalJurisdictionClaim~new("AUSTRALIA", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  ignored = norm~addCondition(.LegalPredicate~new("EMPLOYEE_LIKE_WORKER", "KNOWN_TRUE"))

  gen = .LegalRuleGeneration~new("NSW-G1", "1")
  ignored = gen~addSource(source)
  ignored = gen~addNorm(norm)
  ignored = gen~seal

  facts = .LegalFactSet~new
  ignored = facts~putKnown("EMPLOYEE_LIKE_WORKER", .true)

  before = .LegalContext~new("E-BEFORE", "2026-08-16", "2026-08-20", facts)
  ignored = before~addJurisdiction(.LegalJurisdictionClaim~new("AUSTRALIA", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  action = .LegalAction~new("RATE_CHANGE")
  beforeResult = .LegalEffectEngine~new~evaluate(action, gen, before)
  ok = self~assertEqual("ADMISSIBLE", beforeResult~value~status, "rule does not apply before commencement")

  after = .LegalContext~new("E-AFTER", "2026-08-18", "2026-08-20", facts)
  ignored = after~addJurisdiction(.LegalJurisdictionClaim~new("AUSTRALIA", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  afterResult = .LegalEffectEngine~new~evaluate(action, gen, after)
  ok = self~assertEqual("CONDITIONAL", afterResult~value~status, "rule applies after commencement")

  wrongPlace = .LegalContext~new("E-LONDON", "2026-08-18", "2026-08-20", facts)
  ignored = wrongPlace~addJurisdiction(.LegalJurisdictionClaim~new("UNITED_KINGDOM", "ENGLAND", "WORK_RELATIONSHIP"))
  wrongResult = .LegalEffectEngine~new~evaluate(action, gen, wrongPlace)
  ok = self~assertEqual("ADMISSIBLE", wrongResult~value~status, "NSW norm does not leak into London")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 TEMPORAL/JURISDICTION: OK"
  return 0

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then raise syntax 88.900 array(label || ": expected=" || expected || " actual=" || actual)
  return .true

::requires "LegalEffect.cls"
