/* Synthetic machine-queryable explanation demo. */
say "LEGAL EFFECT V0.14 DECISION TRACE QUERY DEMO"

statute = .NormativeSource~new("DEMO-ACT", "LEGISLATION", "Synthetic mandatory rule", "PARLIAMENT", "ENGLAND")
contract = .NormativeSource~new("DEMO-CONTRACT", "CONTRACT", "Synthetic contract", "PARTIES", "*", "English law")
gen = .LegalRuleGeneration~new("QUERY-DEMO", "0.14")
ignored = gen~addSource(statute)
ignored = gen~addSource(contract)

ban = .LegalNorm~new("ACT-BAN", statute~sourceId, "10", "PROHIBITION", "RATE_CHANGE", "PROHIBITED", "WORK", "mandatory floor", .nil, "*", "RATE_CHANGE")
ignored = ban~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
ignored = gen~addNorm(ban)
permission = .LegalNorm~new("CONTRACT-PERMIT", contract~sourceId, "4", "PERMISSION", "RATE_CHANGE", "PERMITTED", "WORK", "variation clause", .nil, "*", "RATE_CHANGE")
ignored = permission~addCondition(.LegalPredicate~new("RATE_CUT", "KNOWN_TRUE"))
ignored = gen~addNorm(permission)
priority = .LegalAuthorityRule~new("ACT-WINS", statute~sourceId, "11", statute~sourceId, contract~sourceId, "PREVAILS_OVER", "WORK", "RATE_CHANGE", .nil, "ACT-BAN", "CONTRACT-PERMIT", "mandatory rule")
ignored = priority~addCondition(.LegalPredicate~new("MANDATORY", "KNOWN_TRUE"))
ignored = gen~addAuthorityRule(priority)
ignored = gen~seal

facts = .LegalFactSet~new
ignored = facts~putKnown("MANDATORY", .true, .nil, "DEMO")
context = .LegalContext~new("QUERY-DEMO-EVENT", "2026-08-23", "2026-08-23", facts)
ignored = context~bindSource(contract~sourceId, "bound contract")
action = .LegalAction~new("RATE_CHANGE", "reduce rate")
ignored = action~setFact("RATE_CUT", .true)
assessment = .LegalEffectEngine~new~evaluate(action, gen, context)~value
query = .LegalDecisionTraceQuery~new

say "status=" assessment~status
controlling = query~controllingNorms(assessment~decisionTrace)~value
say "controlling_norms=" controlling~nodes~items
if controlling~nodes~items > 0 then say "controlling_norm=" controlling~nodes[1]~subjectId
suppressed = query~suppressedNorms(assessment~decisionTrace)~value
say "suppressed_norms=" suppressed~nodes~items
authority = query~authorityRules(assessment~decisionTrace)~value
say "authority_rules=" authority~nodes~items
changed = query~whatChanged(assessment~decisionTrace)~value
say "fact_mutations=" changed~metadata["FACT_MUTATIONS"]
say "applicability_changes=" changed~metadata["APPLICABILITY_CHANGES"]
say "query_identity_prefix=" controlling~queryIdentity~left(96)

::requires "LegalEffect.cls"
