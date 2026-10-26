/* Reasoned Thought qualification 1: the RexxLA attribution re-evaluation, run on the very
 * misread that motivated the model. Ordinal/defeasible decision (ChatGPT's combiner design,
 * REQ-00000189), with the provenance-binding correction: a mail Message-ID proves the email
 * DOCUMENT, not that a passage was generated verbatim by Claude.
 * Acceptance vectors A-E from REQ-00000189. Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

net = .ThoughtNetwork~new
net~propose("P1a", "Claude was involved in composing the 'Yes Jon...blobs' passage")
net~propose("P1b", "Those exact words were generated verbatim by Claude", "PROVENANCE", "TESTIMONY", .array~of("PASSAGE_GENERATION"))
net~propose("P2",  "The email body as delivered contained that passage", "PROVENANCE", "TESTIMONY", .array~of("MAIL_DOCUMENT"))
net~propose("P1c", "The precise boundary between Josep Maria's and Claude's sentences is known")

say "== A. Seed: stylometric resemblance only."
u0 = .Utterance~new("u0", "The passage reads like Claude.")
u0~assert("SUPPORT", "STYLOMETRIC", "P1a", , , "voice resemblance")
u0~assert("SUPPORT", "STYLOMETRIC", "P1b", , , "voice resemblance", "g.style.p1b")
net~admit(u0)
a1 = net~assess("P1a"); b1 = net~assess("P1b")
call show "P1a", a1; call show "P1b", b1
call check \a1["assertible"] & \b1["assertible"], -
  "A: neither involvement nor verbatim-authorship is assertible on resemblance alone"

say ""
say "== B. Admit the bracket as TESTIMONY: supports involvement, undercuts the stylometry=>authorship step."
u1 = .Utterance~new("u1", "[Sorry -- Claude has a tendency to overstate the obvious ;)]")
u1~assert("SUPPORT", "TESTIMONY", "P1a", , , "a human openly names Claude as a collaborator")
u1~assert("UNDERCUT", "TESTIMONY", "P1b", "g.style.p1b", , "editorial hand revealed: resemblance of voice is not verbatim authorship")
net~admit(u1)
a2 = net~assess("P1a"); b2 = net~assess("P1b")
call show "P1a", a2; call show "P1b", b2
call check a2["assertible"] & a2["status"] = "SUPPORTED", "B: involvement becomes SUPPORTED and assertible"
call check \b2["assertible"] & b2["status"] = "UNDETERMINED" & b2["supportTier"] = 0, -
  "B: the same utterance leaves verbatim-authorship UNDETERMINED (its only support is defeated by a higher-tier undercut)"

say ""
say "== C. Tom's own flip-flop about the seam: equal-tier opposing testimony."
u2 = .Utterance~new("u2", "'the whole Yes-Jon section is Claude' ... then: 'that was Josep Maria's comment'")
u2~assert("SUPPORT", "TESTIMONY", "P1c", , , "first reading: the seam is Claude's")
u2~assert("REBUT",   "TESTIMONY", "P1c", , , "revised reading: that was Josep Maria's")
net~admit(u2)
c = net~assess("P1c"); call show "P1c", c
call check c["stance"] = "DISPUTED" & \c["assertible"], "C: equal-tier opposing testimony is DISPUTED, not resolved by a number"

say ""
say "== D. A mail Message-ID. It binds the email DOCUMENT - not the passage's authorship."
u3 = .Utterance~new("u3", "Mail archive Message-ID authenticates the email as delivered.")
u3~assert("SUPPORT", "PROVENANCE", "P1b", , "MAIL_DOCUMENT", "mis-aimed at P1b: a Message-ID is not a generation transcript")
u3~assert("SUPPORT", "PROVENANCE", "P2",  , "MAIL_DOCUMENT", "correctly aimed: the email body as delivered")
net~admit(u3)
b3 = net~assess("P1b"); p2 = net~assess("P2")
call show "P1b", b3; call show "P2", p2
call check \b3["settled"] & b3["ineligible"]~items > 0, -
  "D: the Message-ID does NOT settle verbatim-authorship (binding not on point; recorded INELIGIBLE)"
call check p2["settled"] & p2["status"] = "SETTLED", "D: the Message-ID DOES settle the document claim it actually binds"

say ""
say "== E. An authenticated model-output transcript, exact passage hash-bound to a Claude run."
u4 = .Utterance~new("u4", "Generation transcript binds the exact passage bytes to a Claude run.")
u4~assert("SUPPORT", "PROVENANCE", "P1b", , "PASSAGE_GENERATION", "generation provenance on point for verbatim authorship")
net~admit(u4)
b4 = net~assess("P1b"); call show "P1b", b4
call check b4["settled"] & b4["status"] = "SETTLED", "E: passage-bound generation provenance SETTLES verbatim-authorship"
call check \b1["settled"] & \b2["settled"] & \b3["settled"] & b4["settled"], -
  "verbatim-authorship settled ONLY on passage-bound provenance - never on stylometry, testimony, or mail provenance"

say ""
say "   audit trail for P1b (why):"
do ln over b4["why"]~makeArray("0a"x); say "     " || ln; end

say ""
say "REASONED THOUGHT ATTRIBUTION TEST: PASS (" || checks || " checks)"
exit 0

show:
  use arg id, r
  say "   " || id r["stance"] r["status"] "assertible=" || r["assertible"] "settled=" || r["settled"] -
      "(S=" || r["supportTier"] || " R=" || r["rebutTier"] || ")  --" r["statement"]
  return

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
