say "LEGAL EFFECT V0.14 SOURCE AUTHORITY ATTESTATION START"
a = .SourceAuthorityAcceptance~new
exit a~run

::class SourceAuthorityAcceptance
::method init
  expose assertions
  assertions = 0

::method identity private
  use arg authority = "DEMO-AUTHORITY", jurisdiction = "TEST-LAND", digest = "testhash:len11-source text"
  return .LegalSourceIdentity~new("LAW-A", "LEGISLATION", "expr-1", "urn:test:law-a", digest, authority, jurisdiction, "VERIFIED")

::method attestation private
  use arg identity, signerId = "A", key = "key-a", policyId = "P1", claimId = "CLAIM-1"
  claim = .LegalSourceAuthorityClaim~new(claimId, policyId, identity~sourceId, identity~sourceKind, identity~expressionId, identity~canonicalUri, identity~contentDigest, identity~authority, identity~jurisdictionId, "2026-08-22T00:00:00Z", "publication-1")
  provider = .LegalTestSignatureProvider~new
  signature = .LegalSourceAuthoritySignature~new(signerId, provider~algorithm, provider~signatureFor(claim~canonicalText, key))
  return .LegalSourceAuthorityAttestation~new(claim, .array~of(signature))

::method profile private
  use arg minimum = 1, required = .nil
  p = .LegalSourceAuthorityTrustProfile~new("HOST")
  ignored = p~addSigner(.LegalTrustedSourceSigner~new("A", "key-a", .array~of("LEGISLATION"), .array~of("DEMO-AUTHORITY"), .array~of("TEST-LAND")))
  ignored = p~addSigner(.LegalTrustedSourceSigner~new("B", "key-b", .array~of("LEGISLATION"), .array~of("DEMO-AUTHORITY"), .array~of("TEST-LAND")))
  ignored = p~addPolicy(.LegalSourceAuthorityPolicy~new("P1", minimum, required))
  return p

::method buildCompiled private
  use arg signerId, key, claimId
  digestProvider = .LegalTestDigestProvider~new
  verifier = .LegalSourceVerifier~new(digestProvider, "authority-test-digest")
  sourceText = "source text"
  provisionText = "must do X"
  sourceDigest = "testhash:" || digestProvider~digest(sourceText)
  provisionDigest = "testhash:" || digestProvider~digest(provisionText)

  unit = .LegalCompilationUnit~new("AUTH-G", "1", "authority-test-compiler", "0.10")
  identity = .LegalSourceIdentity~new("LAW-A", "LEGISLATION", "expr-1", "urn:test:law-a", sourceDigest, "DEMO-AUTHORITY", "TEST-LAND", "VERIFIED")
  source = .NormativeSource~new("LAW-A", "LEGISLATION", "Law A", "DEMO-AUTHORITY", "TEST-LAND")
  ignored = unit~addSource(identity, source)
  reference = .LegalProvisionReference~new("LAW-A", "1", "expr-1", "s.1", provisionDigest, provisionText, "VERIFIED")
  provision = .LegalProvision~new("LAW-A", "1", "ACTIVE", "BASE", provisionText)
  ignored = unit~addProvision(reference, provision)
  sourceDoc = .directory~new
  sourceDoc["content"] = sourceText
  ignored = unit~verifySource("LAW-A", .LegalVerificationMaterial~fromText(sourceDoc, sourceText, "urn:test:law-a", "RAW"), verifier)
  ignored = unit~verifyProvision("LAW-A", "1", .LegalVerificationMaterial~fromText(sourceDoc, provisionText, "s.1", "PROVISION"), verifier)

  internalIdentity = unit~sourceIdentity("LAW-A")
  attestation = self~attestation(internalIdentity, signerId, key, "P1", claimId)
  ignored = unit~addSourceAuthorityAttestation("LAW-A", attestation)

  norm = .LegalNorm~new("N-1", "LAW-A", "1", "OBLIGATION", "X", "REQUIRES_OBLIGATION")
  proposal = .LegalCompileProposal~new("P-N-1", "NORM", norm, "test", "DETERMINISTIC")
  ignored = proposal~addEvidenceReference(unit~provisionReference("LAW-A", "1"))
  ignored = unit~addProposal(proposal)
  return .LegalRuleCompiler~new~compile(unit)

::method run
  expose assertions
  verifier = .LegalSourceAuthorityVerifier~new(.LegalTestSignatureProvider~new)
  identity = self~identity
  profile = self~profile
  attestation = self~attestation(identity)

  evidence = verifier~verify(identity, attestation, profile)
  ok = self~assertTrue(evidence~verified, "valid source authority verifies")
  ok = self~assertEqual("VERIFIED", evidence~statusCode, "valid status")
  ok = self~assertEqual(1, evidence~verifiedSignerIds~items, "one verified signer")
  ok = self~assertEqual("A", evidence~verifiedSignerIds[1], "verified signer id")

  wrongAuthority = self~identity("OTHER-AUTHORITY")
  mismatch = verifier~verify(wrongAuthority, attestation, profile)
  ok = self~assertTrue(\mismatch~verified, "authority replay rejected")
  ok = self~assertEqual("SOURCE_AUTHORITY_CLAIM_MISMATCH", mismatch~statusCode, "authority replay code")

  wrongJurisdiction = self~identity("DEMO-AUTHORITY", "OTHER-LAND")
  mismatch = verifier~verify(wrongJurisdiction, attestation, profile)
  ok = self~assertTrue(\mismatch~verified, "jurisdiction replay rejected")

  wrongDigest = self~identity("DEMO-AUTHORITY", "TEST-LAND", "testhash:changed")
  mismatch = verifier~verify(wrongDigest, attestation, profile)
  ok = self~assertTrue(\mismatch~verified, "digest replay rejected")

  untrustedAttestation = self~attestation(identity, "Z", "key-z")
  untrusted = verifier~verify(identity, untrustedAttestation, profile)
  ok = self~assertTrue(\untrusted~verified, "untrusted signer rejected")
  ok = self~assertEqual("SOURCE_AUTHORITY_SIGNATURE_THRESHOLD_NOT_MET", untrusted~statusCode, "untrusted threshold code")

  scopedProfile = .LegalSourceAuthorityTrustProfile~new("SCOPED")
  ignored = scopedProfile~addSigner(.LegalTrustedSourceSigner~new("A", "key-a", .array~of("CONTRACT"), .array~of("DEMO-AUTHORITY"), .array~of("TEST-LAND")))
  ignored = scopedProfile~addPolicy(.LegalSourceAuthorityPolicy~new("P1", 1))
  scoped = verifier~verify(identity, attestation, scopedProfile)
  ok = self~assertTrue(\scoped~verified, "signer source-kind scope enforced")

  revokedProfile = self~profile
  ignored = revokedProfile~revokeSigner("A")
  revoked = verifier~verify(identity, attestation, revokedProfile)
  ok = self~assertTrue(\revoked~verified, "revoked signer rejected")

  duplicateProfile = .LegalSourceAuthorityTrustProfile~new("DUP")
  first = duplicateProfile~addSigner(.LegalTrustedSourceSigner~new("A", "aa bb"))
  second = duplicateProfile~addSigner(.LegalTrustedSourceSigner~new("B", "aabb"))
  ok = self~assertTrue(first~ok, "first duplicate-key signer accepted")
  ok = self~assertTrue(\second~ok, "same key cannot masquerade as second signer")
  ok = self~assertEqual("SOURCE_AUTHORITY_DUPLICATE_KEY", second~code, "duplicate key code")

  multiProfile = self~profile(2, .array~of("A", "B"))
  claim = attestation~claim
  provider = .LegalTestSignatureProvider~new
  sigA = .LegalSourceAuthoritySignature~new("A", provider~algorithm, provider~signatureFor(claim~canonicalText, "key-a"))
  sigB = .LegalSourceAuthoritySignature~new("B", provider~algorithm, provider~signatureFor(claim~canonicalText, "key-b"))
  multi = .LegalSourceAuthorityAttestation~new(claim, .array~of(sigA, sigB))
  multiEvidence = verifier~verify(identity, multi, multiProfile)
  ok = self~assertTrue(multiEvidence~verified, "two-party attestation satisfies policy")
  ok = self~assertEqual(2, multiEvidence~verifiedSignerIds~items, "two distinct signers counted")

  oneOnly = .LegalSourceAuthorityAttestation~new(claim, .array~of(sigA))
  oneEvidence = verifier~verify(identity, oneOnly, multiProfile)
  ok = self~assertTrue(\oneEvidence~verified, "missing treaty/contract party rejected")
  ok = self~assertEqual("SOURCE_AUTHORITY_REQUIRED_SIGNER_MISSING", oneEvidence~statusCode, "required signer code")

  duplicateSig = .LegalSourceAuthorityAttestation~new(claim, .array~of(sigA, sigA))
  duplicateEvidence = verifier~verify(identity, duplicateSig, multiProfile)
  ok = self~assertTrue(\duplicateEvidence~verified, "duplicate signature does not satisfy threshold")

  reportA = self~buildCompiled("A", "key-a", "CLAIM-A")
  reportB = self~buildCompiled("B", "key-b", "CLAIM-B")
  ok = self~assertTrue(reportA~ok, "attested compilation A succeeds")
  ok = self~assertTrue(reportB~ok, "attested compilation B succeeds")
  ok = self~assertEqual(reportA~generation~semanticIdentity, reportB~generation~semanticIdentity, "signer proof excluded from legal semantic identity")
  ok = self~assertTrue(reportA~inputIdentity \== reportB~inputIdentity, "signer proof included in compilation input identity")
  ok = self~assertTrue(reportA~generation~sourceAuthorityAttestationsPresent, "attested generation advertises source authority material")
  ok = self~assertEqual(1, reportA~certificate~sourceAuthorityAttestations~items, "certificate snapshots authority attestation")

  sourceA = reportA~generation~source("LAW-A")
  ok = self~assertEqual(1, sourceA~sourceIdentity~authorityAttestationCount, "generation retains source attestation")
  ok = self~assertEqual("A", sourceA~sourceIdentity~authorityAttestations[1]~signatures[1]~signerId, "generation retains signer proof")

  unit = .LegalCompilationUnit~new("LATE", "1")
  basicIdentity = self~identity
  basicSource = .NormativeSource~new("LAW-A", "LEGISLATION", "Law A", "DEMO-AUTHORITY", "TEST-LAND")
  ignored = unit~addSource(basicIdentity, basicSource)
  ignored = unit~freeze
  late = unit~addSourceAuthorityAttestation("LAW-A", attestation)
  ok = self~assertTrue(\late~ok, "post-freeze attestation rejected")
  ok = self~assertEqual("COMPILATION_UNIT_FROZEN", late~code, "post-freeze attestation code")

  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 SOURCE AUTHORITY ATTESTATION: OK"
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
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return .true

::requires "LegalEffectAuthorityTestSupport.cls"
