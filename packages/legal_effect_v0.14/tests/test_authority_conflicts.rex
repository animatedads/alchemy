say "LEGAL EFFECT V0.14 AUTHORITY / CONFLICT START"
a = .LegalAuthorityAcceptance~new
exit a~run

::class LegalAuthorityAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  statute = .NormativeSource~new("SYN-STATUTE", "LEGISLATION", "Synthetic mandatory delivery rule", "PARLIAMENT", "ENGLAND")
  contract = .NormativeSource~new("SYN-CONTRACT", "CONTRACT", "Synthetic driver contract", "PARTIES", "*", "English law")

  gen = .LegalRuleGeneration~new("AUTH-G1", "0.3")
  ok = self~assertTrue(gen~addSource(statute)~ok, "statute source added")
  ok = self~assertTrue(gen~addSource(contract)~ok, "contract source added")

  statutoryNorm = .LegalNorm~new("STAT-N1", statute~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "synthetic mandatory floor", .nil, "*", "WAGE_CUT_LEGALITY")
  contractNorm = .LegalNorm~new("CONTRACT-N1", contract~sourceId, "4", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "synthetic variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
  ok = self~assertTrue(gen~addNorm(statutoryNorm)~ok, "statutory norm added")
  ok = self~assertTrue(gen~addNorm(contractNorm)~ok, "contract norm added")
  ignored = gen~seal

  context = .LegalContext~new("LONDON-WAGE-CUT", "2026-08-20")
  ignored = context~bindSource(contract~sourceId, "driver is party to contract")
  unresolved = .LegalEffectEngine~new~evaluate(.LegalAction~new("WAGE_CUT"), gen, context)
  ok = self~assertTrue(unresolved~ok, "unresolved conflict evaluation succeeds")
  ok = self~assertEqual("REVIEW_REQUIRED", unresolved~value~status, "conflict without authority is review-required")
  ok = self~assertEqual(1, unresolved~value~unresolvedConflicts~items, "unresolved conflict retained")
  ok = self~assertEqual(0, unresolved~value~dispositions~items, "conflicting dispositions withheld")

  gen2 = .LegalRuleGeneration~new("AUTH-G2", "0.3")
  ignored = gen2~addSource(statute)
  ignored = gen2~addSource(contract)
  statutoryNorm2 = .LegalNorm~new("STAT-N1", statute~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "synthetic mandatory floor", .nil, "*", "WAGE_CUT_LEGALITY")
  contractNorm2 = .LegalNorm~new("CONTRACT-N1", contract~sourceId, "4", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "synthetic variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
  ignored = gen2~addNorm(statutoryNorm2)
  ignored = gen2~addNorm(contractNorm2)
  priority = .LegalAuthorityRule~new("STATUTE-OVERRIDES-CONTRACT", statute~sourceId, "11", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK_RELATIONSHIP", "WAGE_CUT", .nil, "STAT-N1", "CONTRACT-N1", "synthetic non-derogation rule")
  ok = self~assertTrue(gen2~addAuthorityRule(priority)~ok, "authority rule added")
  ignored = gen2~seal
  ok = self~assertEqual(1, gen2~authorityRuleCount, "authority rule count")
  ok = self~assertTrue(priority~sealed, "authority rule sealed with generation")

  resolved = .LegalEffectEngine~new~evaluate(.LegalAction~new("WAGE_CUT"), gen2, context)
  ok = self~assertTrue(resolved~ok, "resolved conflict evaluation succeeds")
  ok = self~assertEqual("BLOCKED", resolved~value~status, "authoritative prohibition governs")
  ok = self~assertEqual(1, resolved~value~resolvedConflicts~items, "resolved conflict retained")
  ok = self~assertEqual(0, resolved~value~unresolvedConflicts~items, "no unresolved conflicts")
  ok = self~assertEqual("STAT-N1", resolved~value~resolvedConflicts[1]~winnerMatch~norm~normId, "winning norm explicit")
  ok = self~assertEqual("CONTRACT-N1", resolved~value~resolvedConflicts[1]~loserMatch~norm~normId, "suppressed norm explicit")
  ok = self~assertEqual("STATUTE-OVERRIDES-CONTRACT", resolved~value~resolvedConflicts[1]~authorityMatch~rule~ruleId, "authority provenance retained")
  ok = self~assertEqual(1, resolved~value~suppressedMatches~items, "losing norm suppressed")
  ok = self~assertEqual("PROHIBITED", resolved~value~dispositions[1], "only effective disposition emitted")

  lateGen = .LegalRuleGeneration~new("AUTH-G3", "0.3")
  ignored = lateGen~addSource(statute)
  ignored = lateGen~addSource(contract)
  statLate = .LegalNorm~new("STAT-LATE", statute~sourceId, "20", "PROHIBITION", "SHIFT_LOCK", "PROHIBITED", "WORK_RELATIONSHIP", "synthetic", .nil, "*", "SHIFT_LOCK_LEGALITY")
  contractLate = .LegalNorm~new("CONTRACT-LATE", contract~sourceId, "8", "PERMISSION", "SHIFT_LOCK", "PERMITTED", "WORK_RELATIONSHIP", "synthetic", .nil, "*", "SHIFT_LOCK_LEGALITY")
  ignored = lateGen~addNorm(statLate)
  ignored = lateGen~addNorm(contractLate)
  lateScope = .LegalTemporalScope~new("2026-09-01", "2026-09-01", "", "2026-09-01", "")
  lateRule = .LegalAuthorityRule~new("LATE-PRIORITY", statute~sourceId, "21", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK_RELATIONSHIP", "SHIFT_LOCK", lateScope, "STAT-LATE", "CONTRACT-LATE")
  ignored = lateGen~addAuthorityRule(lateRule)
  ignored = lateGen~seal
  beforeCtx = .LegalContext~new("BEFORE", "2026-08-31")
  ignored = beforeCtx~bindSource(contract~sourceId, "party")
  afterCtx = .LegalContext~new("AFTER", "2026-09-01")
  ignored = afterCtx~bindSource(contract~sourceId, "party")
  beforeEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("SHIFT_LOCK"), lateGen, beforeCtx)
  afterEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("SHIFT_LOCK"), lateGen, afterCtx)
  ok = self~assertEqual("REVIEW_REQUIRED", beforeEval~value~status, "future authority cannot resolve earlier event")
  ok = self~assertEqual("BLOCKED", afterEval~value~status, "authority becomes effective at its own time")

  treaty = .NormativeSource~new("SYN-TREATY", "TREATY", "Synthetic treaty authority", "TREATY_PARTIES", "*")
  privateGen = .LegalRuleGeneration~new("AUTH-G4", "0.3")
  ignored = privateGen~addSource(statute)
  ignored = privateGen~addSource(contract)
  ignored = privateGen~addSource(treaty)
  statPrivate = .LegalNorm~new("STAT-PRIVATE", statute~sourceId, "30", "PROHIBITION", "TRANSFER", "PROHIBITED", "DATA", "synthetic", .nil, "*", "TRANSFER_LAW")
  contractPrivate = .LegalNorm~new("CONTRACT-PRIVATE", contract~sourceId, "30", "PERMISSION", "TRANSFER", "PERMITTED", "DATA", "synthetic", .nil, "*", "TRANSFER_LAW")
  ignored = privateGen~addNorm(statPrivate)
  ignored = privateGen~addNorm(contractPrivate)
  treatyPriority = .LegalAuthorityRule~new("TREATY-PRIORITY", treaty~sourceId, "5", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "DATA", "TRANSFER", .nil, "STAT-PRIVATE", "CONTRACT-PRIVATE")
  ignored = privateGen~addAuthorityRule(treatyPriority)
  ignored = privateGen~seal
  privateCtx = .LegalContext~new("TRANSFER", "2026-08-20")
  ignored = privateCtx~bindSource(contract~sourceId, "party")
  unboundTreaty = .LegalEffectEngine~new~evaluate(.LegalAction~new("TRANSFER"), privateGen, privateCtx)
  ok = self~assertEqual("REVIEW_REQUIRED", unboundTreaty~value~status, "unbound explicit authority source does not control")
  ignored = privateCtx~bindSource(treaty~sourceId, "treaty applicability established for this context")
  boundTreaty = .LegalEffectEngine~new~evaluate(.LegalAction~new("TRANSFER"), privateGen, privateCtx)
  ok = self~assertEqual("BLOCKED", boundTreaty~value~status, "bound explicit authority source may resolve conflict")

  sourceA = .NormativeSource~new("LAW-A", "LEGISLATION", "Synthetic law A", "A", "TEST")
  sourceB = .NormativeSource~new("LAW-B", "LEGISLATION", "Synthetic law B", "B", "TEST")
  sourceC = .NormativeSource~new("LAW-C", "LEGISLATION", "Synthetic law C", "C", "TEST")
  cycleGen = .LegalRuleGeneration~new("AUTH-CYCLE", "0.3")
  ignored = cycleGen~addSource(sourceA)
  ignored = cycleGen~addSource(sourceB)
  ignored = cycleGen~addSource(sourceC)
  normA = .LegalNorm~new("NORM-A", sourceA~sourceId, "1", "STATUS", "CYCLE_ACTION", "A_WINS", "TEST", "synthetic", .nil, "*", "CYCLE_KEY")
  normB = .LegalNorm~new("NORM-B", sourceB~sourceId, "1", "STATUS", "CYCLE_ACTION", "B_WINS", "TEST", "synthetic", .nil, "*", "CYCLE_KEY")
  normC = .LegalNorm~new("NORM-C", sourceC~sourceId, "1", "STATUS", "CYCLE_ACTION", "C_WINS", "TEST", "synthetic", .nil, "*", "CYCLE_KEY")
  ignored = cycleGen~addNorm(normA)
  ignored = cycleGen~addNorm(normB)
  ignored = cycleGen~addNorm(normC)
  ignored = cycleGen~addAuthorityRule(.LegalAuthorityRule~new("A-OVER-B", sourceA~sourceId, "2", sourceA~sourceId, sourceB~sourceId, "PREVAILS_OVER", "TEST", "CYCLE_ACTION", .nil, "NORM-A", "NORM-B"))
  ignored = cycleGen~addAuthorityRule(.LegalAuthorityRule~new("B-OVER-C", sourceB~sourceId, "2", sourceB~sourceId, sourceC~sourceId, "PREVAILS_OVER", "TEST", "CYCLE_ACTION", .nil, "NORM-B", "NORM-C"))
  ignored = cycleGen~addAuthorityRule(.LegalAuthorityRule~new("C-OVER-A", sourceC~sourceId, "2", sourceC~sourceId, sourceA~sourceId, "PREVAILS_OVER", "TEST", "CYCLE_ACTION", .nil, "NORM-C", "NORM-A"))
  ignored = cycleGen~seal
  cycleEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("CYCLE_ACTION"), cycleGen, .LegalContext~new("CYCLE", "2026-08-20"))
  ok = self~assertEqual("REVIEW_REQUIRED", cycleEval~value~status, "precedence cycle fails closed")
  ok = self~assertTrue(cycleEval~value~unresolvedConflicts~items > 0, "precedence cycle retained as unresolved")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 AUTHORITY / CONFLICT: OK"
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
