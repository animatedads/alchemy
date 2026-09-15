parse arg root
if root = "" then root = directory()
say "LEGAL EFFECT V0.14 RUNTIME REGISTRY V0.8 BUNDLE START"
a = .RuntimeV08BundleAcceptance~new(root)
exit a~run

::class RuntimeV08BundleAcceptance
::method init
  expose root
  use arg rootArg
  root = rootArg

::method run
  expose root
  builder = .RuntimeBundleBuilder~new
  addedCore = builder~addFile(root || "/src/LegalEffect.cls", "LegalEffect.cls")
  if \addedCore~ok then raise syntax 88.900 array("add LegalEffect.cls: " || addedCore~code)
  addedBridge = builder~addFile(root || "/src/LegalRuntimeCryptoBridge.cls", "LegalRuntimeCryptoBridge.cls")
  if \addedBridge~ok then raise syntax 88.900 array("add crypto bridge: " || addedBridge~code)
  alchemySrc = value("ALCHEMY_OBJECTS_SRC",, "ENVIRONMENT")
  if alchemySrc = "" then raise syntax 88.900 array("ALCHEMY_OBJECTS_SRC required")
  do alchemyName over .array~of("AlchemyEvidence.cls", "AlchemySecurity.cls", "AlchemyLockedMethod.cls", "AlchemyObject.cls")
    addedAlchemy = builder~addFile(alchemySrc || "/" || alchemyName, alchemyName)
    if \addedAlchemy~ok then raise syntax 88.900 array("add " || alchemyName || ": " || addedAlchemy~code)
  end
  cryptoSrc = value("CRYPTO_SRC",, "ENVIRONMENT")
  if cryptoSrc = "" then cryptoSrc = value("OOREXX_CRYPTO_SRC",, "ENVIRONMENT")
  if cryptoSrc = "" then raise syntax 88.900 array("CRYPTO_SRC required")
  addedCrypto = builder~addFile(cryptoSrc || "/crypto.cls", "crypto.cls")
  if \addedCrypto~ok then raise syntax 88.900 array("add crypto.cls: " || addedCrypto~code)
  addedRules = builder~addFile(root || "/tests/fixtures/DemoLegalRules_v1.cls", "DemoLegalRules_v1.cls")
  if \addedRules~ok then raise syntax 88.900 array("add rules fixture: " || addedRules~code)
  built = builder~build
  if \built~ok then raise syntax 88.900 array("build bundle: " || built~code || " " || built~detail)
  bundle = built~value
  if bundle~unitCount <> 8 then raise syntax 88.900 array("bundle unit count=" || bundle~unitCount)
  if bundle~localRequiresRemoved~items <> 9 then raise syntax 88.900 array("expected nine local ::REQUIRES bindings got=" || bundle~localRequiresRemoved~items)

  verifier = .RuntimePinnedSourceVerifier~new
  artifactId = "legal:v07:bundle:v1"
  ignored = verifier~pin(artifactId, bundle~sourceLines)
  artifact = .RuntimeArtifact~new("legal.effect.v07.bundle", "LEGAL_RULES", "1", artifactId, "DemoLegalRules", bundle~sourceLines, .LegalEffectBuild~API_VERSION, "runtime-bundle")
  kernel = .RuntimeKernel~new(verifier)
  staged = kernel~stage("prod", artifact)
  if \staged~ok then raise syntax 88.900 array("bundle stage: " || staged~code || " " || staged~detail)
  activated = kernel~activate("prod", artifact~moduleId, staged~value~generationId)
  if \activated~ok then raise syntax 88.900 array("bundle activate: " || activated~code || " " || activated~detail)

  trustProfile = .LegalAuthorityTestSupport~trustProfile
  authorityVerifier = .LegalAuthorityTestSupport~verifier
  acquired = .LegalRuntimeRuleResolver~new~acquire(kernel, "prod", artifact~moduleId, trustProfile, authorityVerifier)
  if \acquired~ok then raise syntax 88.900 array("bundle acquire: " || acquired~code || " " || acquired~detail)
  legalLease = acquired~value
  if legalLease~generation~generationId <> "DEMO-LEGAL-V1" then raise syntax 88.900 array("wrong legal generation from bundle")
  if legalLease~generation~semanticIdentity~startsWith("LEGAL-EFFECT-SEMANTIC/1") = .false then raise syntax 88.900 array("semantic identity missing")
  if legalLease~bindingEvidence == .nil then raise syntax 88.900 array("runtime binding evidence missing")
  if legalLease~bindingEvidence~compilationEvidence~compilerId <> "demo-fixture-compiler" then raise syntax 88.900 array("compiler evidence missing from bundle binding")
  runtimeGenerationId = legalLease~runtimeLease~generationId
  ignored = legalLease~release

  say "  bundle_units=" || bundle~unitCount || " lines=" || bundle~sourceLineCount || " local_requires=" || bundle~localRequiresRemoved~items
  say "  runtime_generation=" || runtimeGenerationId || " legal_generation=DEMO-LEGAL-V1"
  say "LEGAL EFFECT V0.14 RUNTIME REGISTRY V0.8 BUNDLE: OK"
  return 0

::requires "LegalEffect.cls"
::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "LegalEffectAuthorityTestSupport.cls"
