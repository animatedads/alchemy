parse arg registryRoot pluginRoot hardworldRoot
if registryRoot = "" then registryRoot = "."
if pluginRoot = "" then do
  say "ABILITY REGISTRY REAL STACK: SKIP (no structured relation root)"
  exit 0
end
if hardworldRoot = "" then do
  say "ABILITY REGISTRY REAL STACK: SKIP (no HardWorld root)"
  exit 0
end
call main registryRoot, pluginRoot, hardworldRoot
exit 0

main:
  procedure
  use arg registryRoot, pluginRoot, hardworldRoot
  say "ABILITY REGISTRY V0.1 REAL STACK START"

  pluginVersion = structuredVersion(pluginRoot)
  call assertTrue pluginVersion <> "", "structured relation version detected"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  abilityRegistry = .AbilityRegistry~new(kernel)

  structured1 = stageStructured(kernel, verifier, pluginRoot, pluginVersion, "S1")
  call mustOk kernel~activate("prod", "structured.relation", structured1~generationId), "activate structured S1"
  hard1 = stageHardWorld(kernel, verifier, hardworldRoot, structured1~artifactId, "H1")
  call mustOk kernel~activate("prod", "rules.hardworld.rich", hard1~generationId), "activate HardWorld H1"

  p1 = makeProfile("1", structured1~artifactId, hard1~artifactId)
  a1Stage = abilityRegistry~stage("prod", p1); call mustOk a1Stage, "stage real profile P1"; a1 = a1Stage~value
  call mustOk abilityRegistry~activate("prod", "client-real", a1~generationId), "activate real profile P1"

  s1Result = abilityRegistry~acquire("prod", "client-real"); call mustOk s1Result, "acquire real P1 session"; s1 = s1Result~value
  call assertEq "S1", s1~module("data")~generationLabel, "P1 data alias sees structured S1"
  call assertEq "H1", s1~module("rules")~generationLabel, "P1 rules alias sees HardWorld H1"
  call assertEq structured1~generationId, s1~runtimeGenerationId("data"), "P1 direct structured generation pinned"
  call assertEq hard1~generationId, s1~runtimeGenerationId("rules"), "P1 direct HardWorld generation pinned"

  richFact = s1~module("data")~xmlQuantityFact("<Order><Quantity>50</Quantity></Order>", "ability:order-1")
  call assertTrue richFact \== .nil, "P1 query capability returns rich fact"
  call assertEq 50, richFact~value, "P1 rich fact typed value"
  call assertTrue richFact~source~path~pos("Quantity") > 0, "P1 rich fact native source path"
  evidenceFact = s1~module("rules")~evidenceFact
  call assertEq 50, evidenceFact~value, "P1 HardWorld receives rich evidence value"
  call assertTrue evidenceFact~evidence~isEvidenceBearing, "P1 HardWorld retains rich evidence object"
  decision = s1~module("rules")~safetyDecision
  call assertEq "PROHIBITED", decision~action("BIG_UPSELL")~disposition, "HardWorld authority still overrides extreme upsell preference"
  call assertEq "REQUIRED", decision~action("WARNING")~disposition, "HardWorld warning remains required"

  /* Publish a complete new source+rules closure globally. P1 must remain on
   * the old closure until P2 is published for this client. */
  structured2 = stageStructured(kernel, verifier, pluginRoot, pluginVersion, "S2")
  call mustOk kernel~activate("prod", "structured.relation", structured2~generationId), "activate structured S2 globally"
  hard2 = stageHardWorld(kernel, verifier, hardworldRoot, structured2~artifactId, "H2")
  call mustOk kernel~activate("prod", "rules.hardworld.rich", hard2~generationId), "activate HardWorld H2 globally"

  p1Again = abilityRegistry~acquire("prod", "client-real"); call mustOk p1Again, "acquire P1 after global runtime upgrade"; s1b = p1Again~value
  call assertEq "S1", s1b~module("data")~generationLabel, "active P1 still sees structured S1"
  call assertEq "H1", s1b~module("rules")~generationLabel, "active P1 still sees HardWorld H1"
  call assertEq "S1", s1b~module("rules")~structuredLabel, "P1 HardWorld H1 still pins structured S1 dependency"

  p2 = makeProfile("2", structured2~artifactId, hard2~artifactId)
  a2Stage = abilityRegistry~stage("prod", p2); call mustOk a2Stage, "stage real profile P2"; a2 = a2Stage~value
  call mustOk abilityRegistry~activate("prod", "client-real", a2~generationId), "activate real profile P2"
  s2Result = abilityRegistry~acquire("prod", "client-real"); call mustOk s2Result, "acquire real P2 session"; s2 = s2Result~value
  call assertEq "S2", s2~module("data")~generationLabel, "P2 sees structured S2"
  call assertEq "H2", s2~module("rules")~generationLabel, "P2 sees HardWorld H2"
  call assertEq "S2", s2~module("rules")~structuredLabel, "P2 HardWorld H2 pins structured S2 dependency"
  call assertEq "S1", s1~module("rules")~structuredLabel, "held P1 remains on complete old closure"

  call mustOk s1b~release, "release second P1 real session"
  call mustOk s1~release, "release first P1 real session"
  call assertEq "RETIRED", a1~state, "real P1 retires after sessions drain"

  /* Layered retention: P1 directly pins S1 and H1; H1 itself also pins S1.
   * Releasing P1 drops its direct anchors, but H1 remains warm and therefore
   * continues to pin S1 until H1 itself is released. */
  call assertTrue structured1~leaseCount >= 2, "S1 has direct profile and H1 dependency anchors before P1 release"
  call mustOk abilityRegistry~releaseGeneration(a1~generationId), "release retired real P1"
  call assertEq "RELEASED", a1~state, "real P1 released"
  call assertEq "RETIRED", hard1~state, "H1 retires after P1 runtime anchor release"
  call assertEq 1, structured1~leaseCount, "H1 warm dependency remains sole S1 anchor"
  call assertEq "DRAINING", structured1~state, "S1 still drains while warm H1 pins it"
  call mustOk kernel~releaseGeneration(hard1~generationId), "release warm H1"
  call assertEq "RETIRED", structured1~state, "S1 retires after H1 dependency release"
  call mustOk kernel~releaseGeneration(structured1~generationId), "release S1 code closure"

  call mustOk s2~release, "release P2 real session"

  say "  structured_version=" || pluginVersion
  say "  p1=" || a1~generationId || " state=" || a1~state
  say "  p2=" || a2~generationId || " state=" || a2~state
  say "  rich_source_path=" || richFact~source~path
  say "  hardworld_big_upsell=" || decision~action("BIG_UPSELL")~disposition
  say "ABILITY REGISTRY V0.1 REAL STACK: OK"
  return

makeProfile:
  procedure
  use arg revision, structuredArtifactId, hardArtifactId
  runtimeBindings = .array~new
  runtimeBindings~append(.AbilityRuntimeBinding~new("data", "structured.relation", structuredArtifactId))
  runtimeBindings~append(.AbilityRuntimeBinding~new("rules", "rules.hardworld.rich", hardArtifactId))
  abilities = .array~new
  abilities~append(.AbilityDescriptor~new("query", "QUERY", .array~of("data"), .true, "Structured rich-source query"))
  abilities~append(.AbilityDescriptor~new("evaluate", "EVALUATE", .array~of("rules", "data"), .true, "HardWorld evaluation over rich evidence"))
  dataBindings = .array~of(.AbilityDataBinding~new("orders", "data", "orders", "READ"))
  ruleBindings = .array~of(.AbilityRuleBinding~new("customer-policy", "rules", "hardworld-rich"))
  return .AbilityProfileRevision~new("real-customer-bot", revision, "client-real", runtimeBindings, abilities, dataBindings, ruleBindings, "real current stack profile")

stageStructured:
  procedure
  use arg kernel, verifier, pluginRoot, pluginVersion, label
  buildResult = buildStructuredBundle(pluginRoot, label); call mustOk buildResult, "build structured " || label; bundle = buildResult~value
  artifactId = "structured-relation:v" || pluginVersion || ":ability:" || label
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin structured " || label
  artifact = .RuntimeArtifact~new("structured.relation", "CAPABILITY", pluginVersion || "+" || label, artifactId, "StructuredRelationRuntimeCapability", bundle~sourceLines)
  stageResult = kernel~stage("prod", artifact); call mustOk stageResult, "stage structured " || label
  return stageResult~value

stageHardWorld:
  procedure
  use arg kernel, verifier, hardworldRoot, structuredArtifactId, label
  buildResult = buildHardWorldBundle(hardworldRoot, label); call mustOk buildResult, "build HardWorld " || label; bundle = buildResult~value
  hardVersion = hardworldVersion(hardworldRoot)
  if hardVersion = "" then hardVersion = "unknown"
  artifactId = "hardworld:v" || hardVersion || ":ability:" || label
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin HardWorld " || label
  dep = .RuntimeDependency~new("structured.relation", "runtime.module/0.2", structuredArtifactId)
  manifest = .RuntimeManifest~new("rules.hardworld.rich", "RULE", hardVersion || "+" || label, artifactId, "RuntimeHardWorldRichRules", .array~of(dep), .array~of("prod"))
  artifact = .RuntimeArtifact~new(manifest, bundle~sourceLines, "HardWorld v" || hardVersion || " ability " || label)
  stageResult = kernel~stage("prod", artifact); call mustOk stageResult, "stage HardWorld " || label
  return stageResult~value

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
  if \value then do
    say "FAILED:" label
    exit 81
  end
  return

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 82
  end
  return

::requires "AbilityRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
