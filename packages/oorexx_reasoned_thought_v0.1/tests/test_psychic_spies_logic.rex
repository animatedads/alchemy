/* Reasoned Thought qualification 7: model and test the logic of a REAL conversation.
 * Source: the psychic-spies / Bitcoin-key chat (Tom & Claude, 2026-10-25/26).
 *   file:   psychic_spies_bitcoin_chat.md
 *   sha256: edd4c34875a83b6d47b73c2677ea1dd129b2f33da12ed7ef7dad1300a0287e27
 * Each expected revision is bound to an identifiable transcript turn (below), per ChatGPT REQ-213.
 *
 * Claude made confident conclusions resting on UNEXAMINED assumptions; Tom supplied premises - the
 * AXIOMS OF HIS FICTIONAL WORLD, authoritative within the scenario, not real-world documentary - that
 * falsified them; Claude revised. Modelled with scoped premise authority (binding SCENARIO).
 *
 *   Episode   assumption falsified         conclusion(s) that fell          transcript
 *   T1->T2    K_glance  "a glance is minor"  D_fob,  D_2of3                   Turn 1 -> Turn 2
 *   T3->T4    K_wholefob "a whole-fob glance" D_ring                          Turn 3 -> Turn 4
 *   T5->T6    K_noread  "can't read non-psy"  D_courier                       Turn 5 -> Turn 6
 *   survivors: D_xor_property, D_drop_ring (Turn 4) - never falsified
 *
 * Per ChatGPT REQ-213: "drop the ring" is split from "keep the XOR property"; abandoning the ring
 * needs its own justification (K_ring_no_benefit) beyond K_xor, so surviving XOR alone does not
 * carry it.
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

net = .ThoughtNetwork~new
j = .BeliefJournal~new(net)

/* Claims = Claude's working assumptions. Those Tom overturns accept SCENARIO-scoped premises. */
scen = .array~of("SCENARIO")
j~claim("K_glance",   "an accidental human-readable glance is a minor, containable risk", "", "TESTIMONY", scen)
j~claim("K_coll",     "2-of-3's collusion risk is acceptable",                            "", "TESTIMONY", scen)
j~claim("K_wholefob", "a glance exposes a whole fob at once",                             "", "TESTIMONY", scen)
j~claim("K_noread",   "psychics cannot read non-psychics",                               "", "TESTIMONY", scen)
j~claim("K_xor",         "independent two-files-per-fob XOR preserves the leak-tolerance property")
j~claim("K_ring_nobenefit", "the ring / cross-encryption adds nothing over independent XOR parts")

assume = .Utterance~new("assume", "Claude's working assumptions")
assume~assert("SUPPORT", "TESTIMONY", "K_glance",         , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_coll",           , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_wholefob",       , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_noread",         , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_xor",            , , "Turn 4")
assume~assert("SUPPORT", "TESTIMONY", "K_ring_nobenefit", , , "Turn 4")
net~admit(assume)

/* Conclusions Claude asserted. 'drop the ring' rests on BOTH keeping the property AND the ring
   adding nothing - two justifications, per ChatGPT REQ-213. */
j~decision("D_fob",      "the fob scheme is NOT materially better than paper")
j~restsOn("D_fob", "K_glance")
j~decision("D_2of3",     "recommend 2-of-3 multisig")
j~restsOn("D_2of3", "K_coll")
j~decision("D_ring",     "the ring scheme adds no security over a plain split")
j~restsOn("D_ring", "K_wholefob")
j~decision("D_xor_property", "keep the independent two-files-per-fob XOR structure")
j~restsOn("D_xor_property", "K_xor")
j~decision("D_drop_ring", "drop the ring / cross-encryption")
j~restsOn("D_drop_ring", "K_xor"); j~restsOn("D_drop_ring", "K_ring_nobenefit")
j~decision("D_courier",  "an ordinary courier can hold a secret")
j~restsOn("D_courier", "K_noread")

allDecs = .array~of("D_fob", "D_2of3", "D_ring", "D_xor_property", "D_drop_ring", "D_courier")

say "== Baseline: every conclusion held when Claude first asserted it"
heldAll = .true
do d over allDecs
  if \ j~status(d)["ok"] then heldAll = .false
end
call check heldAll, "all six conclusions were assertible under Claude's original assumptions"

/* Tom's premises enter as SCENARIO-scoped DOCUMENTARY facts that REBUT the assumptions. */
facts = .Utterance~new("toms_premises", "the axioms of Tom's fictional world")
facts~assert("REBUT", "DOCUMENTARY", "K_glance",   , "SCENARIO", "psychics broadcast any human-readable exposure (Turn 2)")
facts~assert("REBUT", "DOCUMENTARY", "K_coll",     , "SCENARIO", "2-of-3 encourages collusion (Turn 2)")
facts~assert("REBUT", "DOCUMENTARY", "K_wholefob", , "SCENARIO", "each fob has two files; a single-file open is not terminal (Turn 4)")
facts~assert("REBUT", "DOCUMENTARY", "K_noread",   , "SCENARIO", "psychics can read anyone (Turn 6)")
net~admit(facts)

say ""
say "== After Tom's corrections: trace which conclusions fall"
fell = .set~new; held = .set~new
do d over allDecs
  s = j~status(d)
  if s["ok"] then do; held~put(d); say "   HOLDS  " d; end
  else do; fell~put(d); say "   FALLS  " d "(lost:" s["failedDeps"][1] || ")"; end
end

expectedFell = .set~new
expectedFell~put("D_fob"); expectedFell~put("D_2of3"); expectedFell~put("D_ring"); expectedFell~put("D_courier")
expectedHeld = .set~new; expectedHeld~put("D_xor_property"); expectedHeld~put("D_drop_ring")

call check setEqual(fell, expectedFell), -
  "the model flags EXACTLY the four conclusions Claude revised (Turns 2, 2, 4, 6)"
call check setEqual(held, expectedHeld), -
  "and spares the two survivors that rest only on claims Tom never falsified"
call check j~status("K_xor")["ok"], "the survivor claim K_xor is still assertible"
call check \ j~status("K_glance")["ok"], "the falsified assumption K_glance is no longer assertible"
/* ChatGPT REQ-213 point 1: dropping the ring needs its own justification, not just surviving XOR */
call check j~status("D_drop_ring")["ok"] & j~status("K_ring_nobenefit")["ok"], -
  "D_drop_ring holds because BOTH K_xor and K_ring_nobenefit survive - abandoning the ring is separately justified"

say ""
say "REASONED THOUGHT PSYCHIC-SPIES LOGIC TEST: PASS (" || checks || " checks)"
exit 0

setEqual: procedure
  use arg a, b
  if a~items \= b~items then return .false
  do x over a; if \ b~hasItem(x) then return .false; end
  return .true

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

::requires "BeliefJournal.cls"
