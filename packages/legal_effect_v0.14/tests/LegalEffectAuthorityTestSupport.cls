::class LegalTestDigestProvider public
::method algorithm
  return "TESTHASH"
::method digest
  use arg material
  text = material~string
  return "len" || text~length || "-" || text


::class LegalTestSignatureProvider public
::method algorithm
  return "TEST-SIG"

::method signatureFor
  use arg message, publicKey
  return "TESTSIG|" || publicKey~string~space(0)~lower || "|" || message~string

::method verify
  use arg message, signatureValue, publicKey
  return signatureValue~string = self~signatureFor(message, publicKey)


::class LegalAuthorityTestSupport public

::method trustProfile class
  use arg profileId = "host-test-profile", minimum = 1, required = .nil
  profile = .LegalSourceAuthorityTrustProfile~new(profileId)
  ignored = profile~addSigner(.LegalTrustedSourceSigner~new("DEMO-SIGNER", "demo-key", .array~of("CONTRACT", "LEGISLATION", "TREATY", "POLICY"), .array~of("DEMO-PARTIES", "DEMO-AUTHORITY", "*"), .array~of("*")))
  ignored = profile~addPolicy(.LegalSourceAuthorityPolicy~new("DEMO-SOURCE-POLICY", minimum, required))
  return profile

::method attestation class
  use arg identity, signerId = "DEMO-SIGNER", publicKey = "demo-key", policyId = "DEMO-SOURCE-POLICY", claimId = "DEMO-AUTHORITY-CLAIM"
  claim = .LegalSourceAuthorityClaim~new(claimId, policyId, identity~sourceId, identity~sourceKind, identity~expressionId, identity~canonicalUri, identity~contentDigest, identity~authority, identity~jurisdictionId, "2026-08-22T00:00:00Z", identity~canonicalUri)
  provider = .LegalTestSignatureProvider~new
  signature = .LegalSourceAuthoritySignature~new(signerId, provider~algorithm, provider~signatureFor(claim~canonicalText, publicKey))
  return .LegalSourceAuthorityAttestation~new(claim, .array~of(signature))

::method verifier class
  return .LegalSourceAuthorityVerifier~new(.LegalTestSignatureProvider~new)

::requires "LegalEffect.cls"
