say "LEGAL EFFECT V0.14 COMPILER BOUNDARY START"
a = .CompilerBoundaryAcceptance~new
exit a~run

::class CompilerBoundaryAcceptance
::method init
  expose assertions
  assertions = 0

::method buildUnit private
  use arg compilerId = "compiler-a", sourceVariant = "source-one", verified = .true, includeEvidence = .true
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "compiler-boundary-verifier")
  verifyState = "VERIFIED"
  sourceText = "Synthetic Law A / " || sourceVariant
  text = "A regulated operator must obtain approval before ACTION-X."
  sourceDoc = .directory~new
  sourceDoc["content"] = sourceText

  unit = .LegalCompilationUnit~new("COMPILED-G1", "1", compilerId, "0.6")
  identity = .LegalSourceIdentity~new("LAW-A", "LEGISLATION", "expr-2026-01", "urn:test:law-a", "sha512:" || provider~digest(sourceText), "TEST-AUTH", "TEST-LAND", verifyState)
  source = .NormativeSource~new("LAW-A", "LEGISLATION", "Synthetic Law A", "TEST-AUTH", "TEST-LAND")
  addSource = unit~addSource(identity, source)
  if \addSource~ok then raise syntax 88.900 array(addSource~code)

  reference = .LegalProvisionReference~new("LAW-A", "11.12", "expr-2026-01", "s.11(12)", "sha512:" || provider~digest(text), text, verifyState)
  provision = .LegalProvision~new("LAW-A", "11.12", "ACTIVE", "BASE", text)
  addProvision = unit~addProvision(reference, provision)
  if \addProvision~ok then raise syntax 88.900 array(addProvision~code)

  if verified then do
    ignored = unit~verifySource("LAW-A", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:law-a", "RAW_NORMATIVE_SOURCE"), verifier)
    ignored = unit~verifyProvision("LAW-A", "11.12", .LegalVerificationMaterial~fromText(sourceDoc, text, "s.11(12)", "PROVISION_LEXICAL_TEXT"), verifier)
  end

  norm = .LegalNorm~new("NORM-A", "LAW-A", "11.12", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION", "TEST", "synthetic compiler-boundary rule")
  ignored = norm~addCondition(.LegalPredicate~new("REGULATED_OPERATOR", "KNOWN_TRUE"))
  proposal = .LegalCompileProposal~new("P-NORM-A", "NORM", norm, "llm:test-model", "LLM", "0.91")
  if includeEvidence then ignored = proposal~addEvidenceReference(reference)
  addProposal = unit~addProposal(proposal)
  if \addProposal~ok then raise syntax 88.900 array(addProposal~code)
  return unit

::method run
  expose assertions
  compiler = .LegalRuleCompiler~new

  unit = self~buildUnit
  report = compiler~compile(unit)
  ok = self~assertTrue(report~ok, "valid source-anchored compilation succeeds")
  generation = report~generation
  ok = self~assertTrue(generation \== .nil, "successful compilation returns generation")
  ok = self~assertTrue(generation~sealed, "compiled generation is sealed")
  ok = self~assertTrue(generation~publicationEligible, "compiled generation is publication eligible")
  ok = self~assertTrue(generation~compilationCertificate \== .nil, "compiled generation carries certificate")
  ok = self~assertEqual("compiler-a", generation~compilationCertificate~compilerId, "compiler identity retained outside legal semantic graph")
  ok = self~assertTrue(generation~source("LAW-A")~sourceIdentity~verificationEvidence \== .nil, "source identity carries verifier evidence")
  ok = self~assertTrue(generation~provision("LAW-A", "11.12")~provisionReference~verificationEvidence \== .nil, "provision reference carries verifier evidence")
  norms = generation~norms
  ok = self~assertEqual(1, norms~items, "one norm compiled")
  ok = self~assertEqual(1, norms[1]~evidence~items, "proposal evidence promoted into norm evidence")
  ok = self~assertEqual("LLM", norms[1]~evidence[1]~metadata["producerKind"], "LLM provenance retained as evidence metadata")

  facts = .LegalFactSet~new
  ignored = facts~putKnown("REGULATED_OPERATOR", .true, "fixture")
  context = .LegalContext~new("E1", "2026-08-20", "2026-08-20", facts)
  ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("TEST-AUTH", "TEST-LAND", "TEST", "fixture"))
  evaluation = .LegalEffectEngine~new~evaluate(.LegalAction~new("ACTION-X"), generation, context)
  ok = self~assertTrue(evaluation~ok, "compiled generation evaluates")
  assessment = evaluation~value
  ok = self~assertEqual("CONDITIONAL", assessment~status, "compiled norm executes deterministically")

  missingEvidence = compiler~compile(self~buildUnit("compiler-a", "source-one", .true, .false))
  ok = self~assertTrue(\missingEvidence~ok, "proposal without evidence is rejected")
  ok = self~assertTrue(self~hasDiagnostic(missingEvidence, "PROPOSAL_EVIDENCE_MISSING"), "missing evidence diagnostic emitted")
  ok = self~assertTrue(missingEvidence~generation == .nil, "failed compilation yields no generation")

  unverified = compiler~compile(self~buildUnit("compiler-a", "source-one", .false, .true))
  ok = self~assertTrue(\unverified~ok, "asserted VERIFIED without verifier evidence is rejected")
  ok = self~assertTrue(self~hasDiagnostic(unverified, "SOURCE_VERIFICATION_EVIDENCE_MISSING"), "source verifier evidence diagnostic emitted")
  ok = self~assertTrue(self~hasDiagnostic(unverified, "PROVISION_VERIFICATION_EVIDENCE_MISSING"), "provision verifier evidence diagnostic emitted")

  manualSource = .NormativeSource~new("MANUAL", "LEGISLATION", "Manual")
  manualGeneration = .LegalRuleGeneration~new("MANUAL-G", "1")
  ignored = manualGeneration~addSource(manualSource)
  ignored = manualGeneration~seal
  ok = self~assertTrue(manualGeneration~sealed, "manual generation can still be sealed for offline work")
  ok = self~assertTrue(\manualGeneration~publicationEligible, "manual seal alone is not publication authority")

  spoofGeneration = .LegalRuleGeneration~new("SPOOF-G", "1")
  spoofCertificate = .LegalCompilationCertificate~new("fake", "1", "fake-input", 0, 0, 0)
  spoofResult = spoofGeneration~certifyCompilation(spoofCertificate)
  ok = self~assertTrue(\spoofResult~ok, "caller cannot self-certify a generation")
  ok = self~assertEqual("COMPILATION_AUTHORITY_REQUIRED", spoofResult~code, "self-certification rejection is explicit")

  compilerB = compiler~compile(self~buildUnit("compiler-b", "source-one", .true, .true))
  ok = self~assertTrue(compilerB~ok, "second compiler can independently produce same graph")
  ok = self~assertEqual(generation~semanticIdentity, compilerB~generation~semanticIdentity, "compiler identity does not alter legal semantic identity")

  digestChanged = compiler~compile(self~buildUnit("compiler-a", "source-two", .true, .true))
  ok = self~assertTrue(digestChanged~ok, "alternate verified source content compiles")
  ok = self~assertTrue(generation~semanticIdentity \== digestChanged~generation~semanticIdentity, "source content identity changes legal semantic identity")

  provider = .LegalSha512DigestProvider~new
  verifier = .LegalSourceVerifier~new(provider, "compiler-boundary-verifier")
  badUnit = .LegalCompilationUnit~new("BAD-G", "1", "compiler-a", "0.6")
  sourceText = "Law B source"
  identity = .LegalSourceIdentity~new("LAW-B", "LEGISLATION", "expr-b", "urn:test:law-b", "sha512:" || provider~digest(sourceText), "AUTH-B", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new("LAW-B", "LEGISLATION", "Law B", "AUTH-B", "TEST-LAND")
  ignored = badUnit~addSource(identity, source)
  text = "Provision B."
  reference = .LegalProvisionReference~new("LAW-B", "2", "expr-b", "s.2", "sha512:" || provider~digest(text), text, "VERIFIED")
  provision = .LegalProvision~new("LAW-B", "2", "ACTIVE", "BASE", text)
  ignored = badUnit~addProvision(reference, provision)
  sourceDoc = .directory~new; sourceDoc["content"] = sourceText
  ignored = badUnit~verifySource("LAW-B", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:law-b"), verifier)
  ignored = badUnit~verifyProvision("LAW-B", "2", .LegalVerificationMaterial~fromText(sourceDoc, text, "s.2", "PROVISION_LEXICAL_TEXT"), verifier)
  sealedNorm = .LegalNorm~new("SEALED-N", "LAW-B", "2", "PROHIBITION", "ACTION-Y", "PROHIBITED")
  ignored = sealedNorm~seal
  proposal = .LegalCompileProposal~new("P-SEALED", "NORM", sealedNorm, "tool", "DETERMINISTIC")
  ignored = proposal~addEvidenceReference(reference)
  ignored = badUnit~addProposal(proposal)
  presealed = compiler~compile(badUnit)
  ok = self~assertTrue(\presealed~ok, "pre-sealed semantic proposal rejected")
  ok = self~assertTrue(self~hasDiagnostic(presealed, "PRESEALED_PROPOSAL_REJECTED"), "presealed diagnostic emitted")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 COMPILER BOUNDARY: OK"
  return 0

::method hasDiagnostic private
  use arg report, code
  do diagnostic over report~diagnostics
    if diagnostic~code = code then return .true
  end
  return .false

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
    say "ASSERTION FAILED:" label "expected=" expected "actual=" actual
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalRuntimeCryptoBridge.cls"
