call main
exit 0

main:
  say "RUNTIME REGISTRY V0.2 CRYPTO VERIFIER START"

  pub = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
  sourceDigest = "00a7cbcb02c84cb6742f57501ddcfffef2fd1d49c12ea5dfe690be213cdc47bb41c8c6c33f72cb06b88f49cb4e8fe3776acf215e6506e4f4568a89629f072d41"
  signature = "e76ffdabc4141a2b2dd9cc3cfd63e5c9e6a9068db622ae0c894358008d481fab60e80616d0f50c18a93e959ec319ab8bc3e6ab259d454189af2fa033a6908b04"

  loaded = .RuntimeArtifactFactory~fromFiles("fixtures/modules/DemoCapability_v1.rrmf", "fixtures/modules/DemoCapability_v1.cls")
  call mustOk loaded, "load signed manifest + source"
  artifact = loaded~value
  sourceLines = artifact~sourceLines
  manifest = artifact~manifest

  trust = .RuntimeTrustStore~new
  signer = .RuntimeTrustedSigner~new("rfc8032-test", pub, .array~of("test", "live", "prod"), .array~of("CAPABILITY"))
  call mustOk trust~addSigner(signer), "trust test signer"
  verifier = .RuntimeEd25519ReferenceVerifier~new(trust)
  kernel = .RuntimeKernel~new(verifier)

  r = kernel~stage("test", artifact)
  call mustOk r, "signed artifact verifies and stages in test"
  call assertEq 1, verifier~cryptoVerificationCount, "one cryptographic verification"
  call assertEq 0, verifier~cacheHitCount, "no cache hit on first verification"

  r2 = kernel~stage("live", artifact)
  call mustOk r2, "same immutable artifact stages in live"
  call assertEq 1, verifier~cryptoVerificationCount, "same artifact object not re-verified cryptographically"
  call assertEq 1, verifier~cacheHitCount, "cache reused after live trust policy recheck"

  tamperedLines = copyLines(sourceLines)
  tamperedLines~append("/* tampered */")
  tampered = .RuntimeArtifact~new(manifest, tamperedLines, "tampered")
  bad = kernel~stage("prod", tampered)
  call assertFalse bad~ok, "tampered source rejected"
  call assertEq "ARTIFACT_SOURCE_DIGEST_MISMATCH", bad~code, "tamper digest mismatch code"

  untrustedManifest = .RuntimeManifest~new("demo.untrusted", "CAPABILITY", "1", "fixture:untrusted", "DemoCapability", .nil, .array~of("prod"), "runtime.module/0.2", "unknown-signer", sourceDigest, signature)
  untrusted = .RuntimeArtifact~new(untrustedManifest, sourceLines, "untrusted")
  beforeCrypto = verifier~cryptoVerificationCount
  bad = kernel~stage("prod", untrusted)
  call assertFalse bad~ok, "untrusted signer rejected"
  call assertEq "SIGNER_UNTRUSTED", bad~code, "untrusted signer code"
  call assertEq beforeCrypto, verifier~cryptoVerificationCount, "untrusted signer rejected before crypto"

  call mustOk trust~revoke("rfc8032-test"), "revoke signer"
  beforeCrypto = verifier~cryptoVerificationCount
  bad = kernel~stage("prod", artifact)
  call assertFalse bad~ok, "revocation defeats cached crypto success"
  call assertEq "SIGNER_REVOKED", bad~code, "revocation code"
  call assertEq beforeCrypto, verifier~cryptoVerificationCount, "revoked signer rejected before crypto"

  say "  crypto_verifications=" || verifier~cryptoVerificationCount
  say "  cache_hits=" || verifier~cacheHitCount
  say "RUNTIME REGISTRY V0.2 CRYPTO VERIFIER: OK"
  return

mustOk:
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 30
  end
  return

assertFalse:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 31
  end
  return

assertEq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 32
  end
  return

readLines:
  use arg path
  s=.Stream~new(path); o=s~open("read")
  if o <> "READY:" then do; say "open failed" path o; exit 33; end
  a=.array~new
  do while s~lines > 0; a~append(s~lineIn); end
  c=s~close
  return a

copyLines:
  use arg source
  a=.array~new
  do i=1 to source~items; a~append(source~at(i)); end
  return a

::requires "RuntimeCryptoVerifier.cls"
