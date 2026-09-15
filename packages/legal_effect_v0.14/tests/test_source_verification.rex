say "LEGAL EFFECT V0.14 SOURCE VERIFICATION START"
a = .SourceVerificationAcceptance~new
exit a~run

::class SourceVerificationAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  provider = .LegalSha512DigestProvider~new("runtime-registry-sha512")
  verifier = .LegalSourceVerifier~new(provider, "legal-source-verifier-v0.9")

  sourceText = "Section 1. A regulated operator must obtain approval before ACTION-X."
  provisionText = "A regulated operator must obtain approval before ACTION-X."
  sourceDoc = .directory~new
  sourceDoc["kind"] = "SYNTHETIC_NORMATIVE_TEXT"
  sourceDoc["text"] = sourceText
  provisionDoc = .directory~new
  provisionDoc["kind"] = "SYNTHETIC_PROVISION_TEXT"
  provisionDoc["text"] = provisionText

  sourceDigest = "sha512:" || provider~digest(sourceText)
  provisionDigest = "sha512:" || provider~digest(provisionText)

  unit = .LegalCompilationUnit~new("VERIFIED-G1", "1", "compiler-v06", "0.6")
  identity = .LegalSourceIdentity~new("LAW-V", "LEGISLATION", "expr-v1", "urn:test:law-v", sourceDigest, "AUTH-V", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new("LAW-V", "LEGISLATION", "Verified Law", "AUTH-V", "TEST-LAND")
  ignored = unit~addSource(identity, source)

  reference = .LegalProvisionReference~new("LAW-V", "1", "expr-v1", "s.1", provisionDigest, provisionText, "VERIFIED")
  provision = .LegalProvision~new("LAW-V", "1", "ACTIVE", "BASE", provisionText)
  ignored = unit~addProvision(reference, provision)

  norm = .LegalNorm~new("NORM-V", "LAW-V", "1", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION", "TEST", "verified source rule")
  proposal = .LegalCompileProposal~new("P-V", "NORM", norm, "fixture", "TOOL", "1")
  ignored = proposal~addEvidenceReference(reference)
  ignored = unit~addProposal(proposal)

  pre = .LegalRuleCompiler~new~compile(unit)
  ok = self~assertTrue(\pre~ok, "asserted VERIFIED without evidence is rejected")
  ok = self~assertTrue(self~hasDiagnostic(pre, "SOURCE_VERIFICATION_EVIDENCE_MISSING"), "missing source verification evidence is explicit")
  ok = self~assertTrue(self~hasDiagnostic(pre, "PROVISION_VERIFICATION_EVIDENCE_MISSING"), "missing provision verification evidence is explicit")
  postFailureMutation = unit~verifySource("LAW-V", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:law-v", "RAW_NORMATIVE_SOURCE"), verifier)
  ok = self~assertEqual("COMPILATION_UNIT_FROZEN", postFailureMutation~code, "failed compilation consumes/freeze input")

  /* v0.9 requires a fresh compilation unit after any compile attempt. */
  unit = .LegalCompilationUnit~new("VERIFIED-G1", "1", "compiler-v09", "0.9")
  identity = .LegalSourceIdentity~new("LAW-V", "LEGISLATION", "expr-v1", "urn:test:law-v", sourceDigest, "AUTH-V", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new("LAW-V", "LEGISLATION", "Verified Law", "AUTH-V", "TEST-LAND")
  ignored = unit~addSource(identity, source)
  reference = .LegalProvisionReference~new("LAW-V", "1", "expr-v1", "s.1", provisionDigest, provisionText, "VERIFIED")
  provision = .LegalProvision~new("LAW-V", "1", "ACTIVE", "BASE", provisionText)
  ignored = unit~addProvision(reference, provision)

  sourceMaterial = .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:law-v", "RAW_NORMATIVE_SOURCE")
  sourceVerifyResult = unit~verifySource("LAW-V", sourceMaterial, verifier)
  ok = self~assertTrue(sourceVerifyResult~ok, "source verification binding succeeds")
  sourceEvidence = sourceVerifyResult~value
  ok = self~assertTrue(sourceEvidence~verified, "source digest matches retained material")
  ok = self~assertTrue(sourceEvidence~sourceObject == sourceDoc, "source verification retains source object identity")
  verifiedIdentity = unit~sourceIdentity("LAW-V")
  ok = self~assertEqual("VERIFIED", verifiedIdentity~verificationState, "source verification state derived from evidence")
  ok = self~assertEqual("VERIFIED", verifiedIdentity~assertedVerificationState, "caller assertion remains visible but non-authoritative")
  originalEvidenceId = verifiedIdentity~verificationEvidence~evidenceIdentity
  secondBind = verifier~bindSource(verifiedIdentity, .LegalVerificationMaterial~fromText(sourceDoc, sourceText || " tampered", "urn:test:law-v", "RAW_NORMATIVE_SOURCE"))
  ok = self~assertEqual(originalEvidenceId, secondBind~evidenceIdentity, "source verification is one-shot and cannot be rebound")
  ok = self~assertEqual(originalEvidenceId, verifiedIdentity~verificationEvidence~evidenceIdentity, "bound verification evidence remains immutable")

  provisionMaterial = .LegalVerificationMaterial~fromText(provisionDoc, provisionText, "s.1", "PROVISION_LEXICAL_TEXT")
  provisionVerifyResult = unit~verifyProvision("LAW-V", "1", provisionMaterial, verifier)
  ok = self~assertTrue(provisionVerifyResult~ok, "provision verification binding succeeds")
  provisionEvidence = provisionVerifyResult~value
  norm = .LegalNorm~new("NORM-V", "LAW-V", "1", "OBLIGATION", "ACTION-X", "REQUIRES_OBLIGATION", "TEST", "verified source rule")
  proposal = .LegalCompileProposal~new("P-V", "NORM", norm, "fixture", "TOOL", "1")
  ignored = proposal~addEvidenceReference(unit~provisionReference("LAW-V", "1"))
  ignored = unit~addProposal(proposal)
  ok = self~assertTrue(provisionEvidence~verified, "provision digest matches retained material")
  ok = self~assertTrue(provisionEvidence~parentEvidence == sourceEvidence, "provision verification links verified parent source")
  ok = self~assertEqual("VERIFIED", unit~provisionReference("LAW-V", "1")~verificationState, "provision verification state derived from evidence")

  report = .LegalRuleCompiler~new~compile(unit)
  ok = self~assertTrue(report~ok, "evidence-verified compilation succeeds")
  ok = self~assertTrue(report~generation~publicationEligible, "evidence-verified generation is publication eligible")
  certificateEvidence = report~certificate~verificationEvidence
  ok = self~assertEqual(2, certificateEvidence~items, "compiler certificate snapshots source and provision verification")
  ok = self~assertTrue(certificateEvidence[1]~sourceObject == sourceDoc, "compiler verification snapshot retains source object")
  certificateEvidence~append("caller-mutation")
  ok = self~assertEqual(2, report~certificate~verificationEvidence~items, "compiler verification evidence is copy-on-read")

  badIdentity = .LegalSourceIdentity~new("LAW-BAD", "LEGISLATION", "expr-bad", "urn:test:bad", sourceDigest, "AUTH-V", "TEST-LAND", "VERIFIED")
  badMaterial = .LegalVerificationMaterial~fromText(sourceDoc, sourceText || " tampered", "urn:test:bad", "RAW_NORMATIVE_SOURCE")
  badEvidence = verifier~bindSource(badIdentity, badMaterial)
  ok = self~assertTrue(\badEvidence~verified, "digest mismatch is retained as failed evidence")
  ok = self~assertEqual("DIGEST_MISMATCH", badEvidence~statusCode, "digest mismatch status is explicit")
  ok = self~assertEqual("UNVERIFIED", badIdentity~verificationState, "failed evidence cannot manufacture VERIFIED")

  say "LEGAL EFFECT V0.14 SOURCE VERIFICATION: OK assertions=" || assertions
  return 0

::method hasDiagnostic
  use arg report, code
  do diagnostic over report~diagnostics
    if diagnostic~code = code then return .true
  end
  return .false

::method assertTrue
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then do
    say "FAIL:" label
    raise syntax 88.900 array(label)
  end
  return .true

::method assertEqual
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then do
    say "FAIL:" label "expected=" expected "actual=" actual
    raise syntax 88.900 array(label)
  end
  return .true

::requires "LegalRuntimeCryptoBridge.cls"
