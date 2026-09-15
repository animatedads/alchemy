say "LEGAL EFFECT V0.14 COUNTERFACTUAL EVALUATION START"
a = .LegalCounterfactualAcceptance~new
exit a~run

::class LegalCounterfactualAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  evaluator = .LegalCounterfactualEvaluator~new

  /* Unknown licence state: only actual re-evaluation may tell us the branch. */
  source = .NormativeSource~new("CF-LICENCE-ACT", "LEGISLATION", "Synthetic licence rule", "PARLIAMENT", "ENGLAND")
  gen = .LegalRuleGeneration~new("CF-G1", "0.14")
  ignored = self~must(gen~addSource(source), "licence source added")
  norm = .LegalNorm~new("CF-LICENCE-NORM", source~sourceId, "20", "PROHIBITION", "SHIP_GOODS", "PROHIBITED", "LICENSING", "active licence forbids this synthetic shipment")
  ignored = norm~addCondition(.LegalPredicate~new("LICENCE_ACTIVE", "KNOWN_TRUE"))
  ignored = norm~addEvidence(.LegalEvidenceAnchor~new(source~sourceId, "LEGAL_PROVISION", "s.20", .nil, "PARLIAMENT"))
  ignored = self~must(gen~addNorm(norm), "licence norm added")
  ignored = gen~seal
  context = .LegalContext~new("CF-EVENT", "2026-08-24")
  action = .LegalAction~new("SHIP_GOODS", "ship regulated goods")
  baseResult = .LegalEffectEngine~new~evaluate(action, gen, context)
  ignored = self~true(baseResult~ok, "base evaluation succeeds")
  base = baseResult~value
  ignored = self~eq("REVIEW_REQUIRED", base~status, "unknown licence is review-required")
  baseIdentity = base~decisionTrace~traceIdentity

  trueResult = evaluator~evaluateFact(base, "LICENCE_ACTIVE", .true)
  ignored = self~true(trueResult~ok, "true counterfactual succeeds")
  trueCf = trueResult~value
  ignored = self~eq(.true, trueCf~hypothetical, "counterfactual is labelled hypothetical")
  ignored = self~eq(.false, trueCf~authoritative, "counterfactual is never authority")
  ignored = self~eq("REVIEW_REQUIRED", trueCf~baseStatus, "base status retained")
  ignored = self~eq("BLOCKED", trueCf~counterfactualStatus, "known true branch is deterministically blocked")
  ignored = self~eq(.true, trueCf~statusChanged, "true branch changes status")
  ignored = self~eq(.true, trueCf~legallyMaterial, "true branch is legally material")
  ignored = self~contains(trueCf~addedDispositions, "PROHIBITED", "true branch adds prohibited disposition")
  ignored = self~contains(trueCf~addedControllingNorms, "CF-LICENCE-NORM", "true branch adds controlling norm")
  ignored = self~eq("COUNTERFACTUAL_ASSUMPTION", trueCf~assumption~authority, "assumption authority cannot masquerade as evidence")
  ignored = self~eq("KNOWN", trueCf~assumption~state, "assumption state retained")
  ignored = self~eq(.true, trueCf~assumption~value, "assumption value retained")
  ignored = self~eq("CONTEXT", trueCf~assumption~scope, "review-input counterfactual defaults to context scope")
  ignored = self~true(self~predicateAuthorityPresent(trueCf~counterfactualTrace~nodes, "LICENCE_ACTIVE", "COUNTERFACTUAL_ASSUMPTION"), "context assumption authority is visible in predicate trace")
  ignored = self~eq("BLOCKED", trueCf~counterfactualTrace~status, "counterfactual trace exposes actual alternate evaluation")
  ignored = self~eq(baseIdentity, base~decisionTrace~traceIdentity, "base trace is not mutated by counterfactual evaluation")

  falseResult = evaluator~evaluateFact(base, "LICENCE_ACTIVE", .false)
  ignored = self~true(falseResult~ok, "false counterfactual succeeds")
  falseCf = falseResult~value
  ignored = self~eq("ADMISSIBLE", falseCf~counterfactualStatus, "known false branch is deterministically admissible")
  ignored = self~eq(.true, falseCf~statusChanged, "false branch changes status")
  ignored = self~eq(0, falseCf~counterfactualDispositions~items, "false branch has no effective dispositions")
  ignored = self~eq(0, falseCf~counterfactualControllingNorms~items, "false branch has no controlling norm")

  branchesResult = evaluator~evaluateBoolean(base, "LICENCE_ACTIVE")
  ignored = self~true(branchesResult~ok, "boolean branch evaluation succeeds")
  branches = branchesResult~value
  ignored = self~eq(.true, branches~hypothetical, "branch set is hypothetical")
  ignored = self~eq(.false, branches~authoritative, "branch set is non-authoritative")
  ignored = self~eq(2, branches~comparisons~items, "boolean branch set contains two actual evaluations")
  ignored = self~eq("ADMISSIBLE", branches~comparisons[1]~counterfactualStatus, "false branch is canonical first branch")
  ignored = self~eq("BLOCKED", branches~comparisons[2]~counterfactualStatus, "true branch is second branch")
  sameBranches = evaluator~evaluateBoolean(base, "LICENCE_ACTIVE")~value
  ignored = self~eq(branches~setIdentity, sameBranches~setIdentity, "same two branch evaluations have stable identity")

  trueAgain = evaluator~evaluateFact(base, "LICENCE_ACTIVE", .true)~value
  ignored = self~eq(trueCf~counterfactualIdentity, trueAgain~counterfactualIdentity, "same fact counterfactual has stable identity")
  detached = trueCf~addedDispositions
  detached~append("FAKE")
  ignored = self~eq(1, trueCf~addedDispositions~items, "counterfactual arrays are copy-on-read")

  /* Existing candidate mutation can be explicitly overridden for sensitivity. */
  cutSource = .NormativeSource~new("CF-WAGE-ACT", "LEGISLATION", "Synthetic wage rule", "PARLIAMENT", "ENGLAND")
  cutGen = .LegalRuleGeneration~new("CF-G2", "0.14")
  ignored = cutGen~addSource(cutSource)
  cutNorm = .LegalNorm~new("CF-WAGE-NORM", cutSource~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK", "rate cut blocked")
  ignored = cutNorm~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = cutNorm~addEvidence(.LegalEvidenceAnchor~new(cutSource~sourceId, "LEGAL_PROVISION", "s.10", .nil, "PARLIAMENT"))
  ignored = cutGen~addNorm(cutNorm)
  ignored = cutGen~seal
  cutAction = .LegalAction~new("WAGE_CUT")
  ignored = cutAction~setFact("RATE_CUT", .true)
  cutBaseResult = .LegalEffectEngine~new~evaluate(cutAction, cutGen, .LegalContext~new("CF-CUT", "2026-08-24"))
  ignored = self~true(cutBaseResult~ok, "rate-cut base evaluation succeeds")
  ignored = self~eq("BLOCKED", cutBaseResult~value~status, "rate-cut base blocked")
  cutFalseResult = evaluator~evaluateFact(cutBaseResult~value, "RATE_CUT", .false, "KNOWN", "ACTION_OVERRIDE")
  ignored = self~true(cutFalseResult~ok, "counterfactual overrides original action fact")
  cutFalse = cutFalseResult~value
  ignored = self~eq("ACTION_OVERRIDE", cutFalse~assumption~scope, "action fact sensitivity is explicitly action-scoped")
  ignored = self~eq("ADMISSIBLE", cutFalse~counterfactualStatus, "override removes rate-cut prohibition")
  ignored = self~contains(cutFalse~removedDispositions, "PROHIBITED", "override records removed prohibited disposition")
  ignored = self~contains(cutFalse~removedControllingNorms, "CF-WAGE-NORM", "override records removed controlling norm")

  cutTrueResult = evaluator~evaluateFact(cutBaseResult~value, "RATE_CUT", .true, "KNOWN", "ACTION_OVERRIDE")
  ignored = self~true(cutTrueResult~ok, "same-value counterfactual succeeds")
  cutTrue = cutTrueResult~value
  ignored = self~eq("BLOCKED", cutTrue~counterfactualStatus, "same-value counterfactual preserves status")
  ignored = self~eq(.false, cutTrue~statusChanged, "same-value counterfactual does not report status change")
  ignored = self~eq(.false, cutTrue~legallyMaterial, "extra hypothetical trace mutation alone is not a legal-materiality change")

  /* Conflict sensitivity: authority fact changes the conflict result. */
  contract = .NormativeSource~new("CF-CONTRACT", "CONTRACT", "Synthetic contract", "PARTIES", "*", "English law")
  conflictGen = .LegalRuleGeneration~new("CF-G3", "0.14")
  ignored = conflictGen~addSource(cutSource)
  ignored = conflictGen~addSource(contract)
  stat = .LegalNorm~new("CF-STAT", cutSource~sourceId, "10", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK", "mandatory rule", .nil, "*", "CF-WAGE")
  ignored = stat~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = stat~addEvidence(.LegalEvidenceAnchor~new(cutSource~sourceId, "LEGAL_PROVISION", "s.10", .nil, "PARLIAMENT"))
  con = .LegalNorm~new("CF-CON", contract~sourceId, "4", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK", "variation allowed", .nil, "*", "CF-WAGE")
  ignored = con~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
  ignored = con~addEvidence(.LegalEvidenceAnchor~new(contract~sourceId, "CONTRACT_CLAUSE", "clause 4", .nil, "PARTIES"))
  ignored = conflictGen~addNorm(stat)
  ignored = conflictGen~addNorm(con)
  rule = .LegalAuthorityRule~new("CF-AUTH", cutSource~sourceId, "11", cutSource~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK", "WAGE_CUT", .nil, "CF-STAT", "CF-CON", "mandatory rule wins")
  ignored = rule~addCondition(.LegalPredicate~new("MANDATORY_RULE_ACTIVE", "KNOWN_TRUE"))
  ignored = rule~addEvidence(.LegalEvidenceAnchor~new(cutSource~sourceId, "LEGAL_PROVISION", "s.11", .nil, "PARLIAMENT"))
  ignored = conflictGen~addAuthorityRule(rule)
  ignored = conflictGen~seal
  cfFacts = .LegalFactSet~new
  ignored = cfFacts~putKnown("MANDATORY_RULE_ACTIVE", .true, .nil, "TEST")
  cfContext = .LegalContext~new("CF-CONFLICT", "2026-08-24", "2026-08-24", cfFacts)
  ignored = cfContext~bindSource(contract~sourceId, "transaction bound contract")
  cfAction = .LegalAction~new("WAGE_CUT")
  ignored = cfAction~setFact("RATE_CUT", .true)
  cfBase = .LegalEffectEngine~new~evaluate(cfAction, conflictGen, cfContext)
  ignored = self~true(cfBase~ok, "conflict base evaluation succeeds")
  ignored = self~eq("BLOCKED", cfBase~value~status, "authority-resolved base is blocked")
  noAuthority = evaluator~evaluateFact(cfBase~value, "MANDATORY_RULE_ACTIVE", .false)
  ignored = self~true(noAuthority~ok, "authority counterfactual succeeds")
  noAuth = noAuthority~value
  ignored = self~eq("REVIEW_REQUIRED", noAuth~counterfactualStatus, "removing authority condition exposes unresolved conflict")
  ignored = self~true(noAuth~addedConflicts~items > 0, "counterfactual records changed conflict result")
  ignored = self~true(noAuth~removedConflicts~items > 0, "resolved conflict identity is removed")
  ignored = self~true(noAuth~addedSourceAnchors~items > 0 | noAuth~removedSourceAnchors~items > 0, "counterfactual records source-anchor closure change")

  /* UNKNOWN is an explicit tested branch, not a hidden guess. */
  unknownResult = evaluator~evaluateFact(cutBaseResult~value, "RATE_CUT", .nil, "UNKNOWN", "ACTION_OVERRIDE")
  ignored = self~true(unknownResult~ok, "explicit UNKNOWN counterfactual succeeds")
  ignored = self~eq("REVIEW_REQUIRED", unknownResult~value~counterfactualStatus, "unknown override is evaluated, not predicted")

  invalidState = evaluator~evaluateFact(base, "LICENCE_ACTIVE", .nil, "MAYBE")
  ignored = self~eq(.false, invalidState~ok, "invalid counterfactual state rejected")
  ignored = self~eq("COUNTERFACTUAL_STATE_INVALID", invalidState~code, "invalid state diagnostic")
  emptyFact = evaluator~evaluateFact(base, "", .true)
  ignored = self~eq(.false, emptyFact~ok, "empty fact name rejected")
  ignored = self~eq("COUNTERFACTUAL_FACT_REQUIRED", emptyFact~code, "empty fact diagnostic")
  invalidScope = evaluator~evaluateFact(base, "LICENCE_ACTIVE", .true, "KNOWN", "PAST")
  ignored = self~eq(.false, invalidScope~ok, "invalid counterfactual scope rejected")
  ignored = self~eq("COUNTERFACTUAL_SCOPE_INVALID", invalidScope~code, "invalid scope diagnostic")

  ci = evaluator~legalComponentIdentity
  ignored = self~eq("LEGALCOUNTERFACTUALEVALUATOR", ci["class"]~string~upper, "counterfactual evaluator uses Alchemy operational base")
  ignored = self~eq("0.14", ci["package_version"], "counterfactual evaluator carries package version")
  ignored = self~eq("legal.effect/0.10", ci["legal_api"], "counterfactual feature preserves legal runtime API")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 COUNTERFACTUAL EVALUATION: OK"
  return 0

::method predicateAuthorityPresent private
  use arg nodes, factName, authority
  do node over nodes
    if node~nodeType <> "PREDICATE_EVALUATION" then iterate
    attrs = node~attributes
    if attrs["FACT_NAME"] <> factName then iterate
    if attrs["FACT_AUTHORITY"] = authority then return .true
  end
  return .false

::method contains private
  expose assertions
  use arg items, wanted, label
  assertions += 1
  do item over items
    if item == wanted then return .true
  end
  raise syntax 88.900 array(label || ": missing " || wanted)

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
