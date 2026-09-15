say "LEGAL EFFECT V0.14 FRAMEWORK SNAPSHOT SYNTHETIC DEMO"
say

base = .NormativeSource~new("DELIVERY-FRAMEWORK", "LEGISLATION", "Synthetic delivery framework", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES")
amending = .NormativeSource~new("DELIVERY-AMENDING-INSTRUMENT", "REGULATION", "Synthetic amending instrument", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES")
contract = .NormativeSource~new("DRIVER-C-7", "CONTRACT", "Synthetic driver contract", "PARTIES", "*", "NSW")

gen = .LegalRuleGeneration~new("DELIVERY-LEGAL-2026", "0.2")
ignored = gen~addSource(base)
ignored = gen~addSource(amending)
ignored = gen~addSource(contract)

rateProvision = .LegalProvision~new(base~sourceId, "Z.11.12", "ACTIVE", "BASE", "synthetic old rate provision")
contractProvision = .LegalProvision~new(contract~sourceId, "11.13", "ACTIVE", "BASE", "synthetic rate-variation clause")
ignored = gen~addProvision(rateProvision)
ignored = gen~addProvision(contractProvision)

oldNorm = .LegalNorm~new("RATE-BASE", base~sourceId, "Z.11.12", "PERMISSION", "RATE_CHANGE", "PERMITTED", "WORK_RELATIONSHIP", "synthetic old rule", .nil, "BASE")
newNorm = .LegalNorm~new("RATE-AMENDED", base~sourceId, "Z.11.12", "OBLIGATION", "RATE_CHANGE", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "synthetic amended rule", .nil, "ORDER_2026")
contractNorm = .LegalNorm~new("CONTRACT-11-13", contract~sourceId, "11.13", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH", "CONTRACT", "synthetic fixed-term clause", .nil, "BASE")
ignored = oldNorm~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
ignored = newNorm~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
ignored = contractNorm~addCondition(.LegalPredicate~new("RATE_CHANGE_DURING_TERM", "KNOWN_TRUE"))
ignored = gen~addNorm(oldNorm)
ignored = gen~addNorm(newNorm)
ignored = gen~addNorm(contractNorm)

changeTime = .LegalTemporalScope~new("2026-08-17", "2026-08-17", "", "2026-08-17", "")
substitution = .LegalModificationEffect~new("CHANGE-Z-11-12", amending~sourceId, "2.1", "SUBSTITUTE", base~sourceId, "Z.11.12", changeTime, 10, "ORDER_2026", "synthetic amended rate provision")
ignored = substitution~addJurisdiction(.LegalJurisdictionClaim~new("NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
ignored = gen~addModification(substitution)
ignored = gen~seal

graph = .LegalJurisdictionGraph~new
ignored = graph~addNode("AU", "COMMONWEALTH_OF_AUSTRALIA", "AUSTRALIA")
ignored = graph~addNode("NSW", "NEW_SOUTH_WALES", "NEW_SOUTH_WALES", "AU")
ignored = graph~addNode("SYDNEY", "CITY_OF_SYDNEY", "SYDNEY", "NSW")

action = .LegalAction~new("RATE_CHANGE", "Candidate delivery-rate change")
ignored = action~setFact("RATE_CHANGE_DURING_TERM", .true)

before = .LegalContext~new("TX-BEFORE", "2026-08-16", "2026-08-20")
ignored = before~useJurisdictionGraph(graph, "SYDNEY")
after = .LegalContext~new("TX-AFTER", "2026-08-18", "2026-08-20")
ignored = after~useJurisdictionGraph(graph, "SYDNEY")

beforeAssessment = .LegalEffectEngine~new~evaluate(action, gen, before)~value
afterAssessment = .LegalEffectEngine~new~evaluate(action, gen, after)~value
beforeState = beforeAssessment~afterSnapshot~provisionState(base~sourceId, "Z.11.12")
afterState = afterAssessment~afterSnapshot~provisionState(base~sourceId, "Z.11.12")

say "Sydney 2026-08-16: material=" || beforeState~materialVersion || " result=" || beforeAssessment~status
say "Sydney 2026-08-18: material=" || afterState~materialVersion || " result=" || afterAssessment~status
say "  lineage effects=" || afterState~lineage~items
say
say "The contract is loaded but is not yet applicable to this transaction:"
say "  result=" || afterAssessment~status
ignored = after~bindSource(contract~sourceId, "driver is party to DRIVER-C-7")
boundAssessment = .LegalEffectEngine~new~evaluate(action, gen, after)~value
say "After explicit contract binding:"
say "  result=" || boundAssessment~status || " dispositions=" || boundAssessment~dispositions~items
say
say "Same sealed generation; different legal framework selected by place, time and source relations."

::requires "LegalEffect.cls"
