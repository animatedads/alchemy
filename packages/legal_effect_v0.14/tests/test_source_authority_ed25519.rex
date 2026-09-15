say "LEGAL EFFECT V0.14 SOURCE AUTHORITY ED25519 START"
a = .Ed25519SourceAuthorityAcceptance~new
exit a~run

::class Ed25519SourceAuthorityAcceptance
::method init
  expose assertions
  assertions = 0

::method run
  expose assertions
  publicKey = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  signatureHex = "999db0cea36db54a617bdb2663c562b428dff651c3713f2f311cba1ef974e1fb7ee7c9237037282370d969b0eb079c3c93f69a651d16d0416e7a4f9a35ad4b05"
  identity = .LegalSourceIdentity~new("LAW-RFC", "LEGISLATION", "expr-rfc", "urn:test:rfc", "sha512:00", "RFC-AUTH", "TEST-LAND", "VERIFIED")
  claim = .LegalSourceAuthorityClaim~new("RFC8032-CLAIM", "RFC8032-POLICY", "LAW-RFC", "LEGISLATION", "expr-rfc", "urn:test:rfc", "sha512:00", "RFC-AUTH", "TEST-LAND", "2026-08-22T00:00:00Z", "urn:test:rfc:pub")
  signature = .LegalSourceAuthoritySignature~new("RFC8032-SIGNER", "ED25519", signatureHex)
  attestation = .LegalSourceAuthorityAttestation~new(claim, .array~of(signature))
  profile = .LegalSourceAuthorityTrustProfile~new("RFC8032-HOST")
  addSigner = profile~addSigner(.LegalTrustedSourceSigner~new("RFC8032-SIGNER", publicKey, .array~of("LEGISLATION"), .array~of("RFC-AUTH"), .array~of("TEST-LAND")))
  ok = self~assertTrue(addSigner~ok, "RFC signer trusted")
  addPolicy = profile~addPolicy(.LegalSourceAuthorityPolicy~new("RFC8032-POLICY", 1, .array~of("RFC8032-SIGNER")))
  ok = self~assertTrue(addPolicy~ok, "RFC policy trusted")
  verifier = .LegalSourceAuthorityVerifier~new(.LegalEd25519SignatureProvider~new)
  evidence = verifier~verify(identity, attestation, profile)
  ok = self~assertTrue(evidence~verified, "real Ed25519 verifies source authority claim")
  ok = self~assertEqual("RFC8032-SIGNER", evidence~verifiedSignerIds[1], "real signer retained")
  say "  assertions=" || assertions
  say "LEGAL EFFECT V0.14 SOURCE AUTHORITY ED25519: OK"
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

::requires "LegalRuntimeCryptoBridge.cls"
