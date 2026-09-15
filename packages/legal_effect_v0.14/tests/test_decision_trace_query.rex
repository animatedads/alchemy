say "LEGAL EFFECT V0.14 DECISION TRACE QUERY START"
a = .LegalDecisionTraceQueryAcceptance~new
exit a~run

::class LegalDecisionTraceQueryAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  statute = .NormativeSource~new("QUERY-STATUTE", "LEGISLATION", "Synthetic mandatory wage rule", "PARLIAMENT", "ENGLAND")
  contract = .NormativeSource~new("QUERY-CONTRACT", "CONTRACT", "Synthetic variation clause", "PARTIES", "*", "English law")

  gen = .LegalRuleGeneration~new("QUERY-G1", "0.14")
  ignored = self~must(gen~addSource(statute), "statute source added")
  ignored = self~must(gen~addSource(contract), "contract source added")

  statNorm = .LegalNorm~new("STAT-Q1", statute~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "mandatory synthetic floor", .nil, "*", "WAGE_CUT_LEGALITY")
  ignored = statNorm~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = statNorm~addEvidence(.LegalEvidenceAnchor~new(statute~sourceId, "LEGAL_PROVISION", "s.10", .nil, "PARLIAMENT"))
  contractNorm = .LegalNorm~new("CONTRACT-Q1", contract~sourceId, "4", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
  ignored = contractNorm~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = contractNorm~addEvidence(.LegalEvidenceAnchor~new(contract~sourceId, "CONTRACT_CLAUSE", "clause 4", .nil, "PARTIES"))
  ignored = self~must(gen~addNorm(statNorm), "statute norm added")
  ignored = self~must(gen~addNorm(contractNorm), "contract norm added")

  priority = .LegalAuthorityRule~new("STATUTE-OVERRIDES-QCONTRACT", statute~sourceId, "11", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK_RELATIONSHIP", "WAGE_CUT", .nil, "STAT-Q1", "CONTRACT-Q1", "mandatory rule cannot be derogated")
  ignored = priority~addCondition(.LegalPredicate~new("MANDATORY_RULE_ACTIVE", "KNOWN_TRUE"))
  ignored = priority~addEvidence(.LegalEvidenceAnchor~new(statute~sourceId, "LEGAL_PROVISION", "s.11", .nil, "PARLIAMENT"))
  ignored = self~must(gen~addAuthorityRule(priority), "authority rule added")
  ignored = gen~seal

  facts = .LegalFactSet~new
  ignored = facts~putKnown("MANDATORY_RULE_ACTIVE", .true, .nil, "TEST")
  context = .LegalContext~new("QUERY-EVENT", "2026-08-23", "2026-08-23", facts)
  ignored = context~bindSource(contract~sourceId, "transaction is party-bound")
  action = .LegalAction~new("WAGE_CUT", "reduce driver rate")
  ignored = action~setFact("RATE_CUT", .true)
  evalResult = .LegalEffectEngine~new~evaluate(action, gen, context)
  ignored = self~true(evalResult~ok, "resolved evaluation succeeds")
  trace = evalResult~value~decisionTrace
  query = .LegalDecisionTraceQuery~new

  whyResult = query~whyFinalStatus(trace)
  ignored = self~true(whyResult~ok, "why-final-status query succeeds")
  why = whyResult~value
  ignored = self~eq("WHY_FINAL_STATUS", why~queryType, "why query type")
  ignored = self~true(self~nodePresent(why~nodes, "STATUS::BLOCKED"), "why result contains final status")
  ignored = self~true(self~nodePresent(why~nodes, "NORM::AFTER::STAT-Q1"), "why result contains winning norm")
  ignored = self~true(self~nodeTypePresent(why~nodes, "AUTHORITY_RULE"), "why result contains authority rule")
  ignored = self~true(why~edges~items > 0, "why result retains causal edges")

  controllingResult = query~controllingNorms(trace)
  ignored = self~true(controllingResult~ok, "controlling-norm query succeeds")
  controlling = controllingResult~value
  ignored = self~eq(1, controlling~nodes~items, "one norm controls final disposition")
  ignored = self~eq("STAT-Q1", controlling~nodes[1]~subjectId, "statutory norm controls result")

  suppressedResult = query~suppressedNorms(trace)
  ignored = self~true(suppressedResult~ok, "suppressed-norm query succeeds")
  suppressed = suppressedResult~value
  ignored = self~eq(1, suppressed~nodes~items, "one norm suppressed")
  ignored = self~eq("CONTRACT-Q1", suppressed~nodes[1]~subjectId, "contract norm is suppressed")
  ignored = self~eq(1, suppressed~edges~items, "suppression relation retained")
  ignored = self~eq("SUPPRESSES", suppressed~edges[1]~relationType, "suppression edge typed")

  authorityResult = query~authorityRules(trace)
  ignored = self~true(authorityResult~ok, "authority-rule query succeeds")
  authority = authorityResult~value
  ignored = self~eq(1, authority~nodes~items, "one authority rule controls conflict")
  ignored = self~eq("STATUTE-OVERRIDES-QCONTRACT", authority~nodes[1]~subjectId, "correct authority rule returned")

  changedResult = query~whatChanged(trace)
  ignored = self~true(changedResult~ok, "what-changed query succeeds")
  changed = changedResult~value
  changedMeta = changed~metadata
  ignored = self~eq(1, changedMeta["FACT_MUTATIONS"], "one proposed fact mutation")
  ignored = self~true(changedMeta["APPLICABILITY_CHANGES"] >= 2, "applicability changes retained")
  ignored = self~true(self~nodeTypePresent(changed~nodes, "FACT_MUTATION"), "what-changed contains fact mutation")
  ignored = self~true(self~edgeRelationPresent(changed~edges, "BECOMES_APPLICABLE"), "what-changed contains applicability edge")

  anchorsResult = query~sourceAnchors(trace)
  ignored = self~true(anchorsResult~ok, "source-anchor query succeeds")
  anchors = anchorsResult~value
  ignored = self~true(self~sourceProvisionPresent(anchors~nodes, statute~sourceId, "10"), "winning source/provision retained")
  ignored = self~true(self~sourceProvisionPresent(anchors~nodes, statute~sourceId, "11"), "authority source/provision retained")
  ignored = self~true(self~sourceProvisionPresent(anchors~nodes, contract~sourceId, "4"), "suppressed contract source remains auditable")

  identity1 = controlling~queryIdentity
  controllingAgain = query~controllingNorms(trace)~value
  ignored = self~eq(identity1, controllingAgain~queryIdentity, "same query over same trace has stable identity")
  detached = controlling~nodes
  detached~append(.nil)
  ignored = self~true(controlling~nodes~items < detached~items, "query result node collection is copy-on-read")

  reviewSource = .NormativeSource~new("QUERY-REVIEW-ACT", "LEGISLATION", "Synthetic licence rule", "PARLIAMENT", "ENGLAND")
  reviewGen = .LegalRuleGeneration~new("QUERY-G2", "0.14")
  ignored = reviewGen~addSource(reviewSource)
  reviewNorm = .LegalNorm~new("REVIEW-Q1", reviewSource~sourceId, "20", "PROHIBITION", "SHIP_GOODS", "PROHIBITED", "LICENSING", "shipment requires known licence state")
  ignored = reviewNorm~addCondition(.LegalPredicate~new("LICENCE_ACTIVE", "KNOWN_TRUE"))
  ignored = reviewNorm~addEvidence(.LegalEvidenceAnchor~new(reviewSource~sourceId, "LEGAL_PROVISION", "s.20", .nil, "PARLIAMENT"))
  ignored = reviewGen~addNorm(reviewNorm)
  ignored = reviewGen~seal
  reviewEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("SHIP_GOODS"), reviewGen, .LegalContext~new("QUERY-REVIEW", "2026-08-23"))
  ignored = self~true(reviewEval~ok, "review-required evaluation succeeds")
  ignored = self~eq("REVIEW_REQUIRED", reviewEval~value~status, "unknown licence state requires review")
  reviewResult = query~reviewInputs(reviewEval~value~decisionTrace)
  ignored = self~true(reviewResult~ok, "review-input query succeeds")
  reviewInputs = reviewResult~value
  reviewMeta = reviewInputs~metadata
  ignored = self~eq(.false, reviewMeta["GUARANTEED_OUTCOME_FLIP"], "review input does not pretend to predict a flip")
  ignored = self~eq("NONE", reviewMeta["COUNTERFACTUAL_PREDICTION"], "review input performs no hidden counterfactual")
  ignored = self~true(self~predicateFactPresent(reviewInputs~nodes, "LICENCE_ACTIVE", "UNKNOWN"), "unknown licence predicate identified")
  ignored = self~true(self~nodePresent(reviewInputs~nodes, "NORM::AFTER::REVIEW-Q1"), "unresolved norm identified")

  noReview = query~reviewInputs(trace)
  ignored = self~true(noReview~ok, "review-input query works on determinate decision")
  ignored = self~eq(0, noReview~value~nodes~items, "determinate decision has no review inputs")

  ci = query~legalComponentIdentity
  ignored = self~eq("LEGALDECISIONTRACEQUERY", ci["class"]~string~upper, "query service uses Alchemy operational base")
  ignored = self~eq("0.14", ci["package_version"], "query operational identity carries package version")
  ignored = self~eq("legal.effect/0.10", ci["legal_api"], "query addition preserves legal runtime API")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 DECISION TRACE QUERY: OK"
  return 0

::method nodePresent private
  use arg nodes, wantedId
  wanted = wantedId~string~upper
  do node over nodes
    if node~nodeId = wanted then return .true
  end
  return .false

::method nodeTypePresent private
  use arg nodes, wantedType
  wanted = wantedType~string~upper
  do node over nodes
    if node~nodeType = wanted then return .true
  end
  return .false

::method edgeRelationPresent private
  use arg edges, wantedRelation
  wanted = wantedRelation~string~upper
  do edge over edges
    if edge~relationType = wanted then return .true
  end
  return .false

::method sourceProvisionPresent private
  use arg nodes, sourceId, provisionId
  do node over nodes
    if node~sourceId <> sourceId then iterate
    if node~provisionId <> provisionId then iterate
    return .true
  end
  return .false

::method predicateFactPresent private
  use arg nodes, factName, result
  do node over nodes
    if node~nodeType <> "PREDICATE_EVALUATION" then iterate
    attrs = node~attributes
    if attrs["FACT_NAME"] <> factName then iterate
    if attrs["RESULT"] <> result then iterate
    return .true
  end
  return .false

::method must private
  expose assertions
  use arg legalResult, label
  assertions += 1
  if legalResult == .nil then raise syntax 88.900 array(label || ": missing LegalResult")
  if \legalResult~ok then raise syntax 88.900 array(label || ": " || legalResult~code || " " || legalResult~detail)
  return legalResult~value

::method true private
  expose assertions
  use arg condition, label
  assertions += 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method eq private
  expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERTION FAILED:" label
    say " expected=" expected
    say " actual=" actual
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalEffect.cls"
