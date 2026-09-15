say "LEGAL EFFECT V0.14 RULE SEALING START"
a = .LegalSealingAcceptance~new
exit a~run

::class LegalSealingAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  metadata = .table~new
  metadata["compiler"] = "candidate-a"
  anchor = .LegalEvidenceAnchor~new("SRC-EVIDENCE", "LEGISLATION", "s.1", .nil, "SYNTHETIC", metadata)
  source = .NormativeSource~new("SRC", "LEGISLATION", "Synthetic source", "SYNTHETIC", "TEST")
  ignored = source~addEvidence(anchor)
  provision = .LegalProvision~new(source~sourceId, "1", "ACTIVE", "BASE", "synthetic text")
  ignored = provision~addEvidence(anchor)
  norm = .LegalNorm~new("NORM-1", source~sourceId, "1", "PROHIBITION", "DO_THING", "PROHIBITED", "TEST", "synthetic", .nil, "BASE")
  ignored = norm~addCondition(.LegalPredicate~new("TRIGGER", "KNOWN_TRUE"))
  ignored = norm~addEvidence(anchor)
  modification = .LegalModificationEffect~new("MOD-1", source~sourceId, "2", "SUBSTITUTE", source~sourceId, "1", .LegalTemporalScope~new("2027-01-01", "2027-01-01", "", "2027-01-01", ""), 10, "V2", "new text")
  ignored = modification~addCondition(.LegalPredicate~new("AMENDMENT_GATE", "KNOWN_TRUE"))
  ignored = modification~addEvidence(anchor)

  gen = .LegalRuleGeneration~new("SEAL-G1", "0.2")
  ignored = gen~addSource(source)
  ignored = gen~addProvision(provision)
  ignored = gen~addNorm(norm)
  ignored = gen~addModification(modification)
  ignored = gen~seal

  ok = self~assertTrue(gen~sealed, "generation sealed")
  ok = self~assertTrue(source~sealed, "source sealed")
  ok = self~assertTrue(provision~sealed, "provision sealed")
  ok = self~assertTrue(norm~sealed, "norm sealed")
  ok = self~assertTrue(modification~sealed, "modification sealed")
  ok = self~assertTrue(\norm~addCondition(.LegalPredicate~new("ILLEGAL_MUTATION", "KNOWN_TRUE"))~ok, "sealed norm rejects mutation")
  ok = self~assertTrue(\modification~addCondition(.LegalPredicate~new("ILLEGAL_MUTATION", "KNOWN_TRUE"))~ok, "sealed modification rejects mutation")
  ok = self~assertTrue(\provision~addEvidence(anchor)~ok, "sealed provision rejects evidence mutation")
  ok = self~assertTrue(\source~addEvidence(anchor)~ok, "sealed source rejects evidence mutation")

  conditionCopy = norm~conditions
  conditionCopy~append(.LegalPredicate~new("COPY_ONLY", "KNOWN_TRUE"))
  ok = self~assertEqual(1, norm~conditions~items, "norm condition accessor is copy-on-read")

  modificationConditionCopy = modification~conditions
  modificationConditionCopy~append(.LegalPredicate~new("COPY_ONLY", "KNOWN_TRUE"))
  ok = self~assertEqual(1, modification~conditions~items, "modification condition accessor is copy-on-read")

  evidenceCopy = source~evidence
  evidenceCopy~append(.LegalEvidenceAnchor~new("OTHER", "TEST", "x"))
  ok = self~assertEqual(1, source~evidence~items, "source evidence accessor is copy-on-read")

  normEvidenceCopy = norm~evidence
  normEvidenceCopy~empty
  ok = self~assertEqual(1, norm~evidence~items, "norm evidence accessor is copy-on-read")

  metaCopy = anchor~metadata
  metaCopy["compiler"] = "tampered"
  ok = self~assertEqual("candidate-a", anchor~metadata["compiler"], "evidence metadata accessor is copy-on-read")
  provenance = anchor~provenance
  provenanceMeta = provenance["metadata"]
  provenanceMeta["compiler"] = "tampered-again"
  ok = self~assertEqual("candidate-a", anchor~metadata["compiler"], "provenance metadata is detached copy")

  generationNormCopy = gen~norms
  generationNormCopy~empty
  ok = self~assertEqual(1, gen~normCount, "generation norm list is copy-on-read")
  generationModificationCopy = gen~modifications
  generationModificationCopy~empty
  ok = self~assertEqual(1, gen~modificationCount, "generation modification list is copy-on-read")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 RULE SEALING: OK"
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
    say " expected=" expected
    say " actual=" actual
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalEffect.cls"
