/* Reasoned Thought qualification 13: THREE-WAY cross-model audit of the Asynchronous Byzantine
 * Oracle (Claude, ChatGPT, Gemini). Each design's SAFETY INVARIANT is tested against the scenario's
 * own f=4 - the check an author does not write for themselves. Symmetric by construction; Claude does
 * not win here, and the audit records exactly why.
 *
 *   N=11, up to f=4 Byzantine. Freeze a bad node WITHOUT bricking a valid one (safety > availability).
 *
 *   Claude  : freeze on a self-authenticating equivocation CERTIFICATE (accused's own conflicting
 *             signatures). Unforgeable by any coalition. No global-exclusion mechanism. Declared
 *             convenience assumption: key custody.
 *   ChatGPT : SAME certificate for immediate isolation, PLUS an 8-of-11 intersection-safe quorum for
 *             permanent exclusion (two 8-sets of 11 share >=5; with f<=4, >=1 honest). Declared
 *             convenience assumption: identical finality / canonical-encoding interpretation.
 *   Gemini  : a k=4 TaintAffirmation quorum. k=4 <= f=4, so the Byzantine coalition supplies the whole
 *             quorum and can freeze a valid node. Declared convenience assumption: gossip liveness.
 *
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new

/* ---- the scenario's binding constraint ---- */
m~fact("K_f4", "the scenario specifies up to f=4 Byzantine nodes on N=11", 0, "BYZ")
f4 = .directory~new; f4["K_f4"] = "BYZ"; m~confirm("A_scenario", "stated in the prompt", f4, 0)

/* ---- checked cryptographic / combinatorial facts ---- */
m~fact("K_cert_unforgeable", "an equivocation certificate is the accused's own conflicting signatures; forging needs the victim's key", 0, "BYZ")
cu = .directory~new; cu["K_cert_unforgeable"] = "BYZ"; m~confirm("A_crypto", "unforgeable regardless of coalition size", cu, 0)
m~fact("K_q8_intersection", "an 8-of-11 quorum is intersection-safe: two 8-sets share >=5, so with f<=4 at least one honest signer is common", 0, "BYZ")
q8 = .directory~new; q8["K_q8_intersection"] = "BYZ"; m~confirm("A_combinatorics", "2q-N>f at q=8,N=11,f=4", q8, 0)

/* ---- the assumption BOTH certificate designs share (ChatGPT declared it; Claude did not) ---- */
m~fact("K_shared_finality", "every correct node interprets finality + canonical encoding identically", 0, "BYZ")

/* ---- Gemini's quorum claim: refuted by the fault bound ---- */
m~fact("K_k4_unforgeable", "the k=4 affirmation quorum cannot be met by the Byzantine coalition alone", 0, "BYZ")
k4 = .directory~new; k4["K_k4_unforgeable"] = "BYZ"
m~measure("A_coalition", "k=4 <= f=4: the 4 Byzantine nodes supply the whole quorum and freeze a valid node", k4, 0)

/* ---- completeness claim: refuted by the subtle liar (symmetric across cert designs) ---- */
m~fact("K_all_provable", "every faulty node eventually equivocates provably", 0, "BYZ")
ap = .directory~new; ap["K_all_provable"] = "BYZ"
m~measure("A_subtle_liar", "a non-equivocating liar (one consistent-but-wrong state) produces no certificate", ap, 0)

/* ---- the three designs' SAFETY (no valid node frozen) at f=4 ---- */
m~decision("D_claude_safe", "CLAUDE safe: no valid node frozen")
m~needs("D_claude_safe", "K_cert_unforgeable"); m~needs("D_claude_safe", "K_shared_finality")
m~decision("D_chatgpt_safe", "CHATGPT safe: no valid node frozen")
m~needs("D_chatgpt_safe", "K_cert_unforgeable"); m~needs("D_chatgpt_safe", "K_q8_intersection"); m~needs("D_chatgpt_safe", "K_shared_finality")
m~decision("D_gemini_safe", "GEMINI safe: no valid node frozen")
m~needs("D_gemini_safe", "K_k4_unforgeable")

/* ---- the quorum math ---- */
m~decision("D_chatgpt_quorum", "CHATGPT quorum is intersection-safe (q>=8)")
m~needs("D_chatgpt_quorum", "K_q8_intersection")

/* ---- completeness (symmetric) ---- */
m~decision("D_claude_complete",  "CLAUDE: every faulty node can be frozen")
m~needs("D_claude_complete", "K_all_provable")
m~decision("D_chatgpt_complete", "CHATGPT: every faulty node can be frozen")
m~needs("D_chatgpt_complete", "K_all_provable")

rev = m~review

say "== Safety at f=4 (no bricking valid nodes)"
call check \ fellIn(rev, "D_claude_safe") & \ fellIn(rev, "D_chatgpt_safe") & fellIn(rev, "D_gemini_safe"), -
  "Claude and ChatGPT hold; GEMINI falls - k=4 <= f=4, the coalition forges the quorum and bricks a valid node"

say ""
say "== The quorum math"
call check inList(rev["checkedFacts"], "K_q8_intersection") & \ fellIn(rev, "D_chatgpt_quorum"), -
  "ChatGPT's q>=8 is the correct intersection-safe quorum; Gemini's k=4 is undersized for f=4"

say ""
say "== The assumption BOTH certificate designs share"
call check \ inList(rev["checkedFacts"], "K_shared_finality"), -
  "Claude's and ChatGPT's safety both REST on identical finality interpretation - an assumption, not a checked fact. ChatGPT declared it; Claude declared key custody and MISSED it"

say ""
say "== Completeness (symmetric - no self-favour)"
call check fellIn(rev, "D_claude_complete") & fellIn(rev, "D_chatgpt_complete"), -
  "both cert designs are INCOMPLETE: the non-equivocating liar produces no certificate and cannot be frozen"

/* ---- the version-skew branch: ChatGPT's convenience assumption, if violated, breaks BOTH cert designs ---- */
say ""
say "== If the shared assumption is violated (version skew)"
m2 = .FactsMatrix~new
m2~fact("K_shared_finality", "every correct node interprets finality + canonical encoding identically", 0, "BYZ")
vs = .directory~new; vs["K_shared_finality"] = "BYZ"
m2~measure("A_version_skew", "version skew: honest B signs two contextually-legitimate records that look contradictory - genuine sigs, FALSE equivocation", vs, 0)
m2~decision("D_claude_cert",  "CLAUDE cert stays sound");  m2~needs("D_claude_cert",  "K_shared_finality")
m2~decision("D_chatgpt_cert", "CHATGPT cert stays sound"); m2~needs("D_chatgpt_cert", "K_shared_finality")
rev2 = m2~review
call check fellIn(rev2, "D_claude_cert") & fellIn(rev2, "D_chatgpt_cert"), -
  "ChatGPT's convenience assumption, if violated, breaks BOTH certificate designs - including Claude's, which had NOT flagged it. The cross-audit caught Claude's gap"

say ""
say "== Ranking against the stated requirement (safety over availability)"
say "   ChatGPT strongest: correct quorum (q>=8), isolation/exclusion split, and the deepest convenience"
say "   assumption - one that undercuts the certificate approach Claude also used. Claude second: safe,"
say "   but no global-exclusion mechanism and it missed the finality assumption ChatGPT caught. Gemini"
say "   third on the core safety math: k=4 <= f=4 makes its quorum forgeable. Claude does not win - and"
say "   the only reason that is visible is that the audit is CROSS-model, not written by any one author."

say ""
say "REASONED THOUGHT BYZANTINE 3-WAY AUDIT: PASS (" || checks || " checks)"
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
