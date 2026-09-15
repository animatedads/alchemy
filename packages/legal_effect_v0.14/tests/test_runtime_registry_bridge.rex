parse arg root
if root = "" then root = directory()
say "LEGAL EFFECT V0.14 RUNTIME REGISTRY BRIDGE START"
a = .RuntimeBridgeAcceptance~new(root)
exit a~run

::class RuntimeBridgeAcceptance
::method init
  expose root
  use arg root

::method run
  expose root
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  v1Path = root || "/tests/fixtures/DemoLegalRules_v1.cls"
  v2Path = root || "/tests/fixtures/DemoLegalRules_v2.cls"
  v1Lines = .RuntimeSourceLoader~readFile(v1Path)~value
  v2Lines = .RuntimeSourceLoader~readFile(v2Path)~value
  ignored = verifier~pin("legal:demo:v1", v1Lines)
  ignored = verifier~pin("legal:demo:v2", v2Lines)

  a1 = .RuntimeArtifact~new("legal.effect.demo", "LEGAL_RULES", "1", "legal:demo:v1", "DemoLegalRules", v1Lines, .LegalEffectBuild~API_VERSION, v1Path)
  s1 = kernel~stage("prod", a1)
  if \s1~ok then raise syntax 88.900 array("stage v1: " || s1~code || " " || s1~detail)
  x1 = kernel~activate("prod", "legal.effect.demo", s1~value~generationId)
  if \x1~ok then raise syntax 88.900 array("activate v1")

  resolver = .LegalRuntimeRuleResolver~new
  trustProfile = .LegalAuthorityTestSupport~trustProfile
  authorityVerifier = .LegalAuthorityTestSupport~verifier

  missingTrust = resolver~acquire(kernel, "prod", "legal.effect.demo")
  if missingTrust~ok then raise syntax 88.900 array("resolver accepted live legal authority without host trust profile")
  if missingTrust~code <> "LEGAL_SOURCE_AUTHORITY_TRUST_PROFILE_REQUIRED" then raise syntax 88.900 array("wrong missing-trust rejection: " || missingTrust~code)

  missingVerifier = resolver~acquire(kernel, "prod", "legal.effect.demo", trustProfile)
  if missingVerifier~ok then raise syntax 88.900 array("resolver accepted live legal authority without host verifier")
  if missingVerifier~code <> "LEGAL_SOURCE_AUTHORITY_VERIFIER_REQUIRED" then raise syntax 88.900 array("wrong missing-verifier rejection: " || missingVerifier~code)

  strongProfile = .LegalSourceAuthorityTrustProfile~new("HOST-STRONG")
  ignored = strongProfile~addSigner(.LegalTrustedSourceSigner~new("DEMO-SIGNER", "demo-key", .array~of("CONTRACT"), .array~of("DEMO-PARTIES"), .array~of("*")))
  ignored = strongProfile~addSigner(.LegalTrustedSourceSigner~new("SECOND-SIGNER", "second-key", .array~of("CONTRACT"), .array~of("DEMO-PARTIES"), .array~of("*")))
  ignored = strongProfile~addPolicy(.LegalSourceAuthorityPolicy~new("DEMO-SOURCE-POLICY", 2, .array~of("DEMO-SIGNER", "SECOND-SIGNER")))
  strongReject = resolver~acquire(kernel, "prod", "legal.effect.demo", strongProfile, authorityVerifier)
  if strongReject~ok then raise syntax 88.900 array("module-side one-signature claim weakened host two-signature policy")
  if strongReject~code <> "LEGAL_SOURCE_AUTHORITY_REQUIRED_SIGNER_MISSING" then raise syntax 88.900 array("wrong strong-policy rejection: " || strongReject~code)

  oldResult = resolver~acquire(kernel, "prod", "legal.effect.demo", trustProfile, authorityVerifier)
  if \oldResult~ok then raise syntax 88.900 array(oldResult~code || " " || oldResult~detail)
  oldLease = oldResult~value
  if oldLease~generation~generationId <> "DEMO-LEGAL-V1" then raise syntax 88.900 array("wrong v1 legal generation")

  a2 = .RuntimeArtifact~new("legal.effect.demo", "LEGAL_RULES", "2", "legal:demo:v2", "DemoLegalRules", v2Lines, .LegalEffectBuild~API_VERSION, v2Path)
  s2 = kernel~stage("prod", a2)
  if \s2~ok then raise syntax 88.900 array("stage v2: " || s2~code || " " || s2~detail)
  x2 = kernel~activate("prod", "legal.effect.demo", s2~value~generationId)
  if \x2~ok then raise syntax 88.900 array("activate v2")

  newResult = resolver~acquire(kernel, "prod", "legal.effect.demo", trustProfile, authorityVerifier)
  if \newResult~ok then raise syntax 88.900 array(newResult~code || " " || newResult~detail)
  newLease = newResult~value
  if oldLease~generation~generationId <> "DEMO-LEGAL-V1" then raise syntax 88.900 array("old legal lease changed after activation")
  if newLease~generation~generationId <> "DEMO-LEGAL-V2" then raise syntax 88.900 array("new lease did not see v2")
  revokedProfile = .LegalAuthorityTestSupport~trustProfile("HOST-REVOKED")
  ignored = revokedProfile~revokeSigner("DEMO-SIGNER")
  revokedAcquire = resolver~acquire(kernel, "prod", "legal.effect.demo", revokedProfile, authorityVerifier)
  if revokedAcquire~ok then raise syntax 88.900 array("revoked source publisher retained live authority")
  oldBinding = oldLease~bindingEvidence
  newBinding = newLease~bindingEvidence
  if oldBinding == .nil then raise syntax 88.900 array("old lease runtime binding evidence missing")
  if newBinding == .nil then raise syntax 88.900 array("new lease runtime binding evidence missing")
  if oldBinding~runtimeEvidence~generationState <> "DRAINING" then raise syntax 88.900 array("old lease evidence did not capture draining state")
  if newBinding~runtimeEvidence~generationState <> "ACTIVE" then raise syntax 88.900 array("new lease evidence did not capture active state")
  if oldBinding~legalSemanticIdentity <> oldLease~generation~semanticIdentity then raise syntax 88.900 array("old legal semantic binding mismatch")
  if newBinding~legalSemanticIdentity <> newLease~generation~semanticIdentity then raise syntax 88.900 array("new legal semantic binding mismatch")
  if oldBinding~compilationEvidence~compilerId <> "demo-fixture-compiler" then raise syntax 88.900 array("old compiler evidence missing")
  if newBinding~compilationEvidence~compilerId <> "demo-fixture-compiler" then raise syntax 88.900 array("new compiler evidence missing")
  if oldBinding~sourceAuthorityEvidence~items <> 1 then raise syntax 88.900 array("old host source-authority evidence missing")
  if newBinding~sourceAuthorityEvidence~items <> 1 then raise syntax 88.900 array("new host source-authority evidence missing")
  if oldBinding~sourceAuthorityEvidence[1]~trustProfileId <> "host-test-profile" then raise syntax 88.900 array("old host trust profile not retained")
  if newBinding~sourceAuthorityEvidence[1]~statusCode <> "VERIFIED" then raise syntax 88.900 array("new host source-authority status missing")
  if oldLease~generation~normCount <> 1 then raise syntax 88.900 array("old v1 norm count changed")
  if newLease~generation~normCount <> 2 then raise syntax 88.900 array("new v2 norm count wrong")

  badArtifact = .RuntimeArtifact~new("legal.effect.badkind", "CAPABILITY", "1", "legal:demo:v1", "DemoLegalRules", v1Lines, .LegalEffectBuild~API_VERSION, v1Path)
  badStage = kernel~stage("prod", badArtifact)
  if \badStage~ok then raise syntax 88.900 array("stage bad-kind fixture")
  badActivate = kernel~activate("prod", "legal.effect.badkind", badStage~value~generationId)
  if \badActivate~ok then raise syntax 88.900 array("activate bad-kind fixture")
  badAcquire = resolver~acquire(kernel, "prod", "legal.effect.badkind")
  if badAcquire~ok then raise syntax 88.900 array("resolver accepted non LEGAL_RULES module")
  if badAcquire~code <> "LEGAL_MODULE_KIND_REQUIRED" then raise syntax 88.900 array("wrong bad-kind rejection: " || badAcquire~code)

  badApiArtifact = .RuntimeArtifact~new("legal.effect.badapi", "LEGAL_RULES", "1", "legal:demo:v1", "DemoLegalRules", v1Lines, "legal.effect/9.9", v1Path)
  badApiStage = kernel~stage("prod", badApiArtifact)
  if \badApiStage~ok then raise syntax 88.900 array("stage bad-api fixture")
  badApiActivate = kernel~activate("prod", "legal.effect.badapi", badApiStage~value~generationId)
  if \badApiActivate~ok then raise syntax 88.900 array("activate bad-api fixture")
  badApiAcquire = resolver~acquire(kernel, "prod", "legal.effect.badapi")
  if badApiAcquire~ok then raise syntax 88.900 array("resolver accepted incompatible legal API")
  if badApiAcquire~code <> "LEGAL_API_VERSION_MISMATCH" then raise syntax 88.900 array("wrong bad-api rejection: " || badApiAcquire~code)

  unattestedPath = root || "/tests/fixtures/DemoLegalRules_unattested.cls"
  unattestedLines = .RuntimeSourceLoader~readFile(unattestedPath)~value
  ignored = verifier~pin("legal:demo:unattested", unattestedLines)
  unattestedArtifact = .RuntimeArtifact~new("legal.effect.unattested", "LEGAL_RULES", "1", "legal:demo:unattested", "DemoLegalRulesUnattested", unattestedLines, .LegalEffectBuild~API_VERSION, unattestedPath)
  unattestedStage = kernel~stage("prod", unattestedArtifact)
  if \unattestedStage~ok then raise syntax 88.900 array("stage unattested fixture")
  unattestedActivate = kernel~activate("prod", "legal.effect.unattested", unattestedStage~value~generationId)
  if \unattestedActivate~ok then raise syntax 88.900 array("activate unattested fixture")
  unattestedAcquire = resolver~acquire(kernel, "prod", "legal.effect.unattested", trustProfile, authorityVerifier)
  if unattestedAcquire~ok then raise syntax 88.900 array("resolver accepted compiler-certified but unattested legal source")
  if unattestedAcquire~code <> "LEGAL_SOURCE_AUTHORITY_ATTESTATION_REQUIRED" then raise syntax 88.900 array("wrong unattested rejection: " || unattestedAcquire~code)

  manualPath = root || "/tests/fixtures/DemoLegalRules_manual.cls"
  manualLines = .RuntimeSourceLoader~readFile(manualPath)~value
  ignored = verifier~pin("legal:demo:manual", manualLines)
  manualArtifact = .RuntimeArtifact~new("legal.effect.manual", "LEGAL_RULES", "1", "legal:demo:manual", "DemoLegalRulesManual", manualLines, .LegalEffectBuild~API_VERSION, manualPath)
  manualStage = kernel~stage("prod", manualArtifact)
  if \manualStage~ok then raise syntax 88.900 array("stage manual fixture")
  manualActivate = kernel~activate("prod", "legal.effect.manual", manualStage~value~generationId)
  if \manualActivate~ok then raise syntax 88.900 array("activate manual fixture")
  manualAcquire = resolver~acquire(kernel, "prod", "legal.effect.manual")
  if manualAcquire~ok then raise syntax 88.900 array("resolver accepted sealed but uncertified legal generation")
  if manualAcquire~code <> "LEGAL_GENERATION_NOT_COMPILED" then raise syntax 88.900 array("wrong manual rejection: " || manualAcquire~code)

  ignored = oldLease~release
  ignored = newLease~release
  say "  old=" || "DEMO-LEGAL-V1" || " new=" || "DEMO-LEGAL-V2"
  say "LEGAL EFFECT V0.14 RUNTIME REGISTRY BRIDGE: OK"
  return 0

::requires "LegalEffect.cls"
::requires "RuntimeRegistry.cls"
::requires "LegalEffectAuthorityTestSupport.cls"
