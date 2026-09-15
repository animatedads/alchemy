/*
 * SYNTHETIC DEMONSTRATION ONLY.
 * These rule identifiers and clauses are designed to exercise Legal Effect;
 * they are not a statement of the actual law of any jurisdiction.
 */

say "LEGAL EFFECT V0.14 FOOD DELIVERY SYNTHETIC DEMO"
say ""

gen = .LegalRuleGeneration~new("FOOD-DELIVERY-DEMO-G1", "0.1")
laSource = .NormativeSource~new("SYN-LA-WORK", "LEGISLATION", "Synthetic California work rule", "SYNTHETIC", "US-CA")
nswSource = .NormativeSource~new("SYN-NSW-WORK", "REGULATION", "Synthetic NSW delivery order", "SYNTHETIC", "AU-NSW")
ukSource = .NormativeSource~new("SYN-UK-WORK", "COURT_DECISION", "Synthetic UK status rule", "SYNTHETIC", "UK-ENG")
contractSource = .NormativeSource~new("DRIVER-MSA-2026", "CONTRACT", "Synthetic driver master services agreement", "PARTIES", "*", "example governing law")
ignored = gen~addSource(laSource)
ignored = gen~addSource(nswSource)
ignored = gen~addSource(ukSource)
ignored = gen~addSource(contractSource)

laNorm = .LegalNorm~new("LA-Z-11-12", laSource~sourceId, "Z.11.12", "STATUS", "SCHEDULING_CHANGE", "STATUS_EFFECT", "WORK_RELATIONSHIP", "Forced blocks may change classification predicates")
ignored = laNorm~addJurisdiction(.LegalJurisdictionClaim~new("CALIFORNIA", "LOS_ANGELES", "WORK_RELATIONSHIP"))
ignored = laNorm~addCondition(.LegalPredicate~new("FORCED_BLOCKS", "KNOWN_TRUE"))
ignored = gen~addNorm(laNorm)

nswTime = .LegalTemporalScope~new("2026-08-17", "2026-08-17", "", "2026-08-17", "")
nswNorm = .LegalNorm~new("NSW-Z-11-13", nswSource~sourceId, "Z.11.13", "OBLIGATION", "RATE_CHANGE", "REQUIRES_OBLIGATION", "WORK_RELATIONSHIP", "Synthetic post-commencement minimum-standard check", nswTime)
ignored = nswNorm~addJurisdiction(.LegalJurisdictionClaim~new("AUSTRALIA", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
ignored = nswNorm~addCondition(.LegalPredicate~new("EMPLOYEE_LIKE_WORKER", "KNOWN_TRUE"))
ignored = gen~addNorm(nswNorm)

ukNorm = .LegalNorm~new("UK-Z-11-14", ukSource~sourceId, "Z.11.14", "STATUS", "SCHEDULING_CHANGE", "STATUS_EFFECT", "WORK_RELATIONSHIP", "Synthetic control/status relationship")
ignored = ukNorm~addJurisdiction(.LegalJurisdictionClaim~new("UNITED_KINGDOM", "ENGLAND", "WORK_RELATIONSHIP"))
ignored = ukNorm~addCondition(.LegalPredicate~new("FORCED_BLOCKS", "KNOWN_TRUE"))
ignored = ukNorm~addCondition(.LegalPredicate~new("GENUINE_SUBSTITUTION", "KNOWN_FALSE"))
ignored = gen~addNorm(ukNorm)

contractNorm = .LegalNorm~new("CONTRACT-11-12", contractSource~sourceId, "11.12", "CONTRACT_TERM", "RATE_CHANGE", "CONTRACT_BREACH", "CONTRACT", "Synthetic rate lock during current term")
ignored = contractNorm~addCondition(.LegalPredicate~new("RATE_CHANGE_DURING_TERM", "KNOWN_TRUE"))
ignored = gen~addNorm(contractNorm)
ignored = gen~seal

engine = .LegalEffectEngine~new

laFacts = .LegalFactSet~new
ignored = laFacts~putKnown("FORCED_BLOCKS", .false)
ignored = laFacts~putKnown("RECRUITMENT_COST_BURDEN", 0.15)
ignored = laFacts~putKnown("NEW_DRIVER_PRODUCTIVITY_FACTOR", 0.80)
la = .LegalContext~new("LA-POLICY", "2026-08-20", "2026-08-20", laFacts)
ignored = la~addJurisdiction(.LegalJurisdictionClaim~new("CALIFORNIA", "LOS_ANGELES", "WORK_RELATIONSHIP"))
shift = .LegalAction~new("SCHEDULING_CHANGE", "Require fixed delivery blocks")
ignored = shift~setFact("FORCED_BLOCKS", .true)
laAssessment = engine~evaluate(shift, gen, la)~value
say "Los Angeles scheduling change: " || laAssessment~status || " newly-applicable=" || laAssessment~newlyApplicable~items

sydFacts = .LegalFactSet~new
ignored = sydFacts~putKnown("EMPLOYEE_LIKE_WORKER", .true)
sydney = .LegalContext~new("SYD-RATE", "2026-08-18", "2026-08-20", sydFacts)
ignored = sydney~addJurisdiction(.LegalJurisdictionClaim~new("AUSTRALIA", "NEW_SOUTH_WALES", "WORK_RELATIONSHIP"))
rate = .LegalAction~new("RATE_CHANGE", "Change delivery rate")
sydAssessment = engine~evaluate(rate, gen, sydney)~value
say "Sydney rate change (event 2026-08-18): " || sydAssessment~status

londonFacts = .LegalFactSet~new
ignored = londonFacts~putKnown("FORCED_BLOCKS", .false)
ignored = londonFacts~putKnown("GENUINE_SUBSTITUTION", .false)
london = .LegalContext~new("LDN-POLICY", "2026-08-20", "2026-08-20", londonFacts)
ignored = london~addJurisdiction(.LegalJurisdictionClaim~new("UNITED_KINGDOM", "ENGLAND", "WORK_RELATIONSHIP"))
ldnAssessment = engine~evaluate(shift, gen, london)~value
say "London scheduling change: " || ldnAssessment~status || " newly-applicable=" || ldnAssessment~newlyApplicable~items

contractFacts = .LegalFactSet~new
ignored = contractFacts~putKnown("RATE_CHANGE_DURING_TERM", .false)
contractContext = .LegalContext~new("CONTRACT-RATE", "2026-08-20", "2026-08-20", contractFacts)
ignored = contractContext~bindSource(contractSource~sourceId, "current driver agreement applies to transaction")
contractAction = .LegalAction~new("RATE_CHANGE", "Reduce current contracted rate")
ignored = contractAction~setFact("RATE_CHANGE_DURING_TERM", .true)
contractAssessment = engine~evaluate(contractAction, gen, contractContext)~value
say "Contract rate change: " || contractAssessment~status || " dispositions=" || contractAssessment~dispositions~items

say ""
say "Business facts remain business facts: recruitment burden=15%, new-driver productivity=80% for 30 days."
say "Legal Effect constrains the feasible action space; it does not choose the business optimum."

::requires "LegalEffect.cls"
