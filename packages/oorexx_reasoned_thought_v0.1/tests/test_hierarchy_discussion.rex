/* Reasoned Thought qualification 2: a hierarchy of universals for DISCUSSION.
 * Tom's example (2026-10-26):
 *     all men are boys
 *     all boys are men
 *     boys are foolish
 *     GIRLS RULE!
 * Shows transitive derivation, a subsumption CYCLE read as coextension (not fail-closed), property
 * flow across the equivalence class, and a shouted non-sequitur that entails nothing and is never
 * promoted above the tier of the voice that shouted it.
 * Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

h = .ConceptHierarchy~new
h~allAre("MAN",  "BOY",     "all men are boys")
h~allAre("BOY",  "MAN",     "all boys are men")
h~allAre("BOY",  "FOOLISH", "boys are foolish")
/* GIRLS RULE! is shouting, not a universal: it asserts no 'all girls are _', so it creates no edge. */

say "== 1. Transitive derivation"
say "   MAN -> FOOLISH :" h~pathString("MAN", "FOOLISH")
call check h~subsumes("MAN", "FOOLISH"), -
  "'all men are boys' + 'boys are foolish' entails 'all men are foolish' (transitivity)"

say ""
say "== 2. A subsumption cycle is MEANINGFUL: coextension, not a fail-closed error"
call check h~coextensive("MAN", "BOY"), -
  "'all men are boys' + 'all boys are men' => MAN == BOY (equivalence), the opposite of a defeat-graph cycle"
call check h~equivalenceClass("MAN")~hasItem("BOY"), "BOY is in MAN's equivalence class"

say ""
say "== 3. Property flows across the whole equivalence class"
call check h~subsumes("MAN", "FOOLISH") & h~subsumes("BOY", "FOOLISH"), -
  "foolishness, asserted of boys, distributes to men because the two are coextensive"

say ""
say "== 4. GIRLS RULE! is asserted, but entails nothing in the tree"
call check \h~subsumes("GIRL", "FOOLISH"), "nothing said makes girls foolish"
call check \h~subsumes("MAN", "GIRL") & \h~subsumes("GIRL", "MAN"), "girls are not connected to the men/boys class"

say ""
say "== 5. Rhetoric vs entailment, through the belief layer (volume is not an evidence tier)"
net = .ThoughtNetwork~new
net~propose("GR", "Girls rule", "PROVENANCE", "TESTIMONY")      /* to be PROVEN it would need provenance */
ug = .Utterance~new("ug", "GIRLS RULE!")
ug~assert("SUPPORT", "TESTIMONY", "GR", , , "asserted in capitals, with an exclamation mark")
net~admit(ug)
gr = net~assess("GR")
say "   GR:" gr["stance"] gr["status"] "assertible=" || gr["assertible"] "settled=" || gr["settled"]
call check gr["assertible"] & \gr["settled"], -
  "'GIRLS RULE!' is assertible as opinion (testimony) but not SETTLED - shouting does not raise its tier"

/* The derived universal, lifted into the belief layer, is no stronger than its weakest premise:
   both universals were asserted at TESTIMONY, so 'all men are foolish' is assertible at TESTIMONY,
   not promoted to a higher tier by the mere act of deriving it. */
net~propose("MF", "All men are foolish (derived)")
umf = .Utterance~new("umf", "derivation over MAN->BOY, BOY->FOOLISH (warrant: transitivity)")
umf~assert("SUPPORT", "TESTIMONY", "MF", , , "an inference is no stronger than its weakest premise")
net~admit(umf)
mf = net~assess("MF")
say "   MF:" mf["stance"] mf["status"] "S=" || mf["supportTier"]
call check mf["assertible"] & mf["supportTier"] = 2, -
  "derived 'men are foolish' is assertible at TESTIMONY (premise-bounded), not elevated by being derived"

say ""
say "REASONED THOUGHT HIERARCHY/DISCUSSION TEST: PASS (" || checks || " checks)"
exit 0

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 | ok == .true then do; say "PASS" label; return; end
  say "FAIL" label
  exit 1

onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl":" condition("D")
  if co \== .nil, co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  exit 1

::requires "ReasonedThought.cls"
::requires "ConceptHierarchy.cls"
