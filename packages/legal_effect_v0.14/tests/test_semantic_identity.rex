say "LEGAL EFFECT V0.14 SEMANTIC IDENTITY START"
a = .LegalSemanticIdentityAcceptance~new
exit a~run

::class PoisonEvidenceObject
::method string
  raise syntax 88.900 array("STRING must not be used for evidence identity")

::class StableEvidenceObject
::attribute token get
::method init
  expose token
  use arg tokenArg
  token = tokenArg~string
::method evidenceIdentity
  expose token
  return "stable-evidence/" || token
::method string
  raise syntax 88.900 array("STRING must not be used when evidenceIdentity exists")

::class LegalSemanticIdentityAcceptance
::method init
  expose assertions
  assertions = 0

::method buildGeneration private
  use arg reverseOrder = .false, changedDisposition = .false, evidenceObject = .nil
  meta = .table~new
  meta["compiler"] = "candidate-a"
  meta["interpretation"] = "reviewed"
  anchor = .LegalEvidenceAnchor~new("AUTH-SRC-1", "LEGISLATION", "s.11(12)", evidenceObject, "SYNTHETIC_AUTHORITY", meta)

  sourceA = .NormativeSource~new("LAW-A", "LEGISLATION", "Synthetic Law A", "AUTH-A", "TEST-LAND")
  ignored = sourceA~addEvidence(anchor)
  sourceB = .NormativeSource~new("CONTRACT-B", "CONTRACT", "Synthetic Contract B", "PARTIES", "*", "TEST-LAW")

  provisionA = .LegalProvision~new("LAW-A", "11.12", "ACTIVE", "BASE", "A person must not perform X.")
  ignored = provisionA~addEvidence(anchor)
  provisionB = .LegalProvision~new("CONTRACT-B", "4.2", "ACTIVE", "BASE", "Party shall provide notice.")

  scope = .LegalTemporalScope~new("2026-01-01", "2026-01-01", "", "2026-01-01", "")
  if changedDisposition then disposition = "REQUIRES_REVIEW"
  else disposition = "PROHIBITED"
  normA = .LegalNorm~new("NORM-A", "LAW-A", "11.12", "PROHIBITION", "DO_X", disposition, "TEST", "synthetic", scope, "BASE")
  ignored = normA~addCondition(.LegalPredicate~new("ACTOR_STATUS", "EQUALS", "DRIVER"))
  ignored = normA~addJurisdiction(.LegalJurisdictionClaim~new("AUTH-A", "TEST-LAND", "TEST", "territorial"))
  ignored = normA~addEvidence(anchor)

  normB = .LegalNorm~new("NORM-B", "CONTRACT-B", "4.2", "CONTRACT_TERM", "CHANGE_RATE", "CONTRACT_BREACH", "CONTRACT", "synthetic")
  ignored = normB~addCondition(.LegalPredicate~new("NOTICE_GIVEN", "KNOWN_FALSE"))

  modification = .LegalModificationEffect~new("MOD-A", "LAW-A", "2", "SUBSTITUTE", "LAW-A", "11.12", .LegalTemporalScope~new("2027-01-01", "2027-01-01", "", "2027-01-01", ""), 10, "V2", "A person must not perform X or Y.")
  ignored = modification~addJurisdiction(.LegalJurisdictionClaim~new("AUTH-A", "TEST-LAND", "TEST", "territorial"))

  gen = .LegalRuleGeneration~new("SEMANTIC-G1", "0.2")
  if reverseOrder then do
    ignored = gen~addSource(sourceB)
    ignored = gen~addSource(sourceA)
    ignored = gen~addProvision(provisionB)
    ignored = gen~addProvision(provisionA)
    ignored = gen~addNorm(normB)
    ignored = gen~addNorm(normA)
  end
  else do
    ignored = gen~addSource(sourceA)
    ignored = gen~addSource(sourceB)
    ignored = gen~addProvision(provisionA)
    ignored = gen~addProvision(provisionB)
    ignored = gen~addNorm(normA)
    ignored = gen~addNorm(normB)
  end
  ignored = gen~addModification(modification)
  ignored = gen~seal
  return gen

::method run
  expose assertions
  genA = self~buildGeneration(.false, .false, .StableEvidenceObject~new("ONE"))
  genB = self~buildGeneration(.true, .false, .StableEvidenceObject~new("ONE"))
  genChanged = self~buildGeneration(.false, .true, .StableEvidenceObject~new("ONE"))
  genEvidenceChanged = self~buildGeneration(.false, .false, .StableEvidenceObject~new("TWO"))
  genOpaque = self~buildGeneration(.false, .false, .PoisonEvidenceObject~new)

  ok = self~assertEqual(genA~semanticIdentity, genB~semanticIdentity, "insertion order does not change semantic identity")
  ok = self~assertTrue(genA~semanticIdentity \== genChanged~semanticIdentity, "normative disposition change changes semantic identity")
  ok = self~assertTrue(genA~semanticIdentity \== genEvidenceChanged~semanticIdentity, "declared evidence identity change changes semantic identity")
  opaqueText = genOpaque~semanticIdentity
  ok = self~assertTrue(opaqueText~pos("OPAQUE:") > 0, "opaque evidence object is represented without STRING")
  ok = self~assertTrue(genA~semanticIdentity~startsWith("LEGAL-EFFECT-SEMANTIC/1"), "identity is version-framed canonical text")

  unsealed = .LegalRuleGeneration~new("UNSEALED", "0.2")
  caught = .false
  signal on syntax name expectedUnsealed
  ignored = unsealed~canonicalText
  signal off syntax
  signal afterUnsealed
expectedUnsealed:
  caught = .true
  signal off syntax
afterUnsealed:
  ok = self~assertTrue(caught, "unsealed generation has no executable semantic identity")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 SEMANTIC IDENTITY: OK"
  return 0

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then raise syntax 88.900 array(label)
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then do
    say "ASSERTION FAILED:" label
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalEffect.cls"
