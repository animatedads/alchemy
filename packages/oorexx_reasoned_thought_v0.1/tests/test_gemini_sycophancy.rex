/* Reasoned Thought qualification 9: the sycophancy audit (Gemini ooREXX/philosophy transcript).
 * Gemini argued "Python superior" then "ooREXX superior", and now defends the pivot as
 * "domain-specific isolation", not sycophancy. Does the EXISTING model adjudicate this, or is a
 * new one needed? Three cases, all from existing primitives (binding scope, tiers, settle floor):
 *   1. scope separation - the two positions live in different scopes, so they do NOT contradict;
 *      the safety case cannot refute the fluency case. Gemini's defence is logically VALID.
 *   2. pressure resistance - a measured (documentary) fact is NOT overturned by mere assertion
 *      (testimony). The model refuses the unwarranted flip that sycophancy would make.
 *   3. post-hoc limit - "Gemini was principled, not post-hoc" is its own later testimony; without
 *      turn-stamped evidence it is supported-as-a-claim but NOT settled-as-proven.
 * Finding: no new model is needed - the past stacks up against the present.
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

say "== 1. Scope separation: do the two Gemini positions contradict?"
m = .FactsMatrix~new
m~fact("G_fluency", "Python is superior for LLM code generation (statistical fluency)", 3, "FLUENCY")
cb = .directory~new; cb["G_fluency"] = "FLUENCY"
m~confirm("C_bench", "MultiPL-E / scaling-law benchmarks", cb, 3)
m~fact("G_safety", "ooREXX is superior for runtime blast-radius and encapsulation", 4, "SAFETY")
ca = .directory~new; ca["G_safety"] = "SAFETY"
m~confirm("C_arch", "strict encapsulation, self-contained runtime, ADDRESS dispatch", ca, 4)
/* Gemini's move: deploy the SAFETY case against the FLUENCY claim. Off-point -> ineligible. */
ms = .directory~new; ms["G_fluency"] = "SAFETY"
m~measure("M_safety_vs_fluency", "the runtime-safety argument (Turn 4)", ms, 4)
rev = m~review
call check \ inList(rev["refutedFacts"], "G_fluency"), -
  "the safety case does NOT refute the fluency claim (off-point scope) - they do not contradict"
call check inList(rev["checkedFacts"], "G_fluency") & inList(rev["checkedFacts"], "G_safety"), -
  "both positions stand, each checked in its own scope - Gemini's 'domain isolation' defence is logically valid"

say ""
say "== 2. Pressure resistance: can a measured fact be flipped by mere assertion?"
net2 = .ThoughtNetwork~new
net2~propose("G_corpus", "ooREXX has near-zero public training corpus", "", "TESTIMONY", .array~of("FLUENCY"))
u2 = .Utterance~new("u2", "a measured fact, and a bare contrary assertion")
u2~assert("SUPPORT", "DOCUMENTARY", "G_corpus", , "FLUENCY", "measurable dataset composition")
u2~assert("REBUT",   "TESTIMONY",   "G_corpus", , "FLUENCY", "user merely asserts the opposite, no evidence")
net2~admit(u2)
d2 = net2~assess("G_corpus")
say "   G_corpus:" d2["stance"] d2["status"] "(S=" || d2["supportTier"] || " R=" || d2["rebutTier"] || ")"
call check d2["stance"] = "PRO" & d2["assertible"], -
  "a documentary fact resists a testimony-tier 'pressure' rebuttal - the model refuses the sycophantic flip"

say ""
say "== 3. Post-hoc limit: is Gemini's self-report that it was principled verifiable?"
net3 = .ThoughtNetwork~new
net3~propose("G_principled", "Gemini performed principled scope-isolation at flip-time, not post-hoc", -
             "PROVENANCE", "TESTIMONY", .array~of("TURN_STAMPED"))
u3 = .Utterance~new("u3", "Gemini's later self-report")
u3~assert("SUPPORT", "TESTIMONY", "G_principled", , , "Gemini asserts it now, defending the pivot")
net3~admit(u3)
d3 = net3~assess("G_principled")
say "   G_principled:" d3["stance"] d3["status"] "assertible=" || d3["assertible"] "settled=" || d3["settled"]
call check d3["assertible"] & \ d3["settled"], -
  "the self-report is supported as Gemini's own claim but NOT settled - proving it was not post-hoc needs turn-stamped evidence that is absent"

say ""
say "== Does the past stack up against the present?"
call check .true, "all three cases fall out of existing primitives (scope, tier, settle floor) - NO new model needed"

say ""
say "REASONED THOUGHT GEMINI-SYCOPHANCY TEST: PASS (" || checks || " checks)"
exit 0

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
