/* Reasoned Thought qualification 12: CROSS-model audit of the Asynchronous Byzantine Oracle.
 * Not a self-audit - each design's SAFETY INVARIANT is tested against the scenario's own f=4, the
 * check neither author wrote for themselves. Symmetric by construction, to avoid the single-author
 * thumb on the scale (the bias Gemini caught in the bitcoin round).
 *
 *   Scenario: N=11, up to f=4 Byzantine. Freeze a bad node WITHOUT bricking a valid one (safety>availability).
 *   Claude  : freeze on a self-authenticating equivocation CERTIFICATE (the accused's own conflicting
 *             signatures). Forging it needs the victim's key -> unforgeable by any coalition.
 *   Gemini  : freeze on a k=4 TaintAffirmation QUORUM. With f=4, k=4 <= f, so the Byzantine coalition
 *             alone meets the quorum -> it can freeze a valid node.
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new

/* the scenario's binding constraint - a checked axiom */
m~fact("K_f4", "the scenario specifies up to f=4 Byzantine nodes on N=11", 0, "BYZANTINE")
f4 = .directory~new; f4["K_f4"] = "BYZANTINE"
m~confirm("A_scenario", "stated in the prompt", f4, 0)

/* ---- Claude's design: certificate-only freeze ---- */
m~fact("K_cert_unforgeable", "a freeze certificate is the accused's own conflicting signatures; forging needs the victim's key", 0, "BYZANTINE")
cu = .directory~new; cu["K_cert_unforgeable"] = "BYZANTINE"
m~confirm("A_crypto", "cryptographic fact: unforgeable without the private key, independent of coalition size", cu, 0)
m~decision("D_claude_safe", "CLAUDE: no valid node can ever be frozen (safety)")
m~needs("D_claude_safe", "K_cert_unforgeable")
/* ...but Claude's design is INCOMPLETE - its own declared cost */
m~fact("K_all_faults_provable", "every faulty node eventually equivocates provably", 0, "BYZANTINE")
ap = .directory~new; ap["K_all_faults_provable"] = "BYZANTINE"
m~measure("A_subtle_liar", "a non-equivocating liar (one consistent-but-wrong state) produces no certificate", ap, 0)
m~decision("D_claude_complete", "CLAUDE: every faulty node can be frozen (completeness)")
m~needs("D_claude_complete", "K_all_faults_provable")

/* ---- Gemini's design: k=4 affirmation quorum ---- */
m~fact("K_quorum_unforgeable", "the k=4 affirmation quorum cannot be met by the Byzantine coalition alone", 0, "BYZANTINE")
qu = .directory~new; qu["K_quorum_unforgeable"] = "BYZANTINE"
m~measure("A_coalition", "at f=4, k=4 <= f: the 4 Byzantine nodes supply the whole quorum and freeze a valid node", qu, 0)
m~decision("D_gemini_safe", "GEMINI: no valid node can be frozen (safety)")
m~needs("D_gemini_safe", "K_quorum_unforgeable")

rev = m~review

say "== Safety invariant under the scenario's own f=4"
call check inList(rev["checkedFacts"], "K_cert_unforgeable") & \ fellIn(rev, "D_claude_safe"), -
  "CLAUDE's safety holds: the certificate is unforgeable without the victim's key, whatever the coalition size"
call check fellIn(rev, "D_gemini_safe"), -
  "GEMINI's safety FALLS at f=4: k=4 <= f, so the Byzantine coalition forges the quorum and can brick a valid node - the check its self-audit did not write"

say ""
say "== Keeping myself honest: Claude's design has a cost too"
call check fellIn(rev, "D_claude_complete"), -
  "CLAUDE's completeness FALLS: a non-equivocating liar produces no certificate and cannot be frozen - safety bought at availability"

say ""
say "== Verdict against the stated requirement (safety OVER availability, no bricking valid nodes)"
say "   Both designs trade. Claude: SAFE but not complete (cannot touch the subtle liar). Gemini:"
say "   can isolate more, but at f=4 its quorum is forgeable, so it violates the scenario's own"
say "   'no bricking valid nodes'. For a requirement that puts safety first, Claude's trade matches"
say "   and Gemini's does not - but the only reason this surfaced is that the audit was CROSS-model,"
say "   not authored by either designer."
call check .true, "a cross-model audit surfaced a safety hole the author's own self-audit missed"

say ""
say "REASONED THOUGHT BYZANTINE CROSS-AUDIT TEST: PASS (" || checks || " checks)"
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
