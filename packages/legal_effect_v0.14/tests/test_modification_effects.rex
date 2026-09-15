say "LEGAL EFFECT V0.14 MODIFICATION EFFECTS START"
a = .LegalModificationAcceptance~new
exit a~run

::class LegalModificationAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  base = .NormativeSource~new("NSW-DELIVERY-BASE", "LEGISLATION", "Synthetic delivery framework", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES")
  amend = .NormativeSource~new("NSW-DELIVERY-AMEND", "LEGISLATION", "Synthetic amendment", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES")
  gen = .LegalRuleGeneration~new("LEGAL-MOD-G1", "0.2")
  ok = self~assertTrue(gen~addSource(base)~ok, "base source added")
  ok = self~assertTrue(gen~addSource(amend)~ok, "amending source added")

  rateProvision = .LegalProvision~new(base~sourceId, "4.1", "ACTIVE", "BASE", "old synthetic rate text")
  commencementProvision = .LegalProvision~new(base~sourceId, "7.1", "NOT_COMMENCED", "BASE", "synthetic future obligation")
  savedProvision = .LegalProvision~new(base~sourceId, "9.1", "ACTIVE", "BASE", "synthetic existing-case protection")
  ok = self~assertTrue(gen~addProvision(rateProvision)~ok, "rate provision added")
  ok = self~assertTrue(gen~addProvision(commencementProvision)~ok, "commencement provision added")
  ok = self~assertTrue(gen~addProvision(savedProvision)~ok, "saved provision added")

  oldRate = .LegalNorm~new("RATE-OLD", base~sourceId, "4.1", "PERMISSION", "RATE_CHANGE", "PERMITTED", "WORK_RELATIONSHIP", "old material", .nil, "BASE")
  ignored = oldRate~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  newRate = .LegalNorm~new("RATE-NEW", base~sourceId, "4.1", "OBLIGATION", "RATE_CHANGE", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "substituted material", .nil, "AMEND_2026")
  ignored = newRate~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  futureNorm = .LegalNorm~new("FUTURE-NORM", base~sourceId, "7.1", "OBLIGATION", "SCHEDULE_CHANGE", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "commenced material", .nil, "BASE")
  savedNorm = .LegalNorm~new("SAVED-NORM", base~sourceId, "9.1", "RIGHT", "TERMINATE_EXISTING", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "saved old cases", .nil, "BASE")
  ok = self~assertTrue(gen~addNorm(oldRate)~ok, "old norm added")
  ok = self~assertTrue(gen~addNorm(newRate)~ok, "new norm added")
  ok = self~assertTrue(gen~addNorm(futureNorm)~ok, "future norm added")
  ok = self~assertTrue(gen~addNorm(savedNorm)~ok, "saved norm added")

  substituteTime = .LegalTemporalScope~new("2026-08-17", "2026-08-17", "", "2026-08-17", "")
  substitute = .LegalModificationEffect~new("AMEND-SUB-4-1", amend~sourceId, "2.1", "SUBSTITUTE", base~sourceId, "4.1", substituteTime, 10, "AMEND_2026", "new synthetic rate text")
  ignored = substitute~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
  ok = self~assertTrue(gen~addModification(substitute)~ok, "substitution added")

  commenceTime = .LegalTemporalScope~new("2026-09-01", "2026-09-01", "", "2026-09-01", "")
  commence = .LegalModificationEffect~new("COMMENCE-7-1", amend~sourceId, "3.1", "COMMENCE", base~sourceId, "7.1", commenceTime, 10)
  ok = self~assertTrue(gen~addModification(commence)~ok, "commencement added")

  repealTime = .LegalTemporalScope~new("2026-09-01", "2026-09-01", "", "2026-09-01", "")
  repeal = .LegalModificationEffect~new("REPEAL-9-1", amend~sourceId, "4.1", "REPEAL", base~sourceId, "9.1", repealTime, 10)
  save = .LegalModificationEffect~new("SAVE-9-1", amend~sourceId, "4.2", "SAVE", base~sourceId, "9.1", repealTime, 20)
  ignored = save~addCondition(.LegalPredicate~new("EXISTING_CASE", "KNOWN_TRUE"))
  ok = self~assertTrue(gen~addModification(repeal)~ok, "repeal added")
  ok = self~assertTrue(gen~addModification(save)~ok, "saving effect added")

  ignored = gen~seal
  ok = self~assertTrue(gen~sealed, "generation sealed")
  ok = self~assertEqual(3, gen~provisionCount, "provision count")
  ok = self~assertEqual(4, gen~modificationCount, "modification count")

  graph = .LegalJurisdictionGraph~new
  ignored = graph~addNode("AU", "COMMONWEALTH_OF_AUSTRALIA", "AUSTRALIA")
  ignored = graph~addNode("NSW", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "AU")
  ignored = graph~addNode("SYDNEY", "CITY_OF_SYDNEY", "SYDNEY", "NSW")

  before = .LegalContext~new("RATE-BEFORE", "2026-08-16", "2026-08-20")
  ignored = before~useJurisdictionGraph(graph, "SYDNEY")
  after = .LegalContext~new("RATE-AFTER", "2026-08-18", "2026-08-20")
  ignored = after~useJurisdictionGraph(graph, "SYDNEY")
  action = .LegalAction~new("RATE_CHANGE")

  beforeEval = .LegalEffectEngine~new~evaluate(action, gen, before)
  ok = self~assertTrue(beforeEval~ok, "pre-amendment evaluation succeeds")
  ok = self~assertEqual("ADMISSIBLE", beforeEval~value~status, "old material governs before substitution")
  ok = self~assertEqual("PERMITTED", beforeEval~value~dispositions[1], "old disposition selected")
  beforeState = beforeEval~value~afterSnapshot~provisionState(base~sourceId, "4.1")
  ok = self~assertEqual("BASE", beforeState~materialVersion, "base version retained before effect")

  afterEval = .LegalEffectEngine~new~evaluate(action, gen, after)
  ok = self~assertTrue(afterEval~ok, "post-amendment evaluation succeeds")
  ok = self~assertEqual("CONDITIONAL", afterEval~value~status, "new obligation governs after substitution")
  ok = self~assertEqual("REQUIRES_OBLIGATION", afterEval~value~dispositions[1], "new disposition selected")
  afterState = afterEval~value~afterSnapshot~provisionState(base~sourceId, "4.1")
  ok = self~assertEqual("AMEND_2026", afterState~materialVersion, "substituted version selected")
  ok = self~assertEqual("new synthetic rate text", afterState~lexicalText, "substituted lexical material retained")
  ok = self~assertTrue(afterState~lineage[1] == substitute, "modification object identity retained in lineage")

  preCommence = .LegalContext~new("PRE-COMMENCE", "2026-08-31")
  postCommence = .LegalContext~new("POST-COMMENCE", "2026-09-01")
  scheduleAction = .LegalAction~new("SCHEDULE_CHANGE")
  preCommenceEval = .LegalEffectEngine~new~evaluate(scheduleAction, gen, preCommence)
  postCommenceEval = .LegalEffectEngine~new~evaluate(scheduleAction, gen, postCommence)
  ok = self~assertEqual("ADMISSIBLE", preCommenceEval~value~status, "not-commenced provision is inert")
  ok = self~assertEqual("CONDITIONAL", postCommenceEval~value~status, "commenced provision becomes operative")

  existingFacts = .LegalFactSet~new
  ignored = existingFacts~putKnown("EXISTING_CASE", .true)
  existingContext = .LegalContext~new("EXISTING-CASE", "2026-09-02", "", existingFacts)
  newFacts = .LegalFactSet~new
  ignored = newFacts~putKnown("EXISTING_CASE", .false)
  newContext = .LegalContext~new("NEW-CASE", "2026-09-02", "", newFacts)
  terminate = .LegalAction~new("TERMINATE_EXISTING")
  existingEval = .LegalEffectEngine~new~evaluate(terminate, gen, existingContext)
  newEval = .LegalEffectEngine~new~evaluate(terminate, gen, newContext)
  existingState = existingEval~value~afterSnapshot~provisionState(base~sourceId, "9.1")
  newState = newEval~value~afterSnapshot~provisionState(base~sourceId, "9.1")
  ok = self~assertEqual("SAVED_ACTIVE", existingState~status, "saving effect preserves old law for existing case")
  ok = self~assertEqual("REPEALED", newState~status, "repeal governs new case")
  ok = self~assertEqual("CONDITIONAL", existingEval~value~status, "saved norm remains executable")
  ok = self~assertEqual("ADMISSIBLE", newEval~value~status, "repealed norm no longer constrains new case")

  uncertainSource = .NormativeSource~new("UNCERTAIN-LAW", "LEGISLATION", "Synthetic uncertain amendment", "TEST", "TEST")
  uncertainGen = .LegalRuleGeneration~new("LEGAL-UNCERTAIN-G1", "0.2")
  ignored = uncertainGen~addSource(uncertainSource)
  uncertainProvision = .LegalProvision~new(uncertainSource~sourceId, "1", "ACTIVE", "BASE", "synthetic material")
  ignored = uncertainGen~addProvision(uncertainProvision)
  uncertainNorm = .LegalNorm~new("UNCERTAIN-NORM", uncertainSource~sourceId, "1", "PROHIBITION", "UNCERTAIN_ACTION", "PROHIBITED", "TEST", "must not guess through uncertain modification", .nil, "BASE")
  ignored = uncertainGen~addNorm(uncertainNorm)
  uncertainEffect = .LegalModificationEffect~new("UNCERTAIN-REPEAL", uncertainSource~sourceId, "2", "REPEAL", uncertainSource~sourceId, "1", .LegalTemporalScope~new("2026-01-01", "2026-01-01", "", "2026-01-01", ""), 10)
  ignored = uncertainEffect~addCondition(.LegalPredicate~new("REPEAL_CONDITION", "KNOWN_TRUE"))
  ignored = uncertainGen~addModification(uncertainEffect)
  ignored = uncertainGen~seal
  uncertainContext = .LegalContext~new("UNCERTAIN", "2026-08-20")
  uncertainEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("UNCERTAIN_ACTION"), uncertainGen, uncertainContext)
  ok = self~assertEqual("REVIEW_REQUIRED", uncertainEval~value~status, "unresolved modifying effect forces review rather than guessing")
  ok = self~assertEqual(1, uncertainEval~value~afterSnapshot~unresolvedModifications~items, "unresolved modification retained in snapshot")

  contract = .NormativeSource~new("PRIVATE-CONTRACT", "CONTRACT", "Synthetic private contract", "PARTIES", "*")
  variation = .NormativeSource~new("PRIVATE-VARIATION", "CONTRACT", "Synthetic contract variation", "PARTIES", "*")
  contractGen = .LegalRuleGeneration~new("CONTRACT-MOD-G1", "0.2")
  ignored = contractGen~addSource(contract)
  ignored = contractGen~addSource(variation)
  contractProvision = .LegalProvision~new(contract~sourceId, "11.12", "ACTIVE", "BASE", "old contract term")
  ignored = contractGen~addProvision(contractProvision)
  contractEffect = .LegalModificationEffect~new("CONTRACT-VARIATION-1", variation~sourceId, "1", "SUBSTITUTE", contract~sourceId, "11.12", .LegalTemporalScope~new("2026-01-01", "2026-01-01", "", "2026-01-01", ""), 10, "VARIATION_1", "varied contract term")
  ignored = contractGen~addModification(contractEffect)
  ignored = contractGen~seal
  contractContext = .LegalContext~new("CONTRACT-CONTEXT", "2026-08-20")
  ignored = contractContext~bindSource(contract~sourceId, "party to base contract")
  unboundVariation = .LegalFrameworkResolver~new~resolve(contractGen, contractContext)
  ok = self~assertEqual("BASE", unboundVariation~value~provisionState(contract~sourceId, "11.12")~materialVersion, "unbound private variation cannot modify contract")
  ignored = contractContext~bindSource(variation~sourceId, "party accepted variation")
  boundVariation = .LegalFrameworkResolver~new~resolve(contractGen, contractContext)
  ok = self~assertEqual("VARIATION_1", boundVariation~value~provisionState(contract~sourceId, "11.12")~materialVersion, "bound private variation modifies contract snapshot")

  ambiguousGen = .LegalRuleGeneration~new("AMBIGUOUS-G1", "0.2")
  ignored = ambiguousGen~addSource(base)
  ambiguousProvision = .LegalProvision~new(base~sourceId, "A.1", "ACTIVE", "BASE", "synthetic")
  ignored = ambiguousGen~addProvision(ambiguousProvision)
  sameDate = .LegalTemporalScope~new("2026-01-01", "2026-01-01", "", "2026-01-01", "")
  ambiguousOne = .LegalModificationEffect~new("AMBIG-ONE", base~sourceId, "A.2", "SUBSTITUTE", base~sourceId, "A.1", sameDate, 10, "V2", "v2")
  ambiguousTwo = .LegalModificationEffect~new("AMBIG-TWO", base~sourceId, "A.3", "SUBSTITUTE", base~sourceId, "A.1", sameDate, 10, "V3", "v3")
  ignored = ambiguousGen~addModification(ambiguousOne)
  ignored = ambiguousGen~addModification(ambiguousTwo)
  ignored = ambiguousGen~seal
  ambiguousResult = .LegalFrameworkResolver~new~resolve(ambiguousGen, .LegalContext~new("AMBIG", "2026-08-20"))
  ok = self~assertTrue(\ambiguousResult~ok, "same target/date/order is rejected rather than silently tie-broken")
  ok = self~assertEqual("AMBIGUOUS_MODIFICATION_ORDER", ambiguousResult~code, "ambiguous modification order has machine-readable failure")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 MODIFICATION EFFECTS: OK"
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
