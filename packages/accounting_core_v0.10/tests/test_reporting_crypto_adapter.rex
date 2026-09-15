t = .AccountingTest~new
numeric digits 50

payload = "accounting-reporting-crypto-adapter-fixture-v0.9"
publicKey = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
digest = "1ee2de9faf93e605f23104e8024ab5681e70d932d83805f61b9bac770261f3a8"
signature = "b399b57a88cf86e0438b4b6a3fae8a634e464f3c5b0cbea26972da4668a74774" ||,
            "be453a341db22deddfdc46f4c646b0ff528c63d5701cb5f29376da04dc3bb806"
proof = .AccountingReportingProof~new("ED25519", "SHA256", digest, signature, "KEY:FIXTURE:001", "sha256:rfc8032-seed-fixture")
verifier = .AccountingEd25519ReportingProofVerifier~new(publicKey, "KEY:FIXTURE:001", "sha256:rfc8032-seed-fixture")

t~assertEq("ED25519", verifier~schemeRef, "Crypto adapter scheme")
t~assertEq("SHA256", verifier~digestAlgorithmRef, "Crypto adapter digest")
t~assertTrue(verifier~verifyProof(payload, proof), "precomputed Ed25519 reporting proof verifies")
t~assertTrue(\verifier~verifyProof(payload || "x", proof), "payload tamper rejected")
badDigest = .AccountingReportingProof~new("ED25519", "SHA256", "0" || digest~substr(2), signature, "KEY:FIXTURE:001", "sha256:rfc8032-seed-fixture")
t~assertTrue(\verifier~verifyProof(payload, badDigest), "digest tamper rejected before signature acceptance")
badSignature = .AccountingReportingProof~new("ED25519", "SHA256", digest, "f" || signature~substr(2), "KEY:FIXTURE:001", "sha256:rfc8032-seed-fixture")
t~assertTrue(\verifier~verifyProof(payload, badSignature), "signature tamper rejected")
wrongKeyIdentity = .AccountingEd25519ReportingProofVerifier~new(publicKey, "KEY:FIXTURE:001", "sha256:other-key")
t~assertTrue(\wrongKeyIdentity~verifyProof(payload, proof), "exact key identity enforced by adapter")

say "reporting crypto adapter assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::options digits 50
::requires "AccountingReportingCrypto.cls"
::requires "TestSupport.cls"
