say "LEGAL EFFECT V0.14 STRUCTURED DECISION TRACE START"
a = .LegalDecisionTraceAcceptance~new
exit a~run

::class LegalDecisionTraceAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  statute = .NormativeSource~new("TRACE-STATUTE", "LEGISLATION", "Synthetic mandatory wage rule", "PARLIAMENT", "ENGLAND")
  contract = .NormativeSource~new("TRACE-CONTRACT", "CONTRACT", "Synthetic variation clause", "PARTIES", "*", "English law")

  gen = .LegalRuleGeneration~new("TRACE-G1", "0.12")
  ignored = self~must(gen~addSource(statute), "statute source added")
  ignored = self~must(gen~addSource(contract), "contract source added")

  statNorm = .LegalNorm~new("STAT-N1", statute~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "mandatory synthetic floor", .nil, "*", "WAGE_CUT_LEGALITY")
  ignored = statNorm~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = statNorm~addEvidence(.LegalEvidenceAnchor~new(statute~sourceId, "LEGAL_PROVISION", "s.10", .nil, "PARLIAMENT"))
  contractNorm = .LegalNorm~new("CONTRACT-N1", contract~sourceId, "4", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
  ignored = contractNorm~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = contractNorm~addEvidence(.LegalEvidenceAnchor~new(contract~sourceId, "CONTRACT_CLAUSE", "clause 4", .nil, "PARTIES"))
  ignored = self~must(gen~addNorm(statNorm), "statute norm added")
  ignored = self~must(gen~addNorm(contractNorm), "contract norm added")

  priority = .LegalAuthorityRule~new("STATUTE-OVERRIDES-CONTRACT", statute~sourceId, "11", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK_RELATIONSHIP", "WAGE_CUT", .nil, "STAT-N1", "CONTRACT-N1", "mandatory rule cannot be derogated by this contract")
  ignored = priority~addCondition(.LegalPredicate~new("MANDATORY_RULE_ACTIVE", "KNOWN_TRUE"))
  ignored = priority~addEvidence(.LegalEvidenceAnchor~new(statute~sourceId, "LEGAL_PROVISION", "s.11", .nil, "PARLIAMENT"))
  ignored = self~must(gen~addAuthorityRule(priority), "authority rule added")
  ignored = gen~seal
  semanticBefore = gen~semanticIdentity

  facts = .LegalFactSet~new
  ignored = facts~putKnown("MANDATORY_RULE_ACTIVE", .true, .nil, "TEST")
  context = .LegalContext~new("TRACE-EVENT", "2026-08-23", "2026-08-23", facts)
  ignored = context~bindSource(contract~sourceId, "transaction is party-bound to contract")

  action = .LegalAction~new("WAGE_CUT", "reduce driver rate")
  ignored = action~setFact("RATE_CUT", .true)
  evalResult = .LegalEffectEngine~new~evaluate(action, gen, context)
  ignored = self~true(evalResult~ok, "evaluation succeeds")
  assessment = evalResult~value
  ignored = self~eq("BLOCKED", assessment~status, "resolved prohibition blocks action")
  ignored = self~eq(semanticBefore, gen~semanticIdentity, "trace generation does not change legal semantic identity")

  trace = assessment~decisionTrace
  ignored = self~true(trace \== .nil, "structured decision trace attached")
  ignored = self~true(trace~sealed, "decision trace sealed")
  ignored = self~eq("WAGE_CUT", trace~actionCode, "trace action code")
  ignored = self~eq("TRACE-G1", trace~generationId, "trace generation id")
  ignored = self~eq("TRACE-EVENT", trace~eventId, "trace event id")
  ignored = self~eq("BLOCKED", trace~status, "trace status")
  ignored = self~true(trace~nodes~items >= 13, "trace contains structured graph nodes")
  ignored = self~true(trace~edges~items >= 12, "trace contains causal edges")

  actionNode = trace~node("ACTION")
  mutationNode = trace~node("MUTATION::1::RATE_CUT")
  beforeStat = trace~node("NORM::BEFORE::STAT-N1")
  afterStat = trace~node("NORM::AFTER::STAT-N1")
  afterContract = trace~node("NORM::AFTER::CONTRACT-N1")
  conflictNode = trace~node("CONFLICT::WAGE_CUT_LEGALITY::CONTRACT-N1::STAT-N1::RESOLVED::WIN::STAT-N1::LOSE::CONTRACT-N1::AUTH::STATUTE-OVERRIDES-CONTRACT")
  dispositionNode = trace~node("DISPOSITION::PROHIBITED")
  statusNode = trace~node("STATUS::BLOCKED")
  ignored = self~true(actionNode \== .nil, "action node present")
  ignored = self~true(mutationNode \== .nil, "mutation node present")
  ignored = self~eq("UNRESOLVED", beforeStat~status, "before-action statute norm is unresolved until proposed fact is supplied")
  ignored = self~eq("APPLIES", afterStat~status, "after-action statute norm applies")
  ignored = self~eq("APPLIES", afterContract~status, "after-action contract norm applies before conflict resolution")
  ignored = self~eq(statute~sourceId, afterStat~sourceId, "effective norm retains source id")
  ignored = self~eq("10", afterStat~provisionId, "effective norm retains provision id")
  ignored = self~eq(1, afterStat~evidence~items, "effective norm retains provision evidence")
  ignored = self~eq("RESOLVED", conflictNode~status, "conflict node records resolution")
  ignored = self~true(dispositionNode \== .nil, "disposition node present")
  ignored = self~true(statusNode \== .nil, "final status node present")

  predicateNodes = trace~nodesByType("PREDICATE_EVALUATION")
  ignored = self~true(predicateNodes~items >= 3, "predicate evaluations are structured nodes")
  ratePred = self~findPredicate(predicateNodes, "AFTER", "RATE_CUT", "CONDITION", "TRUE")
  ignored = self~true(ratePred \== .nil, "prospective RATE_CUT predicate retained")
  rateAttrs = ratePred~attributes
  ignored = self~eq("KNOWN", rateAttrs["FACT_STATE"], "predicate records fact state")
  ignored = self~eq("PROPOSED_ACTION", rateAttrs["FACT_AUTHORITY"], "predicate records proposed-action authority")

  statMatch = assessment~afterMatches[2]
  if statMatch~norm~normId <> "STAT-N1" then statMatch = assessment~afterMatches[1]
  ignored = self~eq(1, statMatch~predicateEvaluations~items, "norm match retains structured predicate evaluation")
  ignored = self~eq("TRUE", statMatch~predicateEvaluations[1]~result, "norm predicate result retained")
  conflict = assessment~resolvedConflicts[1]
  ignored = self~eq(1, conflict~authorityMatch~predicateEvaluations~items, "authority match retains structured predicate evaluation")
  ignored = self~eq("MANDATORY_RULE_ACTIVE", conflict~authorityMatch~predicateEvaluations[1]~factName, "authority predicate fact retained")

  ignored = self~true(self~edgeExists(trace, "MUTATION::1::RATE_CUT", "SUPPLIES_PROPOSED_FACT", ratePred~nodeId), "mutation causally supplies prospective fact")
  ignored = self~true(self~edgeExists(trace, conflictNode~nodeId, "SELECTS", "NORM::AFTER::STAT-N1"), "conflict selects winning norm")
  ignored = self~true(self~edgeExists(trace, conflictNode~nodeId, "SUPPRESSES", "NORM::AFTER::CONTRACT-N1"), "conflict suppresses losing norm")
  ignored = self~true(self~edgeExists(trace, "NORM::AFTER::STAT-N1", "PRODUCES_DISPOSITION", "DISPOSITION::PROHIBITED"), "winning norm produces prohibition")
  ignored = self~true(self~edgeExists(trace, "DISPOSITION::PROHIBITED", "CONTRIBUTES_TO_STATUS", "STATUS::BLOCKED"), "prohibition contributes to blocked status")

  causes = trace~whyFinalStatus
  ignored = self~true(self~nodePresent(causes, "ACTION"), "causal closure includes proposed action")
  ignored = self~true(self~nodePresent(causes, "MUTATION::1::RATE_CUT"), "causal closure includes proposed fact mutation")
  ignored = self~true(self~nodePresent(causes, "NORM::AFTER::STAT-N1"), "causal closure includes winning norm")
  ignored = self~true(self~nodePresent(causes, conflictNode~nodeId), "causal closure includes conflict resolution")
  ignored = self~true(self~nodeTypePresent(causes, "AUTHORITY_RULE"), "causal closure includes controlling authority rule")
  ignored = self~true(self~nodePresent(causes, "STATUS::BLOCKED"), "causal closure includes final status")

  identity1 = trace~traceIdentity
  evalAgain = .LegalEffectEngine~new~evaluate(action, gen, context)
  ignored = self~true(evalAgain~ok, "repeat evaluation succeeds")
  identity2 = evalAgain~value~decisionTrace~traceIdentity
  ignored = self~eq(identity1, identity2, "same legal inputs produce identical structured trace identity")

  reordered = .LegalRuleGeneration~new("TRACE-G1", "0.12")
  ignored = reordered~addSource(contract)
  ignored = reordered~addSource(statute)
  ignored = reordered~addNorm(contractNorm)
  ignored = reordered~addNorm(statNorm)
  ignored = reordered~addAuthorityRule(priority)
  ignored = reordered~seal
  ignored = self~eq(gen~semanticIdentity, reordered~semanticIdentity, "semantic identity is insertion-order independent")
  reorderedEval = .LegalEffectEngine~new~evaluate(action, reordered, context)
  ignored = self~true(reorderedEval~ok, "reordered generation evaluation succeeds")
  ignored = self~eq("BLOCKED", reorderedEval~value~status, "reordered generation has same outcome")
  ignored = self~eq(identity1, reorderedEval~value~decisionTrace~traceIdentity, "structured trace identity is insertion-order independent")

  detachedNodes = trace~nodes
  detachedNodes~append(.nil)
  ignored = self~true(trace~nodes~items < detachedNodes~items, "node collection is copy-on-read")
  detachedEdges = trace~edges
  detachedEdges~append(.nil)
  ignored = self~true(trace~edges~items < detachedEdges~items, "edge collection is copy-on-read")
  lateNode = .LegalDecisionTraceNode~new("LATE", "TEST")
  ignored = self~eq("DECISION_TRACE_SEALED", trace~addNode(lateNode)~code, "sealed trace rejects late node mutation")
  ignored = self~eq("DECISION_TRACE_ALREADY_SET", assessment~setDecisionTrace(trace)~code, "assessment trace binding is one-shot")
  ignored = self~true(assessment~trace~items > 0, "legacy string trace remains available")

  unresolvedGen = .LegalRuleGeneration~new("TRACE-G2", "0.12")
  ignored = unresolvedGen~addSource(statute)
  ignored = unresolvedGen~addSource(contract)
  stat2 = .LegalNorm~new("STAT-U", statute~sourceId, "20", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "mandatory", .nil, "*", "UNRESOLVED_KEY")
  contract2 = .LegalNorm~new("CONTRACT-U", contract~sourceId, "20", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "contract", .nil, "*", "UNRESOLVED_KEY")
  ignored = unresolvedGen~addNorm(stat2)
  ignored = unresolvedGen~addNorm(contract2)
  ignored = unresolvedGen~seal
  unresolvedContext = .LegalContext~new("TRACE-UNRESOLVED", "2026-08-23")
  ignored = unresolvedContext~bindSource(contract~sourceId, "party")
  unresolvedEval = .LegalEffectEngine~new~evaluate(.LegalAction~new("WAGE_CUT"), unresolvedGen, unresolvedContext)
  ignored = self~eq("REVIEW_REQUIRED", unresolvedEval~value~status, "unresolved conflict remains review-required")
  unresolvedTrace = unresolvedEval~value~decisionTrace
  ignored = self~eq(1, unresolvedTrace~nodesByType("NORM_CONFLICT")~items, "unresolved conflict represented structurally")
  ignored = self~true(self~nodeTypePresent(unresolvedTrace~whyFinalStatus, "NORM_CONFLICT"), "review explanation includes unresolved conflict")

  builder = .LegalDecisionTraceBuilder~new
  ci = builder~legalComponentIdentity
  ignored = self~eq("LEGALDECISIONTRACEBUILDER", ci["class"]~string~upper, "trace builder uses Alchemy operational base")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 STRUCTURED DECISION TRACE: OK"
  return 0

::method findPredicate private
  use arg nodes, phase, factName, role, result
  do node over nodes
    if node~phase <> phase then iterate
    attrs = node~attributes
    if attrs["FACT_NAME"] <> factName then iterate
    if attrs["ROLE"] <> role then iterate
    if attrs["RESULT"] <> result then iterate
    return node
  end
  return .nil

::method edgeExists private
  use arg trace, fromId, relationType, toId
  do edge over trace~edges
    if edge~fromId <> fromId~string~upper then iterate
    if edge~relationType <> relationType~string~upper then iterate
    if edge~toId <> toId~string~upper then iterate
    return .true
  end
  return .false

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
