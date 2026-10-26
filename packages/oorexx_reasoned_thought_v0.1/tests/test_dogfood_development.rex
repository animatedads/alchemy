/* Reasoned Thought qualification 5: the circular dogfood test - the module audits its OWN
 * development. (Tom's requirement, 2026-10-26.)
 *
 * The development loop Tom named - model, document decisions against nodes, run, does the outcome
 * uphold the model, revise, reconsider - IS the Belief Journal. So the acceptance criterion for
 * this module is reflexive: encode THIS session's real development as claims and decisions, replay
 * under the model we ended up with, and check that the model flags exactly the decisions we
 * actually had to revise. If the model's predicted blast radius equals the revision that really
 * happened, the module is in reflective equilibrium with its own development.
 *
 * NOTE this proves reflective ADEQUACY (the model can represent and audit its own history and
 * reproduce the revision), not that the model is correct in general. Honest claim only.
 * Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

/* The model we STARTED with this session (the naive one: Message-ID taken as authorship proof). */
net = .ThoughtNetwork~new(.NaiveEvidenceCombiner~new)
j = .BeliefJournal~new(net)

/* The claim underneath the early design. */
j~claim("K1", "a mail Message-ID is sufficient to settle verbatim authorship", -
        "PROVENANCE", "TESTIMONY", .array~of("PASSAGE_GENERATION"))
u = .Utterance~new("ev1", "the RexxLA archive Message-ID")
u~assert("SUPPORT", "PROVENANCE", "K1", , "MAIL_DOCUMENT", "a Message-ID")
net~admit(u)

/* Design decisions made this session, documented against the node each one shaped. */
j~decision("D_wex",    "[node: worked-example] elevate P1b to SETTLED on the Message-ID")
j~restsOn("D_wex", "K1", "settled")
j~decision("D_readme", "[node: README/report] state that verbatim authorship is provable from mail provenance")
j~restsOn("D_readme", "D_wex", "assertible")

/* The historical record: the decisions I ACTUALLY revised this session after ChatGPT's correction. */
actuallyRevised = .set~new; actuallyRevised~put("D_wex"); actuallyRevised~put("D_readme")

say "== Under the model we STARTED with"
say "   K1:" j~status("K1")["status"] "   D_wex:" j~status("D_wex")["status"] "   D_readme:" j~status("D_readme")["status"]
call check j~status("K1")["settled"], "the early model SETTLED the Message-ID claim (my mistake)"
call check j~status("D_wex")["ok"] & j~status("D_readme")["ok"], "both design decisions rested soundly on it, then"

say ""
say "== Run the model against the model: replay under the model we ENDED with (ordinal + binding)"
rep = j~review(.OrdinalEvidenceCombiner~new)
say "   " || rep["headline"]
flagged = .set~new
do di over rep["impacted"]
  say "   would revise:" di["id"] di["was"] "->" di["now"] "(failed:" di["failedDeps"][1] || ")"
  if di["fell"] then flagged~put(di["id"])
end

/* Does the outcome uphold the model? The predicted blast radius must equal what actually happened. */
call check setEqual(flagged, actuallyRevised), -
  "the model's predicted revisions EQUAL the revisions that actually happened this session"
call check rep["regressed"]~items = 1 & rep["regressed"][1]["id"] = "K1", -
  "the single falsified claim is identified: K1"

say ""
say "== Revise + reconsider: re-ground the decision on the corrected claim, re-run, confirm it holds"
j~claim("K1b", "authorship settles only on passage-bound generation provenance", -
        "PROVENANCE", "TESTIMONY", .array~of("PASSAGE_GENERATION"))
u2 = .Utterance~new("ev2", "authenticated model-output transcript, passage hash-bound to a Claude run")
u2~assert("SUPPORT", "PROVENANCE", "K1b", , "PASSAGE_GENERATION", "generation provenance")
net~admit(u2)
j~decision("D_wex2", "[node: worked-example, revised] P1b settles only on passage-bound provenance")
j~restsOn("D_wex2", "K1b", "settled")
rev = j~status("D_wex2", .OrdinalEvidenceCombiner~new)
say "   D_wex2 (revised):" rev["status"]
call check rev["ok"], "the revised decision holds under the new model - the loop closes (model->fail->revise->uphold)"

say ""
say "ASSUMPTION (for the record): an LLM building software makes confident design decisions resting"
say "on unexamined claims, and prose hides the dependency. If each decision is a justified node"
say "(decision restsOn claim, claim graded by evidence), a later falsification yields the EXACT set"
say "of decisions to revise, computably - not rediscovered by accident. The dogfood criterion: a"
say "reasoning module is development-sound when it can audit its own history and reproduce the"
say "revisions that actually occurred. This run shows Reasoned Thought meets it for itself."

say ""
say "REASONED THOUGHT DOGFOOD TEST: PASS (" || checks || " checks)"
exit 0

setEqual: procedure
  use arg a, b
  if a~items \= b~items then return .false
  do x over a; if \b~hasItem(x) then return .false; end
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
