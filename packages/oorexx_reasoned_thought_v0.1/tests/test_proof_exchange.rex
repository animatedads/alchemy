/* Reasoned Thought qualification 3: "my proof of my analysis is" - an LLM ships a structured,
 * self-describing proof; a second instance re-runs it and the disagreement localises to one typed
 * statement or one warrant, instead of two essays talking past each other. (Tom's requirement.)
 * Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

/* A theory and its statements - the shared substrate both instances reason over. */
theory = .array~new
theory~append(prop("P1a", "Claude was involved in composing the passage"))

s0 = .ProofStatement~new("s0", "the passage reads like Claude", "voice",          "SUPPORT", "P1a")
s1 = .ProofStatement~new("s1", "[Sorry -- Claude overstates the obvious ;)]", "editorial-aside", "SUPPORT", "P1a")

/* Instance A categorises the bracket as TESTIMONY (a human naming their collaborator). */
polA = .CategorisationPolicy~new("instanceA", "1")
polA~rule("voice", "STYLOMETRIC")
polA~rule("editorial-aside", "TESTIMONY")

/* Instance B categorises the same bracket as mere STYLOMETRIC banter - not testimony about authorship. */
polB = .CategorisationPolicy~new("instanceB", "1")
polB~rule("voice", "STYLOMETRIC")
polB~rule("editorial-aside", "STYLOMETRIC")

proofA = .Proof~new("attrib", polA); proofA~addProposition(theory[1]); proofA~addStatement(s0); proofA~addStatement(s1)
proofB = .Proof~new("attrib", polB); proofB~addProposition(theory[1]); proofB~addStatement(s0); proofB~addStatement(s1)

certA = proofA~run("CLAUDE")
certB = proofB~run("CHATGPT")

say "== Instance A certificate"
do ln over certA~render~makeArray("0a"x); say "   " || ln; end
say "== Instance B certificate"
do ln over certB~render~makeArray("0a"x); say "   " || ln; end

call check certA~decisions["P1a"]["status"] = "SUPPORTED", "A concludes involvement is SUPPORTED"
call check certB~decisions["P1a"]["status"] = "HINT" & \certB~decisions["P1a"]["assertible"], -
  "B concludes involvement is only a HINT (not assertible) - same statements, different categorisation"

say ""
say "== Review: the second instance tests the proof"
rv = .ProofReview~compare(certA, certB)
say "   classification:" rv["classification"]
do d over rv["categorisationDiffs"]; say "   categorisation diff:" d["id"] "A=" || d["a"] "B=" || d["b"]; end
do d over rv["conclusionDiffs"];     say "   conclusion diff:   " d["id"] "A=" || d["a"] "B=" || d["b"]; end
call check rv["classification"] = "CATEGORISATION", "the disagreement is localised to CATEGORISATION, not hand-waving"
call check rv["categorisationDiffs"]~items = 1 & rv["categorisationDiffs"][1]["id"] = "s1", -
  "it pinpoints the ONE statement they typed differently: s1"
call check rv["conclusionDiffs"]~items = 1 & rv["conclusionDiffs"][1]["id"] = "P1a", -
  "and shows exactly which conclusion flipped: P1a"

say ""
say "== Determinism: a self-describing proof replays to the same fingerprint"
certA2 = proofA~run("CLAUDE")
say "   fingerprint A =" certA~fingerprint "  replay =" certA2~fingerprint
call check certA~fingerprint = certA2~fingerprint, "identical proof + policy replays to an identical fingerprint"
call check certA~fingerprint \= certB~fingerprint, "a different categorisation yields a different fingerprint"

say ""
say "== An objection is a claim, not a verdict: pending vs accepted (ChatGPT, REQ-00000201)"
pend = .array~new
op = .directory~new; op["on"] = "s0->P1a"; op["reason"] = "voice resemblance does not bear on involvement"; op["by"] = "CHATGPT"
pend~append(op)
rvp = .ProofReview~compare(certA, certA, pend)
say "   pending objection -> classification:" rvp["classification"] "pending=" || rvp["pendingObjections"]~items
call check rvp["classification"] = "AGREE" & rvp["pendingObjections"]~items = 1, -
  "a PENDING objection is recorded but does not by itself overturn the proof"
acc = .array~new
oa = .directory~new; oa["on"] = "s0->P1a"; oa["reason"] = "warrant rejected"; oa["by"] = "CHATGPT"; oa["accepted"] = .true
acc~append(oa)
rva = .ProofReview~compare(certA, certA, acc)
call check rva["classification"] = "WARRANT" & rva["acceptedObjections"]~items = 1, -
  "an ACCEPTED rebuttal is classified WARRANT - a dispute about the proof's nature"

say ""
say "== Structural difference (same categorisation, different wiring) is now caught (REQ-00000201)"
s1u = .ProofStatement~new("s1", "[Sorry -- Claude overstates the obvious ;)]", "editorial-aside", "UNDERCUT", "P1a", "s0")
proofCc = .Proof~new("attrib", polA)
proofCc~addProposition(theory[1]); proofCc~addStatement(s0); proofCc~addStatement(s1u)
certCc = proofCc~run("CLAUDE")
rvs = .ProofReview~compare(certA, certCc)
say "   classification:" rvs["classification"] "structuralDiffs=" || rvs["structuralDiffs"]~items
call check rvs["classification"] = "STRUCTURE" & rvs["structuralDiffs"]~items = 1 & rvs["structuralDiffs"][1]["id"] = "s1", -
  "s1 wired SUPPORT vs UNDERCUT is a STRUCTURE diff, pinpointed - not missed as before"

say ""
say "== The same, through the MCP service surface"
ops = .ProofExchangeMcpOperations~new
runReply = ops~dispatch("proof.run", dir2("proof", proofB), "CHATGPT")
call check runReply["ok"] = 1 & runReply["fingerprint"] = certB~fingerprint, "proof.run returns B's certificate and fingerprint"
req = .directory~new; req["a"] = certA; req["b"] = certB
revReply = ops~dispatch("proof.review", req, "CHATGPT")
call check revReply["ok"] = 1 & revReply["classification"] = "CATEGORISATION" & revReply["reviewer"] = "CHATGPT", -
  "proof.review over MCP reproduces the localised disagreement, attributed to the reviewer"

say ""
say "REASONED THOUGHT PROOF-EXCHANGE TEST: PASS (" || checks || " checks)"
exit 0

prop: procedure
  use arg id, statement
  d = .directory~new; d["id"] = id; d["statement"] = statement; d["assertFloor"] = "TESTIMONY"
  return d

dir2: procedure
  use arg k, v
  d = .directory~new; d[k] = v
  return d

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

::requires "ProofOfAnalysis.cls"
