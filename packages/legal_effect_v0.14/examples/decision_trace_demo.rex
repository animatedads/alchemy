/* Synthetic demonstration only.  These are not statements of real law. */
statute = .NormativeSource~new("DEMO-ACT", "LEGISLATION", "Synthetic mandatory rule", "DEMO_PARLIAMENT", "DEMO")
contract = .NormativeSource~new("DEMO-CONTRACT", "CONTRACT", "Synthetic private agreement", "DEMO_PARTIES", "*")

gen = .LegalRuleGeneration~new("TRACE-DEMO", "0.12")
ignored = gen~addSource(statute)
ignored = gen~addSource(contract)

statNorm = .LegalNorm~new("ACT-12", statute~sourceId, "12", "PROHIBITION", "RATE_CUT", "PROHIBITED", "WORK", "mandatory synthetic floor", .nil, "*", "RATE_CUT_CONFLICT")
ignored = statNorm~addCondition(.LegalPredicate~new("RATE_REDUCED", "KNOWN_TRUE"))
ignored = statNorm~addEvidence(.LegalEvidenceAnchor~new(statute~sourceId, "LEGAL_PROVISION", "s.12", .nil, "DEMO_PARLIAMENT"))
contractNorm = .LegalNorm~new("CONTRACT-7", contract~sourceId, "7", "PERMISSION", "RATE_CUT", "PERMITTED", "WORK", "synthetic variation permission", .nil, "*", "RATE_CUT_CONFLICT")
ignored = contractNorm~addCondition(.LegalPredicate~new("RATE_REDUCED", "KNOWN_TRUE"))
ignored = contractNorm~addEvidence(.LegalEvidenceAnchor~new(contract~sourceId, "CONTRACT_CLAUSE", "clause 7", .nil, "DEMO_PARTIES"))
ignored = gen~addNorm(statNorm)
ignored = gen~addNorm(contractNorm)

priority = .LegalAuthorityRule~new("ACT-NON-DEROGATION", statute~sourceId, "13", statute~sourceId, contract~sourceId, "NON_DEROGATION", "WORK", "RATE_CUT", .nil, "ACT-12", "CONTRACT-7", "synthetic mandatory provision controls")
ignored = gen~addAuthorityRule(priority)
ignored = gen~seal

context = .LegalContext~new("DEMO-EVENT", "2026-08-23")
ignored = context~bindSource(contract~sourceId, "demo transaction bound to private agreement")
action = .LegalAction~new("RATE_CUT", "reduce a contractual rate")
ignored = action~setFact("RATE_REDUCED", .true)

result = .LegalEffectEngine~new~evaluate(action, gen, context)
if \result~ok then do
  say "evaluation failed:" result~code result~detail
  exit 1
end
assessment = result~value
trace = assessment~decisionTrace
say "status=" || assessment~status
say "dispositions=" || assessment~dispositions~items
say "trace_nodes=" || trace~nodes~items
say "trace_edges=" || trace~edges~items
say "trace_identity_prefix=" || trace~traceIdentity~left(80) || "..."
say "why="
do node over trace~whyFinalStatus
  say "  " || node~nodeType || " | " || node~phase || " | " || node~status || " | " || node~subjectId
end
exit 0

::requires "LegalEffect.cls"
