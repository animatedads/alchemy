env = .RIDTestFixtures~environment("INSURANCE", "ADVISED", "ALL_JAPAN_INSURANCE_CO_LTD", "ALL_JAPAN_POLICY_ADMIN", "HOME", "2026.08", "AJI-HOME|2026.08|SEM")
p = env["PRODUCT"]
adapter = .RIDAllJapanInsuranceAdapter~new

decision = .AllJapanInsuranceUnderwritingDecision~new("D-1", "SUB-1", "HOME", .AllJapanInsuranceBuild~DECISION_ACCEPT, "AJI-POLICY-HOME", "UW:1", env["NOW"]~string, "AJI:DECISION:EVIDENCE:1")
e = .RIDTestSupport~ok(adapter~fromDecision(decision, p, 10))
.RIDTestSupport~assertEq("APPROVED", e~status)
.RIDTestSupport~assertEq("ALL_JAPAN_INSURANCE_CO_LTD", e~providerEntityId)
.RIDTestSupport~assertEq("ALL_JAPAN_POLICY_ADMIN", e~providerSystem)
.RIDTestSupport~assertEq(p~productSemanticIdentity, e~productSemanticIdentity)

quote = .AllJapanInsuranceQuote~new("Q-1", "D-1", "SUB-1", "HOME", 12000, "GBP", "2026-09-30T00:00:00", env["NOW"]~string, "R-1", "PLAN-1", "RATED", "")
q = .RIDTestSupport~ok(adapter~fromQuote(quote, p, 11))
.RIDTestSupport~assertEq("QUOTED", q~status)

policy = .AllJapanInsurancePolicy~new("P-1", "Q-1", "CUSTOMER:1", "HOME", "RISK:1", "2026-09-01", "2027-09-01", env["NOW"]~string)
b = .RIDTestSupport~ok(adapter~fromPolicy(policy, p, "SUB-1", 12))
.RIDTestSupport~assertEq("BOUND", b~status)

wrong = .RIDTestFixtures~environment("INSURANCE", "ADVISED", "FEDERATIONBANK_PLC", "FEDERATION_INSURANCE", "HOME", "2026.08", "WRONG|SEM")["PRODUCT"]
r = adapter~fromDecision(decision, wrong, 13)
.RIDTestSupport~assertTrue(\r~ok)
.RIDTestSupport~assertEq("AJI_PROVIDER_ENTITY_MISMATCH", r~code)

say "PASS All Japan insurance authority maps to exact intermediary provider events"
exit 0

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDAllJapanInsuranceAdapter.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"
