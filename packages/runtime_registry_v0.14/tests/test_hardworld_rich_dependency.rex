parse arg registryRoot pluginRoot hardworldRoot
if registryRoot = "" then registryRoot = "."
if pluginRoot = "" then do
  say "RUNTIME REGISTRY V0.5 HARDWORLD RICH DEPENDENCY: SKIP (no structured relation root)"
  exit 0
end
if hardworldRoot = "" then do
  say "RUNTIME REGISTRY V0.5 HARDWORLD RICH DEPENDENCY: SKIP (no HardWorld root)"
  exit 0
end
call main registryRoot, pluginRoot, hardworldRoot
exit 0

main:
  procedure
  use arg registryRoot, pluginRoot, hardworldRoot
  say "RUNTIME REGISTRY V0.5 HARDWORLD RICH DEPENDENCY START"

  pluginVersion = structuredVersion(pluginRoot)
  call assertTrue pluginVersion <> "", "structured relation version detected"
  hardVersion = hardworldVersion(hardworldRoot)
  call assertTrue hardVersion <> "", "HardWorld version detected"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  /* Structured source generation S1. */
  structuredBuild1 = buildStructuredBundle(pluginRoot, "S1")
  call mustOk structuredBuild1, "build structured generation S1"
  structuredBundle1 = structuredBuild1~value
  structuredArtifactId1 = "structured-relation:v" || pluginVersion || ":registry:S1"
  call mustOk verifier~pin(structuredArtifactId1, structuredBundle1~sourceLines), "pin structured S1"
  structuredArtifact1 = .RuntimeArtifact~new("structured.relation", "CAPABILITY", pluginVersion || "+S1", structuredArtifactId1, "StructuredRelationRuntimeCapability", structuredBundle1~sourceLines)
  structuredStage1 = kernel~stage("prod", structuredArtifact1)
  call mustOk structuredStage1, "stage structured S1"
  structuredGen1 = structuredStage1~value
  call mustOk kernel~activate("prod", "structured.relation", structuredGen1~generationId), "activate structured S1"

  /* HardWorld H1 pins the exact S1 dependency generation and accepts the
   * RichBusinessFact itself as evidence. */
  hardBuild1 = buildHardWorldBundle(hardworldRoot, "H1")
  call mustOk hardBuild1, "build HardWorld H1"
  hardBundle1 = hardBuild1~value
  hardArtifactId1 = "hardworld:v" || hardVersion || ":rich:H1"
  call mustOk verifier~pin(hardArtifactId1, hardBundle1~sourceLines), "pin HardWorld H1"
  dep1 = .RuntimeDependency~new("structured.relation", "runtime.module/0.2", structuredArtifactId1)
  hardManifest1 = .RuntimeManifest~new("rules.hardworld.rich", "RULE", hardVersion || "+H1", hardArtifactId1, "RuntimeHardWorldRichRules", .array~of(dep1), .array~of("prod"))
  hardArtifact1 = .RuntimeArtifact~new(hardManifest1, hardBundle1~sourceLines, "HardWorld v" || hardVersion || " rich H1")
  hardStage1 = kernel~stage("prod", hardArtifact1)
  call mustOk hardStage1, "stage HardWorld H1"
  hardGen1 = hardStage1~value
  call mustOk kernel~activate("prod", "rules.hardworld.rich", hardGen1~generationId), "activate HardWorld H1"

  h1LeaseResult = kernel~acquire("prod", "rules.hardworld.rich")
  call mustOk h1LeaseResult, "acquire HardWorld H1"
  h1Lease = h1LeaseResult~value
  h1 = h1Lease~module
  call assertEq structuredGen1~generationId, h1~dependencyGeneration, "H1 pins structured S1 generation"
  call assertEq "S1", h1~structuredLabel, "H1 sees structured S1 implementation"
  evidenceFact = h1~evidenceFact
  call assertEq 50, evidenceFact~value, "HardWorld fact scalar value explicitly promoted"
  call assertEq "EXPLICIT_TEST_POLICY", evidenceFact~authority, "promotion authority remains explicit"
  richFact = evidenceFact~evidence
  call assertTrue richFact \== .nil, "HardWorld fact retains rich evidence object"
  call assertTrue richFact~isEvidenceBearing, "retained fact remains evidence-bearing"
  call assertEq "50", richFact~lexicalValue, "rich lexical form retained"
  call assertTrue richFact~source \== .nil, "native XML source retained behind HardWorld fact"
  call assertTrue richFact~source~path~pos("Quantity") > 0, "native XML path retained behind HardWorld fact"

  /* Upgrade only the source capability. H1 must remain pinned to S1. */
  structuredBuild2 = buildStructuredBundle(pluginRoot, "S2")
  call mustOk structuredBuild2, "build structured generation S2"
  structuredBundle2 = structuredBuild2~value
  structuredArtifactId2 = "structured-relation:v" || pluginVersion || ":registry:S2"
  call mustOk verifier~pin(structuredArtifactId2, structuredBundle2~sourceLines), "pin structured S2"
  structuredArtifact2 = .RuntimeArtifact~new("structured.relation", "CAPABILITY", pluginVersion || "+S2", structuredArtifactId2, "StructuredRelationRuntimeCapability", structuredBundle2~sourceLines)
  structuredStage2 = kernel~stage("prod", structuredArtifact2)
  call mustOk structuredStage2, "stage structured S2"
  structuredGen2 = structuredStage2~value
  call mustOk kernel~activate("prod", "structured.relation", structuredGen2~generationId), "activate structured S2"

  call assertEq "DRAINING", structuredGen1~state, "S1 drains after S2 publication"
  call assertEq 1, structuredGen1~leaseCount, "H1 dependency lease pins S1"
  call assertEq "S1", h1~structuredLabel, "existing H1 still sees S1 after source upgrade"
  busyRelease = kernel~releaseGeneration(structuredGen1~generationId)
  call assertFalse busyRelease~ok, "S1 cannot release while H1 owns dependency"
  call assertEq "GENERATION_BUSY", busyRelease~code, "dependency pin reports generation busy"

  /* New H2 explicitly binds S2. */
  hardBuild2 = buildHardWorldBundle(hardworldRoot, "H2")
  call mustOk hardBuild2, "build HardWorld H2"
  hardBundle2 = hardBuild2~value
  hardArtifactId2 = "hardworld:v" || hardVersion || ":rich:H2"
  call mustOk verifier~pin(hardArtifactId2, hardBundle2~sourceLines), "pin HardWorld H2"
  dep2 = .RuntimeDependency~new("structured.relation", "runtime.module/0.2", structuredArtifactId2)
  hardManifest2 = .RuntimeManifest~new("rules.hardworld.rich", "RULE", hardVersion || "+H2", hardArtifactId2, "RuntimeHardWorldRichRules", .array~of(dep2), .array~of("prod"))
  hardArtifact2 = .RuntimeArtifact~new(hardManifest2, hardBundle2~sourceLines, "HardWorld v" || hardVersion || " rich H2")
  hardStage2 = kernel~stage("prod", hardArtifact2)
  call mustOk hardStage2, "stage HardWorld H2"
  hardGen2 = hardStage2~value
  call mustOk kernel~activate("prod", "rules.hardworld.rich", hardGen2~generationId), "activate HardWorld H2"

  h2LeaseResult = kernel~acquire("prod", "rules.hardworld.rich")
  call mustOk h2LeaseResult, "acquire HardWorld H2"
  h2Lease = h2LeaseResult~value
  h2 = h2Lease~module
  call assertEq structuredGen2~generationId, h2~dependencyGeneration, "H2 pins structured S2 generation"
  call assertEq "S2", h2~structuredLabel, "new HardWorld H2 sees S2"
  call assertEq "S1", h1~structuredLabel, "held H1 request remains S1-pinned"

  /* Retiring H1 is not sufficient to release its dependency: a warm retired
   * generation can still be rolled back. Releasing H1 drops that dependency. */
  call mustOk h1Lease~release, "release held H1 request"
  call assertEq "RETIRED", hardGen1~state, "H1 retires after held request drains"
  call assertEq 1, structuredGen1~leaseCount, "retired warm H1 still pins S1 for rollback"
  call mustOk kernel~releaseGeneration(hardGen1~generationId), "release retired H1"
  call assertEq "RETIRED", structuredGen1~state, "S1 retires when H1 dependency is released"
  call assertEq 0, structuredGen1~leaseCount, "S1 dependency lease released"
  call mustOk kernel~releaseGeneration(structuredGen1~generationId), "release retired S1"
  call assertEq "RELEASED", structuredGen1~state, "S1 code references released"

  call mustOk h2Lease~release, "release H2 request"

  say "  structured_version=" || pluginVersion
  say "  hardworld_version=" || hardVersion
  say "  structured_s1=" || structuredGen1~generationId || " state=" || structuredGen1~state
  say "  structured_s2=" || structuredGen2~generationId || " state=" || structuredGen2~state
  say "  hardworld_h1=" || hardGen1~generationId || " state=" || hardGen1~state
  say "  hardworld_h2=" || hardGen2~generationId || " state=" || hardGen2~state
  say "  evidence_source_path=" || richFact~source~path
  say "RUNTIME REGISTRY V0.5 HARDWORLD RICH DEPENDENCY: OK"
  return


hardworldVersion:
  procedure
  use arg hardworldRoot
  versionResult = .RuntimeSourceLoader~readFile(hardworldRoot || "/VERSION.txt")
  if \versionResult~ok then return ""
  lines = versionResult~value
  if lines~items = 0 then return ""
  return lines~at(1)~strip

structuredVersion:
  procedure
  use arg pluginRoot
  readmeResult = .RuntimeSourceLoader~readFile(pluginRoot || "/README.md")
  if \readmeResult~ok then return ""
  lines = readmeResult~value
  if lines~items = 0 then return ""
  lastWord = word(lines~at(1), words(lines~at(1)))
  if left(lastWord~lower, 1) <> "v" then return ""
  return substr(lastWord, 2)

buildStructuredBundle:
  procedure
  use arg pluginRoot, label
  builder = .RuntimeBundleBuilder~new
  call SysFileTree pluginRoot || "/src/*.cls", sourceFiles., "FO"
  if sourceFiles.0 = 0 then return .RuntimeResult~failure("STRUCTURED_SOURCE_EMPTY", pluginRoot || "/src/*.cls")
  do i = 1 to sourceFiles.0
    path = sourceFiles.i
    addResult = builder~addFile(path, fileBaseName(path))
    if \addResult~ok then return addResult
  end
  wrapper = .array~new
  wrapper~append("::class StructuredRelationRuntimeCapability public")
  wrapper~append("::method generationLabel")
  wrapper~append('  return "' || label || '"')
  wrapper~append("::method runtimeSelfTest")
  wrapper~append('  fact = self~xmlQuantityFact("<Order><Quantity>50</Quantity></Order>", "registry:selftest")')
  wrapper~append("  if fact == .nil then return .false")
  wrapper~append("  if fact~value <> 50 then return .false")
  wrapper~append("  if \fact~isEvidenceBearing then return .false")
  wrapper~append("  return .true")
  wrapper~append("::method xmlQuantityFact")
  wrapper~append('  use arg text, source = "registry:xml"')
  wrapper~append("  doc = .XmlDocumentContext~fromText(text, source)")
  wrapper~append("  provider = .XmlRelationProvider~new(.nil)")
  wrapper~append('  definition = provider~defineRelation("orders", doc, "/Order")')
  wrapper~append('  definition~columnMap("quantity", "Quantity", "INTEGER")')
  wrapper~append('  rows = provider~table("orders")~readRows')
  wrapper~append("  if rows~items = 0 then return .nil")
  wrapper~append('  return rows~at(1)~fact("quantity")')
  addWrapper = builder~addUnit("RuntimeStructuredRelationCapability.cls", wrapper)
  if \addWrapper~ok then return addWrapper
  return builder~build

buildHardWorldBundle:
  procedure
  use arg hardworldRoot, label
  builder = .RuntimeBundleBuilder~new
  addResult = builder~addFile(hardworldRoot || "/HardWorld.cls", "HardWorld.cls"); if \addResult~ok then return addResult
  addResult = builder~addFile(hardworldRoot || "/RYTAStateRules.cls", "RYTAStateRules.cls"); if \addResult~ok then return addResult
  addResult = builder~addFile(hardworldRoot || "/VirtualRYTA.cls", "VirtualRYTA.cls"); if \addResult~ok then return addResult
  addResult = builder~addFile(hardworldRoot || "/plugins/RYTABasicScoring.cls", "plugins/RYTABasicScoring.cls"); if \addResult~ok then return addResult
  addResult = builder~addFile(hardworldRoot || "/plugins/RYTATestExtremeScoring.cls", "plugins/RYTATestExtremeScoring.cls"); if \addResult~ok then return addResult
  wrapper = hardWorldRichWrapper(label)
  addResult = builder~addUnit("RuntimeHardWorldRichRules.cls", wrapper); if \addResult~ok then return addResult
  return builder~build

hardWorldRichWrapper:
  procedure
  use arg label
  lines = .array~new
  lines~append("::class RuntimeHardWorldRichRules public")
  lines~append("::method generationLabel")
  lines~append('  return "' || label || '"')
  lines~append("::method runtimePrepare")
  lines~append("  expose structured dependencyGeneration")
  lines~append("  use arg context")
  lines~append('  structured = context~dependency("structured.relation")')
  lines~append('  dependencyGeneration = context~dependencyGenerationId("structured.relation")')
  lines~append("  if structured == .nil then return .false")
  lines~append("  if dependencyGeneration = '' then return .false")
  lines~append("  return .true")
  lines~append("::method dependencyGeneration")
  lines~append("  expose dependencyGeneration")
  lines~append("  return dependencyGeneration")
  lines~append("::method structuredLabel")
  lines~append("  expose structured")
  lines~append("  return structured~generationLabel")
  lines~append("::method richFact")
  lines~append("  expose structured")
  lines~append('  return structured~xmlQuantityFact("<Order><Quantity>50</Quantity></Order>", "hardworld:rich-order")')
  lines~append("::method evidenceFact")
  lines~append("  rich = self~richFact")
  lines~append("  world = .RYTAWorldState~new('RICH-DEPENDENCY-WORLD')")
  lines~append("  return world~putKnown('ORDER_QUANTITY', rich~value, 'STRUCTURED_RELATION', 'EXPLICIT_TEST_POLICY', rich)")
  lines~append("::method runtimeSelfTest")
  lines~append("  fact = self~evidenceFact")
  lines~append("  if fact~value <> 50 then return .false")
  lines~append("  if fact~authority <> 'EXPLICIT_TEST_POLICY' then return .false")
  lines~append("  if fact~evidence == .nil then return .false")
  lines~append("  if \fact~evidence~isEvidenceBearing then return .false")
  lines~append("  decisionRun = self~safetyDecision")
  lines~append("  bigUpsell = decisionRun~action('BIG_UPSELL')")
  lines~append("  warningAction = decisionRun~action('WARNING')")
  lines~append("  if bigUpsell == .nil then return .false")
  lines~append("  if warningAction == .nil then return .false")
  lines~append("  if bigUpsell~disposition <> 'PROHIBITED' then return .false")
  lines~append("  if warningAction~disposition <> 'REQUIRED' then return .false")
  lines~append("  return .true")
  lines~append("::method safetyDecision")
  lines~append("  world = .RYTAWorldState~new")
  lines~append("  world~putKnown('HAS_QUERY', .true)")
  lines~append("  world~putKnown('PRODUCT_RELEVANT', .true)")
  lines~append("  world~putKnown('CUSTOMER_ELIGIBLE', .true)")
  lines~append("  world~putKnown('UPSELL_OPPORTUNITY', .true)")
  lines~append("  world~putKnown('PRODUCT_VALUE_HIGH', .true)")
  lines~append("  world~putKnown('ESSENTIAL_MEDICATION', .true)")
  lines~append("  world~putKnown('IMMEDIATE_ACCESS', .true)")
  lines~append("  world~putKnown('GUARANTEED_CUSTODY', .false)")
  lines~append("  ryta = .VirtualRYTA~new")
  lines~append("  ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_BIG_UPSELL, 1000000))")
  lines~append("  ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_WARNING, -1000000))")
  lines~append("  return ryta~evaluate(world)")
  lines~append('::requires "VirtualRYTA.cls"')
  lines~append('::requires "RYTATestExtremeScoring.cls"')
  return lines

fileBaseName:
  procedure
  use arg path
  slash = lastPos("/", path)
  backslash = lastPos("\\", path)
  cut = slash
  if backslash > cut then cut = backslash
  if cut = 0 then return path
  return substr(path, cut + 1)

mustOk:
  procedure
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 80
  end
  return

assertTrue:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 81; end
  return

assertFalse:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 82; end
  return

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 83
  end
  return

::requires "RuntimeBundleBuilder.cls"
