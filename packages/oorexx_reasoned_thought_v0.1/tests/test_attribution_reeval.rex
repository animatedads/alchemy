/* Reasoned Thought qualification: the RexxLA attribution re-evaluation, run on the very
 * misread that motivated the model. An idea (who authored a passage) is held with its
 * grounds attached; later utterances TRIGGER re-evaluation and the belief revises.
 * Pure ooRexx 5.3; no native dependencies.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

net = .ThoughtNetwork~new
net~propose("P1a", "Claude was involved in composing the 'Yes Jon...blobs' passage")
net~propose("P1b", "Those exact words were generated verbatim by Claude", "PROVENANCE")
net~propose("P1c", "The precise boundary between Josep Maria's and Claude's sentences is known")

say "== 0. Seed: the attribution. The passage reads like Claude (stylometric resemblance)."
u0 = .Utterance~new("u0", "The passage reads like Claude.")
u0~assert("SUPPORT", "STYLOMETRIC", "P1a", , "voice resemblance")
u0~assert("SUPPORT", "STYLOMETRIC", "P1b", , "voice resemblance", "g.style.p1b")
net~admit(u0)
a1 = net~assess("P1a"); b1 = net~assess("P1b")
call show "P1a", a1; call show "P1b", b1
call check \a1["assertible"] & \b1["assertible"], -
  "seed: NEITHER involvement nor verbatim-authorship is assertible on stylistic resemblance"
call check b1["status"] = "UNDERDETERMINED", -
  "seed: verbatim-authorship is UNDERDETERMINED (it requires PROVENANCE)"
confBeforeBracket = b1["confidence"]

say ""
say "== 1. Admit the bracket as TESTIMONY: a human openly names Claude, and reveals an editorial hand."
u1 = .Utterance~new("u1", "[Sorry -- Claude has a tendency to overstate the obvious ;)]")
u1~assert("SUPPORT", "TESTIMONY", "P1a", , "a human openly names Claude as a collaborator")
u1~assert("UNDERCUT", "TESTIMONY", "P1b", "g.style.p1b", -
  "editorial hand revealed: resemblance of voice does not imply sole verbatim authorship")
rep1 = net~admit(u1)
a2 = net~assess("P1a"); b2 = net~assess("P1b")
call show "P1a", a2; call show "P1b", b2
call check a2["assertible"] & a2["status"] = "SUPPORTED", -
  "bracket: involvement becomes SUPPORTED and assertible"
call check \b2["assertible"] & b2["status"] = "UNDERDETERMINED", -
  "bracket: verbatim-authorship stays UNDERDETERMINED / not assertible"
call check b2["confidence"] < confBeforeBracket, -
  "bracket: the SAME utterance WEAKENED verbatim-authorship while it raised involvement (opposite directions)"
call check reportMoved(rep1, "P1a") & reportMoved(rep1, "P1b"), -
  "the one utterance's change report records BOTH moves (auditable)"

say ""
say "== 2. Admit Tom's own flip-flop about the seam as two conflicting TESTIMONY grounds."
u2 = .Utterance~new("u2", "'the whole Yes-Jon section is Claude' ... then: 'I think that was Josep Maria's comment'")
u2~assert("SUPPORT", "TESTIMONY", "P1c", , "first reading: the seam is Claude's")
u2~assert("REBUT",   "TESTIMONY", "P1c", , "revised reading: that was Josep Maria's")
net~admit(u2)
c2 = net~assess("P1c"); call show "P1c", c2
call check \c2["assertible"] & c2["status"] = "UNDERDETERMINED", -
  "conflicting same-class testimony leaves the seam UNDERDETERMINED (a standoff, not settled)"

say ""
say "== 3. Admit the archive Message-ID as PROVENANCE."
u3 = .Utterance~new("u3", "Mailing-list archive Message-ID shows the passage body exactly as delivered.")
u3~assert("SUPPORT", "PROVENANCE", "P1b", , "Message-ID chain of custody")
net~admit(u3)
b3 = net~assess("P1b"); call show "P1b", b3
call check b3["assertible"] & b3["status"] = "SETTLED", -
  "PROVENANCE settles verbatim-authorship: the model IS convincible, by the decisive class"
call check \b1["assertible"] & \b2["assertible"] & b3["assertible"], -
  "verbatim-authorship was assertible ONLY after provenance - never on stylometric or testimony"

say ""
say "   audit trail for P1b (why):"
do ln over b3["why"]~makeArray("0a"x); say "     " || ln; end

say ""
say "REASONED THOUGHT ATTRIBUTION TEST: PASS (" || checks || " checks)"
exit 0

show:
  use arg id, r
  say "   " || id r["status"] "conf=" || format(r["confidence"],,3) "assertible=" || r["assertible"] "  --" r["statement"]
  return

reportMoved: procedure
  use arg rep, id
  do c over rep["changes"]
    if c["id"] = id then return c["moved"]
  end
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

::requires "ReasonedThought.cls"
