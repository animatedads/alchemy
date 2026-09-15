parse arg legalRoot registryRoot pluginRoot
if legalRoot = "" then legalRoot = directory()
if registryRoot = "" then do
  say "LEGAL EFFECT V0.14 RUNTIME EVIDENCE CHAIN: SKIP (no registry root)"
  exit 0
end
if pluginRoot = "" then do
  say "LEGAL EFFECT V0.14 RUNTIME EVIDENCE CHAIN: SKIP (no structured relation root)"
  exit 0
end
say "LEGAL EFFECT V0.14 RUNTIME EVIDENCE CHAIN START"
a = .RuntimeEvidenceChainAcceptance~new(legalRoot, registryRoot, pluginRoot)
exit a~run

::class RuntimeEvidenceChainAcceptance
::method init
  expose legalRoot registryRoot pluginRoot
  use arg legalRootArg, registryRootArg, pluginRootArg
  legalRoot = legalRootArg
  registryRoot = registryRootArg
  pluginRoot = pluginRootArg

::method run
  expose legalRoot pluginRoot
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  analysisBundle = self~buildAnalysisBundle(pluginRoot)
  analysisArtifactId = "structured-semantic:legal-input:v0.8"
  ignored = verifier~pin(analysisArtifactId, analysisBundle~sourceLines)
  analysisArtifact = .RuntimeArtifact~new("structured.semantic.legal-input", "CAPABILITY", "0.8", analysisArtifactId, "StructuredSemanticLegalInputCapability", analysisBundle~sourceLines, "structured.semantic/0.8", "bundle:structured-relation-v0.8:legal-input")
  stagedAnalysis = kernel~stage("test", analysisArtifact)
  self~mustOk(stagedAnalysis, "stage structured semantic input")
  activatedAnalysis = kernel~activate("test", analysisArtifact~moduleId, stagedAnalysis~value~generationId)
  self~mustOk(activatedAnalysis, "activate structured semantic input")
  acquiredAnalysis = kernel~acquire("test", analysisArtifact~moduleId)
  self~mustOk(acquiredAnalysis, "acquire structured semantic input")
  analysisLease = acquiredAnalysis~value

  finding = analysisLease~module~bitcoin35688Finding
  self~assertEq("BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED", finding~classification, "public corpus finding")
  richFact = finding~asBusinessFact
  analysisEnvelope = analysisLease~envelope(richFact, "bitcoin/bitcoin#35688:value-flow-fact")
  if analysisEnvelope == .nil then raise syntax 88.900 array("analysis runtime envelope missing")

  bridge = .LegalStructuredRelationBridge~factSetFrom(.array~of(analysisEnvelope))
  self~mustOk(bridge, "import runtime-enveloped RichBusinessFact")
  factSet = bridge~value
  legalFact = factSet~fact("CODE_FINDING")
  self~assertEq("KNOWN", legalFact~state, "runtime-enveloped fact imported")
  self~assertEq("STRUCTURED_RELATION_RUNTIME_EVIDENCE", legalFact~authority, "fact authority describes evidence channel")
  if legalFact~source \== richFact~source then raise syntax 88.900 array("native source identity lost at Legal Effect import")
  if legalFact~evidence \== analysisEnvelope then raise syntax 88.900 array("runtime envelope not retained as legal fact evidence")
  if legalFact~richEvidence \== richFact then raise syntax 88.900 array("inner rich fact not recoverable")
  if legalFact~runtimeEvidence \== analysisEnvelope~runtimeEvidence then raise syntax 88.900 array("upstream runtime evidence not recoverable")
  self~assertEq("0796bbeb3271a210ed7ed5d85a82fc76939db61a", legalFact~source~beforeOperation~sourceSpan~fileRevision~blobSha, "Git predecessor blob preserved into Legal Effect")
  clonedFact = factSet~clone~fact("CODE_FINDING")
  if clonedFact~evidence \== analysisEnvelope then raise syntax 88.900 array("runtime envelope lost across LegalFactSet clone")

  legalBundle = self~buildLegalBundle(legalRoot)
  legalArtifactId = "legal:code-evidence:v0.7"
  ignored = verifier~pin(legalArtifactId, legalBundle~sourceLines)
  legalArtifact = .RuntimeArtifact~new("legal.effect.code-evidence", "LEGAL_RULES", "0.7", legalArtifactId, "DemoCodeEvidenceRules", legalBundle~sourceLines, .LegalEffectBuild~API_VERSION, "bundle:legal-effect-v0.7:code-evidence")
  stagedLegal = kernel~stage("prod", legalArtifact)
  self~mustOk(stagedLegal, "stage legal rules")
  activatedLegal = kernel~activate("prod", legalArtifact~moduleId, stagedLegal~value~generationId)
  self~mustOk(activatedLegal, "activate legal rules")

  trustProfile = .LegalAuthorityTestSupport~trustProfile
  authorityVerifier = .LegalAuthorityTestSupport~verifier
  acquiredLegal = .LegalRuntimeRuleResolver~new~acquire(kernel, "prod", legalArtifact~moduleId, trustProfile, authorityVerifier)
  self~mustOk(acquiredLegal, "acquire legal rules")
  legalLease = acquiredLegal~value
  if legalLease~runtimeEvidence == .nil then raise syntax 88.900 array("legal lease did not capture runtime execution evidence")
  self~assertEq(legalArtifactId, legalLease~runtimeEvidence~artifactId, "legal runtime artifact evidence")
  self~assertEq(legalLease~generation~semanticIdentity, legalLease~bindingEvidence~legalSemanticIdentity, "runtime-semantic binding")
  if legalLease~bindingEvidence~compilationEvidence == .nil then raise syntax 88.900 array("compiler evidence snapshot missing")
  self~assertEq("demo-code-evidence-compiler", legalLease~bindingEvidence~compilationEvidence~compilerId, "compiler provenance retained outside legal semantic identity")
  self~assertEq(legalLease~generation~compilationCertificate~inputIdentity, legalLease~bindingEvidence~compilationEvidence~inputIdentity, "compiler input identity snapshot")
  verificationSnapshots = legalLease~bindingEvidence~compilationEvidence~verificationEvidence
  self~assertEq(2, verificationSnapshots~items, "legal runtime binding retains compiler source-verification closure")
  self~assertEq("SHA512", verificationSnapshots[1]~algorithm, "source verification algorithm retained")
  self~assertEq("VERIFIED", verificationSnapshots[1]~statusCode, "source verification status retained")
  authorityEvidence = legalLease~bindingEvidence~sourceAuthorityEvidence
  self~assertEq(1, authorityEvidence~items, "one host source-authority verification retained")
  self~assertEq("VERIFIED", authorityEvidence[1]~statusCode, "host source-authority verification status")
  self~assertEq("host-test-profile", authorityEvidence[1]~trustProfileId, "host source-authority profile retained")

  context = .LegalContext~new("DEPLOY-35688", "2026-08-20T14:00:00Z", "2026-08-20T14:00:00Z", factSet)
  action = .LegalAction~new("DEPLOY", "Synthetic deployment action")
  evaluated = legalLease~evaluate(action, context)
  self~mustOk(evaluated, "runtime-bound Legal Effect evaluation")
  legalEnvelope = evaluated~value
  self~assertEq("REVIEW_REQUIRED", legalEnvelope~status, "legal assessment status")
  if legalEnvelope~decisionTrace == .nil then raise syntax 88.900 array("runtime envelope missing structured legal decision trace")
  self~assertEq(legalEnvelope~assessment~decisionTrace~traceIdentity, legalEnvelope~decisionTrace~traceIdentity, "runtime envelope exposes assessment decision trace")
  self~assertEq(legalEnvelope~decisionTrace~traceIdentity, legalEnvelope~provenance["decisionTraceIdentity"], "runtime provenance binds decision trace identity")
  self~assertEq("DEMO-CODE-LEGAL-V1", legalEnvelope~assessment~generation~generationId, "sealed semantic legal generation")
  self~assertEq(legalArtifactId, legalEnvelope~bindingEvidence~runtimeEvidence~artifactId, "legal output runtime artifact")
  self~assertEq(legalEnvelope~assessment~generation~semanticIdentity, legalEnvelope~bindingEvidence~legalSemanticIdentity, "legal output semantic identity")
  self~assertEq("demo-code-evidence-compiler", legalEnvelope~bindingEvidence~compilationEvidence~compilerId, "legal output compiler provenance")
  self~assertEq(1, legalEnvelope~bindingEvidence~sourceAuthorityEvidence~items, "legal output carries host source-authority evidence")
  self~assertEq(legalEnvelope~assessment~generation~compilationCertificate~inputIdentity, legalEnvelope~bindingEvidence~compilationEvidence~inputIdentity, "legal output compiler input identity")
  upstream = legalEnvelope~upstreamRuntimeEvidence
  self~assertEq(1, upstream~items, "one upstream analysis runtime generation")
  upstream~append("caller-mutation")
  self~assertEq(1, legalEnvelope~upstreamRuntimeEvidence~items, "upstream runtime evidence copy-on-read")
  upstream = legalEnvelope~upstreamRuntimeEvidence
  self~assertEq(analysisArtifactId, upstream~at(1)~artifactId, "upstream analyser artifact retained")
  self~assertEq(analysisEnvelope~runtimeEvidence~generationId, upstream~at(1)~generationId, "upstream analyser generation retained")

  oldAnalysisGeneration = analysisEnvelope~runtimeEvidence~generationId
  oldLegalGeneration = legalEnvelope~bindingEvidence~runtimeEvidence~generationId
  self~mustOk(analysisLease~release, "release analysis lease")
  self~mustOk(legalLease~release, "release legal lease")
  releasedEval = legalLease~evaluate(action, context)
  if releasedEval~ok then raise syntax 88.900 array("released legal lease still executed")
  self~assertEq("LEGAL_LEASE_RELEASED", releasedEval~code, "released lease execution rejection")

  self~assertEq(oldAnalysisGeneration, legalEnvelope~upstreamRuntimeEvidence~at(1)~generationId, "upstream runtime evidence survives lease release")
  self~assertEq(oldLegalGeneration, legalEnvelope~bindingEvidence~runtimeEvidence~generationId, "legal runtime evidence survives lease release")
  self~assertEq("0796bbeb3271a210ed7ed5d85a82fc76939db61a", legalEnvelope~assessment~currentContext~facts~fact("CODE_FINDING")~source~beforeOperation~sourceSpan~fileRevision~blobSha, "source evidence survives full chain")

  say "  analysis_generation=" || oldAnalysisGeneration
  say "  analysis_artifact=" || analysisArtifactId
  say "  legal_generation=" || oldLegalGeneration
  say "  legal_artifact=" || legalArtifactId
  say "  legal_semantic=" || legalEnvelope~bindingEvidence~legalSemanticIdentity~substr(1, 42) || "..."
  say "  source_blob=" || legalEnvelope~assessment~currentContext~facts~fact("CODE_FINDING")~source~beforeOperation~sourceSpan~fileRevision~blobSha
  say "  status=" || legalEnvelope~status
  say "LEGAL EFFECT V0.14 RUNTIME EVIDENCE CHAIN: OK"
  return 0

::method buildAnalysisBundle private
  use arg pluginRoot
  builder = .RuntimeBundleBuilder~new
  names = .array~of("BitcoinCorePublicCorpus.cls", "CodeEvidenceRules.cls", "CodeSemanticSource.cls", "CodeValueFlow.cls", "CodeValueFlowRules.cls", "EdiFactNativeSource.cls", "EdiFactRelationAdapter.cls", "GitHubEvidence.cls", "GitNativeSource.cls", "RichSourceCore.cls", "SourceEvidenceRelationAdapter.cls", "X12NativeSource.cls", "X12RelationAdapter.cls", "XmlNativeSource.cls", "XmlRelationAdapter.cls")
  do i = 1 to names~items
    name = names~at(i)
    added = builder~addFile(pluginRoot || "/src/" || name, name)
    self~mustOk(added, "add structured unit " || name)
  end
  wrapper = .array~new
  wrapper~append("::class StructuredSemanticLegalInputCapability public")
  wrapper~append("::method runtimeSelfTest")
  wrapper~append("  finding = .MemoryValueFlowHistoryRule~assess(.BitcoinCorePublicCorpus~semantic35688)")
  wrapper~append('  return finding~classification = "BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED"')
  wrapper~append("::method bitcoin35688Finding")
  wrapper~append("  return .MemoryValueFlowHistoryRule~assess(.BitcoinCorePublicCorpus~semantic35688)")
  addedWrapper = builder~addUnit("RuntimeStructuredSemanticLegalInput.cls", wrapper)
  self~mustOk(addedWrapper, "add structured runtime wrapper")
  built = builder~build
  self~mustOk(built, "build structured semantic bundle")
  return built~value

::method buildLegalBundle private
  expose legalRoot
  use arg legalRootArg
  builder = .RuntimeBundleBuilder~new
  addedCore = builder~addFile(legalRootArg || "/src/LegalEffect.cls", "LegalEffect.cls")
  self~mustOk(addedCore, "add LegalEffect.cls")
  addedBridge = builder~addFile(legalRootArg || "/src/LegalRuntimeCryptoBridge.cls", "LegalRuntimeCryptoBridge.cls")
  self~mustOk(addedBridge, "add LegalRuntimeCryptoBridge.cls")
  alchemySrc = value("ALCHEMY_OBJECTS_SRC",, "ENVIRONMENT")
  if alchemySrc = "" then raise syntax 88.900 array("ALCHEMY_OBJECTS_SRC required for Legal Effect Alchemy closure")
  do alchemyName over .array~of("AlchemyEvidence.cls", "AlchemySecurity.cls", "AlchemyLockedMethod.cls", "AlchemyObject.cls")
    addedAlchemy = builder~addFile(alchemySrc || "/" || alchemyName, alchemyName)
    self~mustOk(addedAlchemy, "add " || alchemyName)
  end
  cryptoSrc = value("CRYPTO_SRC",, "ENVIRONMENT")
  if cryptoSrc = "" then cryptoSrc = value("OOREXX_CRYPTO_SRC",, "ENVIRONMENT")
  if cryptoSrc = "" then raise syntax 88.900 array("CRYPTO_SRC required for legal crypto closure")
  addedCrypto = builder~addFile(cryptoSrc || "/crypto.cls", "crypto.cls")
  self~mustOk(addedCrypto, "add crypto.cls")
  addedRules = builder~addFile(legalRootArg || "/tests/fixtures/DemoCodeEvidenceRules.cls", "DemoCodeEvidenceRules.cls")
  self~mustOk(addedRules, "add DemoCodeEvidenceRules.cls")
  built = builder~build
  self~mustOk(built, "build Legal Effect bundle")
  return built~value

::method mustOk private
  use arg resultObject, label
  if \resultObject~ok then raise syntax 88.900 array(label || ": " || resultObject~code || " " || resultObject~detail)
  return resultObject

::method assertEq private
  use arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array(label || " expected=" || expected || " actual=" || actual)
  return .true

::requires "LegalEffect.cls"
::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"

::requires "LegalEffectAuthorityTestSupport.cls"
