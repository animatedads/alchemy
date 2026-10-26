/* Reasoned Thought qualification 10: audit Gemini's psychic-spies Bitcoin answer against the SAME
 * scenario premises Claude and Tom established. Reuse of the model with another model's understanding.
 * Gemini produced THREE answers; they agree with Claude on hardware-over-paper but disagree with
 * EACH OTHER on the threshold (one says 2-of-3, one says 3-of-3). Fed the shared premises, the model
 * says which parts of Gemini's understanding stack up and which rest on a hidden assumption.
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new

/* The scenario's established premises - checked axioms of this fictional world. */
m~fact("K_hw_only", "only secure-enclave hardware is private; any human-readable form is broadcast", 0, "SCENARIO")
hw = .directory~new; hw["K_hw_only"] = "SCENARIO"
m~confirm("A_psychic", "scenario axiom: psychics read anything human-readable", hw, 0)
m~fact("K_3of3_sound", "3-of-3 removes the two-can-collude path", 0, "SCENARIO")
t3 = .directory~new; t3["K_3of3_sound"] = "SCENARIO"
m~confirm("A_unanimity", "scenario axiom: only unanimity blocks open collusion", t3, 0)

/* A plain-2-of-3 safety claim - the scenario's collusion axiom refutes it. */
m~fact("K_2of3_safe", "2-of-3 needs no extra mechanism", 0, "SCENARIO")
sc = .directory~new; sc["K_2of3_safe"] = "SCENARIO"
m~measure("A_collusion", "scenario axiom: any two of three can openly collude and rob the third", sc, 0)

/* Gemini's 2-of-3 defence (att.1) bottoms out HERE, and this is never established: */
m~fact("K_liveness", "the 3rd spy reliably notices and vetoes within the 24h timelock window", 0, "SCENARIO")

/* Gemini (all answers) keeps a PIN on the fob. But a 4-digit PIN is a secret in a human mind. */
m~fact("K_pin_secret", "the fob PIN stays secret (a randomized keypad defeats telepathy)", 0, "SCENARIO")
ps = .directory~new; ps["K_pin_secret"] = "SCENARIO"
m~measure("A_mind", "scenario axiom: a 4-digit PIN the user knows is read straight from the mind", ps, 0)

/* Gemini's recommendations across its three answers. */
m~decision("D_fobs",       "use hardware fobs, not paper");            m~needs("D_fobs", "K_hw_only")
m~decision("D_3of3",       "use 3-of-3 multisig (answer 2)");          m~needs("D_3of3", "K_3of3_sound")
m~decision("D_2of3_plain", "use plain 2-of-3 multisig");               m~needs("D_2of3_plain", "K_2of3_safe")
m~decision("D_2of3_veto",  "use 2-of-3, collusion handled by a timelock+veto (answer 1)")
m~needs("D_2of3_veto", "K_liveness")
m~decision("D_pin", "rely on the fob PIN as a security layer"); m~needs("D_pin", "K_pin_secret")

rev = m~review

say "== Where Gemini stacks up"
call check inList(rev["checkedFacts"], "K_hw_only") & \ fellIn(rev, "D_fobs"), -
  "hardware-over-paper rests on a checked scenario axiom - Gemini agrees with Claude, it stacks up"
call check inList(rev["checkedFacts"], "K_3of3_sound") & \ fellIn(rev, "D_3of3"), -
  "Gemini's 3-of-3 (answer 2) rests on a checked axiom - it stacks up"

say ""
say "== Where it does not"
call check fellIn(rev, "D_2of3_plain"), -
  "plain 2-of-3 is REFUTED by the scenario's collusion axiom - exactly Claude's and Gemini-answer-2's point"
call check \ inList(rev["checkedFacts"], "K_liveness") & \ fellIn(rev, "D_2of3_veto"), -
  "Gemini's veto-rescued 2-of-3 (answer 1) survives ONLY on an UNEXAMINED liveness assumption - a hidden fact surfaced"
call check fellIn(rev, "D_pin") & \ fellIn(rev, "D_fobs"), -
  "the PIN layer FALLS (a 4-digit PIN in a mind is broadcast) - yet D_fobs still holds: the enclave that never exports the key is the real protection, not the PIN"

say ""
say "== The verdict against the shared premises"
say "   Gemini's three answers disagree on the threshold (2-of-3 vs 3-of-3). Audited against the same"
say "   premises Claude used: the hardware reasoning and 3-of-3 rest on checked axioms; the 2-of-3"
say "   rests on an unexamined 'the 3rd spy vetoes in time' hope. The better-grounded of Gemini's own"
say "   answers is the 3-of-3 - the conclusion Claude reached."

do f over rev["refutedFacts"]; say "   refuted:" f["id"] || ":" f["statement"]; end

say ""
say "REASONED THOUGHT GEMINI-BITCOIN AUDIT TEST: PASS (" || checks || " checks)"
exit 0

fellIn: procedure
  use arg rev, id
  do d over rev["fallenDecisions"]; if d["id"] = id then return .true; end
  return .false

inList: procedure
  use arg arr, id
  do d over arr; if d["id"] = id then return .true; end
  return .false

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

::requires "FactsMatrix.cls"
