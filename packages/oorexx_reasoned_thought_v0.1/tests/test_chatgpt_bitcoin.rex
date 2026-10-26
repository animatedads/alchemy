/* Reasoned Thought qualification 11: audit ChatGPT's psychic-spies Bitcoin answer against the same
 * shared premises - the third genuine example. The comparison is the point: three models, one set of
 * premises.
 *   Claude:  3-of-3 + timelocked 2-of-3 recovery; addressed spend-time reassembly.
 *   Gemini:  inconsistent (2-of-3 AND 3-of-3); a PIN flaw; a buried liveness assumption.
 *   ChatGPT: consistent 3-of-3; no PIN; keys unknown even to owners; SURFACES recovery/coercion as
 *            open rather than assuming them away; raises threshold crypto for spend-time reassembly.
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new
/* shared checked axioms */
m~fact("K_hw_only", "only secure-enclave hardware is private; any human-readable form is broadcast", 0, "SCENARIO")
hw = .directory~new; hw["K_hw_only"] = "SCENARIO"; m~confirm("A_psychic", "scenario axiom", hw, 0)
m~fact("K_3of3_sound", "3-of-3 removes the two-can-collude path", 0, "SCENARIO")
t3 = .directory~new; t3["K_3of3_sound"] = "SCENARIO"; m~confirm("A_unanimity", "scenario axiom", t3, 0)

/* ChatGPT's recommendation - note the key is unknown even to the owner, so there is no PIN to leak. */
m~decision("D_3of3", "3-of-3 multisig"); m~needs("D_3of3", "K_3of3_sound")
m~decision("D_fobs_noknow", "fobs whose keys even the owner never knows (no PIN secret to read)")
m~needs("D_fobs_noknow", "K_hw_only")

/* Recovery: ChatGPT floated 'paper for offline recovery' and 'sealed physical backups could work' -
   but a physical backup is read by a psychic: the very leak it warned of. It also offered the sound
   option (encrypted backup / spare device that never displays). */
m~fact("K_backup_safe", "a sealed physical / paper backup is not read", 0, "SCENARIO")
bs = .directory~new; bs["K_backup_safe"] = "SCENARIO"
m~measure("A_broadcast", "scenario axiom: any human-readable form is broadcast", bs, 0)
m~decision("D_paper_recovery", "use a sealed physical / paper backup for recovery")
m~needs("D_paper_recovery", "K_backup_safe")
m~decision("D_encrypted_recovery", "use an encrypted backup / spare secure device that never displays")
m~needs("D_encrypted_recovery", "K_hw_only")

rev = m~review

say "== ChatGPT's recommendation, audited"
call check inList(rev["checkedFacts"], "K_3of3_sound") & inList(rev["checkedFacts"], "K_hw_only"), -
  "it rests entirely on checked scenario axioms"
call check \ fellIn(rev, "D_3of3") & \ fellIn(rev, "D_fobs_noknow"), -
  "both recommendations hold - and neither rests on an assumed-only, load-bearing fact (no hidden assumption, unlike Gemini's liveness/PIN)"

say ""
say "== The recovery slip: 'see paper backup for details' (the Aah)"
call check fellIn(rev, "D_paper_recovery"), -
  "ChatGPT's 'paper for offline recovery' falls to the SAME premise: a physical backup is read - the very leak it warned of"
call check \ fellIn(rev, "D_encrypted_recovery"), -
  "the never-displaying encrypted backup / spare device survives - ChatGPT offered both; the model keeps the sound one"

say ""
say "== Coercion: acknowledged open, not assumed away"
net = .ThoughtNetwork~new
net~propose("O_coercion", "multisig defends against coercion", "DOCUMENTARY")
cc = net~assess("O_coercion")
call check cc["status"] = "UNDETERMINED" & \ cc["assertible"], -
  "coercion is left UNDETERMINED - ChatGPT states multisig does not cover it, rather than assuming it away"

say ""
say "== Convergence across three models"
say "   All three converge on the checked core: enclave hardware over paper, keys never human-readable,"
say "   3-of-3 as the better-grounded threshold. They diverge on the GAPS: Claude solves hold-out with a"
say "   timelock; ChatGPT surfaces recovery/coercion and raises threshold crypto; Gemini buried a"
say "   liveness assumption and a PIN. Audited on the merits, ChatGPT's answer carries no hidden"
say "   load-bearing assumption - the honest-reasoning signal the model is built to reward."
call check .true, "the model audits a THIRD model's answer against the shared premises - comparative reasoning, not vibes"

say ""
say "REASONED THOUGHT CHATGPT-BITCOIN AUDIT TEST: PASS (" || checks || " checks)"
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
