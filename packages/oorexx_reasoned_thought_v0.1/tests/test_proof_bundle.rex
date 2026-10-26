/* Reasoned Thought qualification 6: self-contained proof bundle (ChatGPT, REQ-00000199).
 * A proof is serialised to canonical TEXT carrying policy + theory + statements + claimed
 * decisions, sealed with a hash. A second process, working only from the text, parses, rebuilds
 * and re-runs it - verifying the decisions follow from the stated inputs WITHOUT trusting the
 * first agent. Tamper is detected. Pure ooRexx 5.3; no native deps.
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

theory = .array~new
theory~append(prop("P1a", "Claude was involved in composing the passage"))
pol = .CategorisationPolicy~new("instanceA", "1")
pol~rule("voice", "STYLOMETRIC")
pol~rule("editorial-aside", "TESTIMONY")
proof = .Proof~new("attrib", pol)
proof~addProposition(theory[1])
proof~addStatement(.ProofStatement~new("s0", "the passage reads like Claude", "voice", "SUPPORT", "P1a"))
proof~addStatement(.ProofStatement~new("s1", "[Sorry -- Claude overstates the obvious ;)]", "editorial-aside", "SUPPORT", "P1a"))

bundle = .ProofBundle~serialize(proof)
say "== The wire bundle (self-contained text)"
do ln over bundle~makeArray("0a"x); say "   " || ln; end

/* Parse it as if in another process - nothing but the text. */
p = .ProofBundle~parse(bundle)
call check p["statements"]~items = 2 & p["props"]~items = 1 & p["rules"]~items = 2, -
  "the bundle carries the full source: statements, propositions and policy rules"

/* Independent replay: rebuild from the parsed text and re-run; it must reproduce the same result. */
rebuilt = .ProofBundle~rebuild(p)
certR = rebuilt~run("VERIFIER")
certO = proof~run("ORIGINAL")
call check certR~fingerprint = certO~fingerprint, -
  "a second process reproduces the original fingerprint from the text alone (independent replay)"

say ""
say "== Verify: do the claimed decisions follow from the stated inputs?"
v = .ProofBundle~verify(bundle)
say "   ok=" || v["ok"] "integrity=" || v["integrity"] "soundness=" || v["soundness"]
call check v["ok"] & v["integrity"] & v["soundness"], "the untampered bundle verifies (integrity + soundness)"

say ""
say "== Tamper detection"
tampered = changestr("| SUPPORTED |", bundle, "| REBUTTED |")
vt = .ProofBundle~verify(tampered)
say "   tampered: ok=" || vt["ok"] "integrity=" || vt["integrity"] "soundness=" || vt["soundness"]
call check \vt["ok"], "a bundle whose claimed decision was altered FAILS verification"

say ""
say "REASONED THOUGHT PROOF-BUNDLE TEST: PASS (" || checks || " checks)"
exit 0

prop: procedure
  use arg id, statement
  d = .directory~new; d["id"] = id; d["statement"] = statement; d["assertFloor"] = "TESTIMONY"
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
