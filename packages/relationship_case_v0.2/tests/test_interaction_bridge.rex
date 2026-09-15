/* Real Interaction Event v0.3 bridge qualification. */
now = .DateTime~new
e = .InteractionEvent~new("INT-900", "BRANCH_CONVERSATION", .nil, "BRANCH", "STAFF_DESK", "INBOUND", now, now, .nil)~seal
r = .RelationshipCaseInteractionBridge~fromEvent("EL-INT-900", e)
.RelationshipCaseTestSupport~assertTrue(r~ok, "bridge sealed interaction")
el = r~value
.RelationshipCaseTestSupport~assertEqual("INTERACTION", el~elementType, "bridge type")
.RelationshipCaseTestSupport~assertEqual(e~pointId, el~sourceRef, "bridge preserves authoritative reference")
.RelationshipCaseTestSupport~assertTrue(el~hasTag("SOURCE_CONTENT_NOT_COPIED"), "bridge does not flatten interaction")
say "PASS test_interaction_bridge"
exit 0
::requires "TestSupport.cls"
::requires "RelationshipCaseInteractionBridge.cls"
::requires "RelationshipCase.cls"
::requires "InteractionEvent.cls"
