/* Reasoned Thought qualification 4: retroactive revision - "let me think about what I missed".
 * A decision rests on a claim. The claim is replayed under a NEW thinking model; it now fails; the
 * journal traces forward to the decisions that were built on it and reports which now fall.
 * The scenario is the attribution error itself: a claim that SETTLED under the old naive model (mail
 * Message-ID treated as authorship proof) and FALLS under the corrected ordinal+binding model.
 * Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

/* The OLD thinking model: NaiveEvidenceCombiner (ignores binding scope). */
net = .ThoughtNetwork~new(.NaiveEvidenceCombiner~new)
j = .BeliefJournal~new(net)

j~claim("C1", "Those exact words were generated verbatim by Claude", "PROVENANCE", "TESTIMONY", .array~of("PASSAGE_GENERATION"))
/* evidence actually only binds the mail document */
u = .Utterance~new("u1", "mail archive Message-ID authenticates the email as delivered")
u~assert("SUPPORT", "PROVENANCE", "C1", , "MAIL_DOCUMENT", "a Message-ID")
net~admit(u)

j~decision("D1", "Attribute the quoted passage to Claude in the record")
j~restsOn("D1", "C1", "settled")
j~decision("D2", "Credit Claude as the passage's author in the published thread")
j~restsOn("D2", "D1", "assertible")

say "== Baseline, under the OLD (naive) model"
c1 = j~status("C1"); d1 = j~status("D1"); d2 = j~status("D2")
say "   C1:" c1["status"] "(assertible=" || c1["assertible"] "settled=" || c1["settled"] || ")"
say "   D1:" d1["status"] "   D2:" d2["status"]
call check c1["settled"] & c1["assertible"], "old model SETTLES the authorship claim (on the Message-ID)"
call check d1["status"] = "SUPPORTED" & d2["status"] = "SUPPORTED", "both decisions rest soundly on it, under the old model"

say ""
say "== Replay under the NEW (corrected ordinal+binding) model: let me think about what I missed"
rep = j~review(.OrdinalEvidenceCombiner~new)
say "   " || rep["headline"]
do rr over rep["regressed"]; say "   claim regressed:" rr["id"] rr["was"] "->" rr["now"]; end
do di over rep["impacted"]
  say "   decision impacted:" di["id"] di["was"] "->" di["now"] "fell=" || di["fell"] "(failed:" showDeps(di["failedDeps"]) || ")"
end

call check rep["regressed"]~items = 1 & rep["regressed"][1]["id"] = "C1" & rep["regressed"][1]["now"] = "UNDETERMINED", -
  "the authorship claim now FAILS under the corrected model"
call check rep["impacted"]~items = 2, "both dependent decisions are surfaced"
dd1 = impacted(rep, "D1"); dd2 = impacted(rep, "D2")
call check dd1 \== .nil & dd1["fell"] & dd1["now"] = "UNSUPPORTED", "D1 (direct dependant) fell: it was built on the now-unsupported claim"
call check dd2 \== .nil & dd2["fell"] & dd2["now"] = "UNSUPPORTED", "D2 (transitive dependant) fell too: the failure propagates down the chain"
call check depsMention(dd1["failedDeps"], "C1"), "D1's failure names the claim it lost: C1"
call check depsMention(dd2["failedDeps"], "D1"), "D2's failure names its broken link: D1"

say ""
say "REASONED THOUGHT RETRO-REVISION TEST: PASS (" || checks || " checks)"
exit 0

impacted: procedure
  use arg rep, id
  do di over rep["impacted"]; if di["id"] = id then return di; end
  return .nil

showDeps: procedure
  use arg arr
  if arr~items = 0 then return "-"
  out = ""
  do i = 1 to arr~items; if i = 1 then out = arr[i]; else out = out ";" arr[i]; end
  return out

depsMention: procedure
  use arg arr, id
  do e over arr; if e~pos(id) > 0 then return .true; end
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

::requires "BeliefJournal.cls"
