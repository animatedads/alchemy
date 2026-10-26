/* Reasoned Thought qualification 7: model and test the logic of a REAL conversation.
 * Source: the psychic-spies / Bitcoin-key chat (Tom & Claude, 2026-10-25/26). Claude made confident
 * conclusions resting on UNEXAMINED assumptions; Tom supplied premises that falsified them; Claude
 * revised. This is the exact failure the model is built to catch, on external data with a DOCUMENTED
 * revision history - so the expected "what was revised" set is the transcript's, not hand-authored
 * (answering ChatGPT's dogfood critique, REQ-00000201).
 *
 * Three falsification episodes:
 *   T1->T2  "fobs no better than paper" and "use 2-of-3" rest on "a glance is a minor risk";
 *           premise "psychics broadcast any readable exposure" falsifies it -> both flip.
 *   T3->T4  "the ring adds no security" rests on an unstated "a glance exposes a whole fob";
 *           "each fob has two files" falsifies it -> it falls; the independent-XOR sub-claim survives.
 *   T5->T6  "a courier can hold a secret" rests on Claude's unprompted "psychics can't read
 *           non-psychics"; "psychics can read anyone" falsifies it -> it dies.
 * Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

net = .ThoughtNetwork~new
j = .BeliefJournal~new(net)

/* Claims = Claude's working assumptions, each asserted at TESTIMONY tier (a stated hunch). */
j~claim("K_glance",   "an accidental human-readable glance is a minor, containable risk")
j~claim("K_coll",     "2-of-3's collusion risk is acceptable")
j~claim("K_wholefob", "a glance exposes a whole fob at once")
j~claim("K_xor",      "independent two-files-per-fob XOR gives the property without the ring")
j~claim("K_noread",   "psychics cannot read non-psychics")

assume = .Utterance~new("assume", "Claude's working assumptions")
assume~assert("SUPPORT", "TESTIMONY", "K_glance",   , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_coll",     , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_wholefob", , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_xor",      , , "assumed")
assume~assert("SUPPORT", "TESTIMONY", "K_noread",   , , "assumed")
net~admit(assume)

/* Conclusions Claude asserted, each resting on one claim. */
j~decision("D_fob",     "the fob scheme is NOT materially better than paper");  j~restsOn("D_fob",     "K_glance")
j~decision("D_2of3",    "recommend 2-of-3 multisig");                            j~restsOn("D_2of3",    "K_coll")
j~decision("D_ring",    "the ring scheme adds no security over a plain split");  j~restsOn("D_ring",    "K_wholefob")
j~decision("D_drop",    "drop the ring; keep independent two-files-per-fob XOR");j~restsOn("D_drop",    "K_xor")
j~decision("D_courier", "an ordinary courier can hold a secret");               j~restsOn("D_courier", "K_noread")

allDecs = .array~of("D_fob", "D_2of3", "D_ring", "D_drop", "D_courier")

say "== Baseline: every conclusion held when Claude first asserted it"
heldAll = .true
do d over allDecs
  if \ j~status(d)["ok"] then heldAll = .false
end
call check heldAll, "all five conclusions were assertible under Claude's original assumptions"

/* Tom's premises enter as higher-tier (DOCUMENTARY) facts that REBUT the assumptions. */
facts = .Utterance~new("toms_premises", "the premises Tom supplied")
facts~assert("REBUT", "DOCUMENTARY", "K_glance",   , , "psychics broadcast any human-readable exposure (Turn 2)")
facts~assert("REBUT", "DOCUMENTARY", "K_coll",     , , "2-of-3 encourages collusion (Turn 2)")
facts~assert("REBUT", "DOCUMENTARY", "K_wholefob", , , "each fob has two files; a single-file open is not terminal (Turn 4)")
facts~assert("REBUT", "DOCUMENTARY", "K_noread",   , , "psychics can read anyone (Turn 6)")
net~admit(facts)

say ""
say "== After Tom's corrections: trace which conclusions fall"
fell = .set~new; held = .set~new
do d over allDecs
  s = j~status(d)
  if s["ok"] then do; held~put(d); say "   HOLDS  " d; end
  else do; fell~put(d); say "   FALLS  " d "(lost:" s["failedDeps"][1] || ")"; end
end

/* The transcript's DOCUMENTED revisions: D_fob, D_2of3 (Turn 2), D_ring (Turn 4), D_courier (Turn 6). */
expectedFell = .set~new
expectedFell~put("D_fob"); expectedFell~put("D_2of3"); expectedFell~put("D_ring"); expectedFell~put("D_courier")
expectedHeld = .set~new; expectedHeld~put("D_drop")

call check setEqual(fell, expectedFell), -
  "the model flags EXACTLY the four conclusions Claude actually revised in the transcript"
call check setEqual(held, expectedHeld), -
  "and spares the one sub-claim (independent XOR) that Tom never falsified"
call check j~status("K_xor")["ok"], "the survivor claim K_xor is still assertible"
call check \ j~status("K_glance")["ok"], "the falsified assumption K_glance is no longer assertible"

say ""
say "== What this shows"
say "   Each revision Claude made by hand (self-score 8->5 at Turn 2) is reproduced mechanically:"
say "   an unexamined assumption, falsified by a premise, drags its dependent conclusion down."
say "   The expected revision set came from the transcript's record, not from the author of this test."

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
