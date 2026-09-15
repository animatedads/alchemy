say "LEGAL EFFECT V0.14 AUTHORITY / CONFLICT SYNTHETIC DEMO"
say
statute = .NormativeSource~new("DELIVERY-ACT", "LEGISLATION", "Synthetic mandatory delivery rule", "PARLIAMENT", "ENGLAND")
contract = .NormativeSource~new("DRIVER-CONTRACT", "CONTRACT", "Synthetic driver contract", "PARTIES", "*", "ENGLAND")

gen = .LegalRuleGeneration~new("DEMO-AUTH-G1", "0.3")
ignored = gen~addSource(statute)
ignored = gen~addSource(contract)
statNorm = .LegalNorm~new("ACT-12", statute~sourceId, "12", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "synthetic mandatory rule", .nil, "*", "WAGE_CUT_LEGALITY")
contractNorm = .LegalNorm~new("CONTRACT-7", contract~sourceId, "7", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "synthetic variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
ignored = gen~addNorm(statNorm)
ignored = gen~addNorm(contractNorm)
ignored = gen~seal

context = .LegalContext~new("DELIVERY-WAGE-CUT", "2026-08-20")
ignored = context~bindSource(contract~sourceId, "driver is party")
action = .LegalAction~new("WAGE_CUT")
first = .LegalEffectEngine~new~evaluate(action, gen, context)~value
say "Both norms apply, but no authority relation is loaded:"
say "  status=" || first~status || " unresolved_conflicts=" || first~unresolvedConflicts~items || " effective_dispositions=" || first~dispositions~items
say

gen2 = .LegalRuleGeneration~new("DEMO-AUTH-G2", "0.3")
statute2 = .NormativeSource~new("DELIVERY-ACT", "LEGISLATION", "Synthetic mandatory delivery rule", "PARLIAMENT", "ENGLAND")
contract2 = .NormativeSource~new("DRIVER-CONTRACT", "CONTRACT", "Synthetic driver contract", "PARTIES", "*", "ENGLAND")
ignored = gen2~addSource(statute2)
ignored = gen2~addSource(contract2)
statNorm2 = .LegalNorm~new("ACT-12", statute2~sourceId, "12", "PROHIBITION", "WAGE_CUT", "PROHIBITED", "WORK_RELATIONSHIP", "synthetic mandatory rule", .nil, "*", "WAGE_CUT_LEGALITY")
contractNorm2 = .LegalNorm~new("CONTRACT-7", contract2~sourceId, "7", "PERMISSION", "WAGE_CUT", "PERMITTED", "WORK_RELATIONSHIP", "synthetic variation clause", .nil, "*", "WAGE_CUT_LEGALITY")
ignored = gen2~addNorm(statNorm2)
ignored = gen2~addNorm(contractNorm2)
priority = .LegalAuthorityRule~new("ACT-NON-DEROGATION", statute2~sourceId, "13", statute2~sourceId, contract2~sourceId, "NON_DEROGATION", "WORK_RELATIONSHIP", "WAGE_CUT", .nil, "ACT-12", "CONTRACT-7", "synthetic rule says contract cannot displace Act")
ignored = gen2~addAuthorityRule(priority)
ignored = gen2~seal

context2 = .LegalContext~new("DELIVERY-WAGE-CUT", "2026-08-20")
ignored = context2~bindSource(contract2~sourceId, "driver is party")
second = .LegalEffectEngine~new~evaluate(action, gen2, context2)~value
say "After adding an explicit evidence-bearing authority relation:"
say "  status=" || second~status || " disposition=" || second~dispositions[1]
say "  winner=" || second~resolvedConflicts[1]~winnerMatch~norm~normId || " loser=" || second~resolvedConflicts[1]~loserMatch~norm~normId
say "  authority=" || second~resolvedConflicts[1]~authorityMatch~rule~ruleId

::requires "LegalEffect.cls"
