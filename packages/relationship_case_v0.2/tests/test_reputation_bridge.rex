/* Real Reputation Feed v0.12 bridge qualification. */
now = .DateTime~new
claim = .ReputationFeedClaim~new("CL-1", "ARTICLE-1", "FAMILY-1", "POLITICAL_TRADE_PRESSURE", "", now, now, "US", 70, "ASSERTS", "UNVERIFIED", "PUBLIC-SOURCE", "")~seal
h = .ReputationEventHypothesis~new("H-POLITICAL-1", "POLITICAL_TRADE_PRESSURE")
h~addClaim(claim)
h~seal
r = .RelationshipCaseReputationBridge~fromHypothesis("EL-H-1", h)
.RelationshipCaseTestSupport~assertTrue(r~ok, "bridge sealed reputation hypothesis")
el = r~value
.RelationshipCaseTestSupport~assertEqual("EXTERNAL_SIGNAL", el~elementType, "external signal type")
.RelationshipCaseTestSupport~assertEqual("OBSERVATION_NOT_DECISION", el~authorityClass, "observation authority remains bounded")
.RelationshipCaseTestSupport~assertTrue(el~hasTag("NO_CORE_BANKING_AUTHORITY"), "bridge forbids authority promotion")
.RelationshipCaseTestSupport~assertTrue(el~hasTag("ASSERTION_NOT_PROMOTED_TO_FACT"), "bridge preserves epistemic boundary")
say "PASS test_reputation_bridge"
exit 0
::requires "TestSupport.cls"
::requires "RelationshipCaseReputationBridge.cls"
::requires "RelationshipCase.cls"
::requires "ReputationFeed.cls"
