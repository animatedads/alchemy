say "LEGAL EFFECT V0.14 CONFLICT OF LAWS START"
a = .ConflictOfLawsAcceptance~new
exit a~run

::class ConflictOfLawsAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  englishLaw = .NormativeSource~new("ENGLISH-CONTRACT-LAW", "LEGISLATION", "Synthetic English contract law", "ENGLAND", "ENGLAND")
  nswLaw = .NormativeSource~new("NSW-CONTRACT-LAW", "LEGISLATION", "Synthetic NSW contract law", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES")
  contract = .NormativeSource~new("CROSS-BORDER-CONTRACT", "CONTRACT", "Synthetic cross-border services contract", "PARTIES", "*", "ENGLAND")

  gen = .LegalRuleGeneration~new("COL-G1", "0.3")
  ignored = gen~addSource(englishLaw)
  ignored = gen~addSource(nswLaw)
  ignored = gen~addSource(contract)

  englishInterpretation = .LegalNorm~new("ENG-INTERPRET", englishLaw~sourceId, "E.1", "STATUS", "INTERPRET_CONTRACT", "ENGLISH_RULE_APPLIES", "CONTRACT", "synthetic English interpretation rule", .nil, "*", "CONTRACT_INTERPRETATION_LAW")
  ignored = englishInterpretation~addJurisdiction(.LegalJurisdictionClaim~new("ENGLAND", "ENGLAND", "CONTRACT", "English connecting factor"))
  nswInterpretation = .LegalNorm~new("NSW-INTERPRET", nswLaw~sourceId, "N.1", "STATUS", "INTERPRET_CONTRACT", "NSW_RULE_APPLIES", "CONTRACT", "synthetic NSW interpretation rule", .nil, "*", "CONTRACT_INTERPRETATION_LAW")
  ignored = nswInterpretation~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "CONTRACT", "NSW connecting factor"))
  ignored = gen~addNorm(englishInterpretation)
  ignored = gen~addNorm(nswInterpretation)

  choice = .LegalAuthorityRule~new("CONTRACT-GOVERNING-LAW", contract~sourceId, "17", englishLaw~sourceId, nswLaw~sourceId, "CHOICE_OF_LAW", "CONTRACT", "INTERPRET_CONTRACT", .nil, "ENG-INTERPRET", "NSW-INTERPRET", "synthetic governing-law clause")
  ignored = choice~addEvidence(.LegalEvidenceAnchor~new(contract~sourceId, "CONTRACT", "clause 17", .nil, "PARTIES"))
  ok = self~assertTrue(gen~addAuthorityRule(choice)~ok, "choice-of-law relation added")
  ignored = gen~seal

  context = .LegalContext~new("CROSS-BORDER-DISPUTE", "2026-08-20")
  ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("ENGLAND", "ENGLAND", "CONTRACT", "party/performance connection"))
  ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "CONTRACT", "party/performance connection"))

  unbound = .LegalEffectEngine~new~evaluate(.LegalAction~new("INTERPRET_CONTRACT"), gen, context)
  ok = self~assertEqual("REVIEW_REQUIRED", unbound~value~status, "governing-law clause has no authority until contract is bound")
  ok = self~assertEqual(1, unbound~value~unresolvedConflicts~items, "both connected laws remain visible")

  ignored = context~bindSource(contract~sourceId, "transaction is party to CROSS-BORDER-CONTRACT")
  resolved = .LegalEffectEngine~new~evaluate(.LegalAction~new("INTERPRET_CONTRACT"), gen, context)
  ok = self~assertEqual("ADMISSIBLE", resolved~value~status, "bound choice-of-law relation resolves scoped conflict")
  ok = self~assertEqual(1, resolved~value~resolvedConflicts~items, "choice-of-law resolution recorded")
  ok = self~assertEqual("CHOICE_OF_LAW", resolved~value~resolvedConflicts[1]~authorityMatch~rule~relationType, "relation type retained")
  ok = self~assertEqual("ENGLISH_RULE_APPLIES", resolved~value~dispositions[1], "selected legal regime emits effective disposition")
  ok = self~assertEqual("CONTRACT-GOVERNING-LAW", resolved~value~resolvedConflicts[1]~authorityMatch~rule~ruleId, "governing clause remains provenance")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 CONFLICT OF LAWS: OK"
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
