main = .PokerPromptEnvelope~new("GROK")
main~append("GAME.POT", "PUBLIC", "pot: 50" || "0a"x)
main~append("SELF.HOLE_CARDS", "CUSTOMER", "your cards: AS KS" || "0a"x)
main~append("SOCIAL.EMPIRICAL_HISTORY", "PUBLIC", "E1 Hugo CHALLENGE n=4" || "0a"x)
ignore = main~finalize
ma = main~auditSummary

shadow = .PokerPromptEnvelope~new("GROK")
shadow~append("GAME.POT", "PUBLIC", "pot: 50" || "0a"x)
shadow~append("SELF.HOLE_CARDS", "CUSTOMER", "your cards: AS KS" || "0a"x)
shadow~append("SOCIAL.COUNTERFACTUAL_POLICY", "PUBLIC", "SOCIAL EVIDENCE DISABLED" || "0a"x)
ignore = shadow~finalize
sa = shadow~auditSummary

v = .PokerPromptManifestVerifier~new
if v~verifyCounterfactual(ma, sa) \= "MATCH" then raise syntax 93.900 array("compatible prompt manifests did not match")
if ma["manifest_version"] \= "PSYCHIC_POKER_PROMPT_FIELD_MANIFEST_V1" then raise syntax 93.900 array("manifest version wrong")
if ma["core_manifest"] \= sa["core_manifest"] then raise syntax 93.900 array("social-only counterfactual changed core manifest")
if ma["field_manifest"] = sa["field_manifest"] then raise syntax 93.900 array("social and counterfactual full manifests unexpectedly identical")
if ma["field_manifest"]~caselessPos("AS KS") > 0 then raise syntax 93.900 array("hole-card value leaked into field manifest")
if ma["core_manifest"]~caselessPos("your cards") > 0 then raise syntax 93.900 array("prompt value leaked into core manifest")
if ma["core_manifest"]~caselessPos("SELF.HOLE_CARDS|CUSTOMER") = 0 then raise syntax 93.900 array("viewer-owned private provenance absent from manifest")

/* Deliberate non-social structural drift must fail closed. */
drift = .PokerPromptEnvelope~new("GROK")
drift~append("GAME.POT", "PUBLIC", "pot: 50" || "0a"x)
drift~append("GAME.STREET", "PUBLIC", "street: FLOP" || "0a"x)
drift~append("SELF.HOLE_CARDS", "CUSTOMER", "your cards: AS KS" || "0a"x)
drift~append("SOCIAL.COUNTERFACTUAL_POLICY", "PUBLIC", "SOCIAL EVIDENCE DISABLED" || "0a"x)
ignore = drift~finalize
da = drift~auditSummary
if \expectDrift(v, ma, da) then raise syntax 93.900 array("non-social counterfactual manifest drift was not rejected")

say "PASS prompt structural manifest and counterfactual core-equivalence contract"
exit 0

expectDrift: procedure
  use arg verifier, mainAudit, driftAudit
  signal on syntax name rejected
  ignore = verifier~verifyCounterfactual(mainAudit, driftAudit)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

::requires "poker.cls"
