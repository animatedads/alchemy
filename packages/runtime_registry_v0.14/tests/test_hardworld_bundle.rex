parse arg registryRoot hardworldRoot
if registryRoot = "" then registryRoot = "."
if hardworldRoot = "" then do
  say "HARDWORLD BUNDLE INTEGRATION: SKIP (no HardWorld root)"
  exit 0
end
call main registryRoot, hardworldRoot
exit 0

main:
  use arg registryRoot, hardworldRoot
  say "RUNTIME REGISTRY V0.9 HARDWORLD BUNDLE START"

  verifyFile = hardworldRoot || "/VERSION.txt"
  versionLinesResult = .RuntimeSourceLoader~readFile(verifyFile)
  call mustOk versionLinesResult, "read HardWorld VERSION.txt"
  versionLines = versionLinesResult~value
  call assertTrue versionLines~items > 0, "HardWorld version file non-empty"
  hardVersion = versionLines~at(1)~strip
  call assertTrue hardVersion <> "", "HardWorld version detected"

  builderA = .RuntimeBundleBuilder~new
  call addHardWorldSources builderA, hardworldRoot
  call mustOk builderA~addUnit("RuntimeHardWorldRules.cls", makeWrapper("A")), "add HardWorld runtime wrapper A"
  builtA = builderA~build
  call mustOk builtA, "build HardWorld bundle A"
  bundleA = builtA~value
  call assertEq 6, bundleA~unitCount, "five HardWorld sources plus wrapper"
  call assertTrue bundleA~localRequiresRemoved~items >= 5, "HardWorld local requires closure-bound"

  verifier = .RuntimePinnedSourceVerifier~new
  call mustOk verifier~pin("hardworld:v" || hardVersion || ":registry:A", bundleA~sourceLines), "pin HardWorld bundle A"
  kernel = .RuntimeKernel~new(verifier)

  artifactA = .RuntimeArtifact~new("rules.hardworld", "RULE", hardVersion || "+A", "hardworld:v" || hardVersion || ":registry:A", "RuntimeHardWorldRules", bundleA~sourceLines)
  stagedA = kernel~stage("prod", artifactA)
  call mustOk stagedA, "stage HardWorld A"
  generationA = stagedA~value
  call mustOk kernel~activate("prod", "rules.hardworld", generationA~generationId), "activate HardWorld A"

  oldLeaseResult = kernel~acquire("prod", "rules.hardworld")
  call mustOk oldLeaseResult, "acquire HardWorld A"
  oldLease = oldLeaseResult~value
  oldModule = oldLease~module
  call assertEq "A", oldModule~generationLabel, "old request generation marker A"
  call assertHardWorldDecision oldModule~safetyDecision, "old request A"
  call assertEq "RYTA-CABIN-SAFETY", oldModule~modelId, "HardWorld model id exposed"
  call assertEq "0.2", oldModule~modelVersion, "HardWorld model version exposed"
  call assertEq "RYTA-HARDWORLD-V0.2-SEMANTIC-FREEZE", oldModule~modelHash, "HardWorld model hash exposed"

  builderB = .RuntimeBundleBuilder~new
  call addHardWorldSources builderB, hardworldRoot
  call mustOk builderB~addUnit("RuntimeHardWorldRules.cls", makeWrapper("B")), "add HardWorld runtime wrapper B"
  builtB = builderB~build
  call mustOk builtB, "build HardWorld bundle B"
  bundleB = builtB~value
  call assertEq 6, bundleB~unitCount, "HardWorld B source closure size"
  call assertTrue pos('decisionRun~action("WARNING")', bundleB~canonicalSource) > 0, "HardWorld B wrapper preserves quoted WARNING literal"
  call assertTrue pos("a RYTAACTIONDECISION", bundleB~canonicalSource) = 0, "HardWorld B wrapper contains no leaked action-object text"

  call mustOk verifier~pin("hardworld:v" || hardVersion || ":registry:B", bundleB~sourceLines), "pin HardWorld bundle B"
  artifactB = .RuntimeArtifact~new("rules.hardworld", "RULE", hardVersion || "+B", "hardworld:v" || hardVersion || ":registry:B", "RuntimeHardWorldRules", bundleB~sourceLines)
  stagedB = kernel~stage("prod", artifactB)
  call mustOk stagedB, "stage HardWorld B"
  generationB = stagedB~value
  call mustOk kernel~activate("prod", "rules.hardworld", generationB~generationId), "activate HardWorld B"

  call assertEq "DRAINING", generationA~state, "HardWorld A drains after B publication"
  call assertEq 1, generationA~leaseCount, "old HardWorld request pins A"
  call assertEq "A", oldModule~generationLabel, "old request remains on A after activation"
  call assertHardWorldDecision oldModule~safetyDecision, "old request A after B activation"

  newLeaseResult = kernel~acquire("prod", "rules.hardworld")
  call mustOk newLeaseResult, "acquire HardWorld B"
  newLease = newLeaseResult~value
  newModule = newLease~module
  call assertEq "B", newModule~generationLabel, "new request gets B"
  call assertHardWorldDecision newModule~safetyDecision, "new request B"

  call assertTrue generationA~packageIdentity \== generationB~packageIdentity, "HardWorld generations own distinct package objects"
  call assertTrue generationA~moduleClassIdentity \== generationB~moduleClassIdentity, "same HardWorld runtime class is generation-private"

  /* The exact same immutable B artifact may be promoted into TEST, but TEST
   * receives a separate package/module object universe. */
  stagedTest = kernel~stage("test", artifactB)
  call mustOk stagedTest, "stage same HardWorld B artifact in test"
  generationTest = stagedTest~value
  call mustOk kernel~activate("test", "rules.hardworld", generationTest~generationId), "activate HardWorld B in test"
  testLeaseResult = kernel~acquire("test", "rules.hardworld")
  call mustOk testLeaseResult, "acquire test HardWorld B"
  testLease = testLeaseResult~value
  call assertEq "B", testLease~module~generationLabel, "test sees B"
  call assertHardWorldDecision testLease~module~safetyDecision, "test request B"
  call assertTrue generationTest~packageIdentity \== generationB~packageIdentity, "test/prod same artifact use distinct packages"
  call assertTrue generationTest~moduleClassIdentity \== generationB~moduleClassIdentity, "test/prod classes are isolated"

  call mustOk testLease~release, "release test lease"
  call mustOk newLease~release, "release prod B lease"
  call mustOk oldLease~release, "release prod A lease"
  call assertEq "RETIRED", generationA~state, "HardWorld A retires when final old request drains"

  say "  bundle_units=" || bundleA~unitCount
  say "  bundle_lines=" || bundleA~sourceLineCount
  say "  local_requires_bound=" || bundleA~localRequiresRemoved~items
  say "  prod_old_state=" || generationA~state
  say "  prod_active=" || kernel~registry~activeGenerationId("prod", "rules.hardworld")
  say "  test_active=" || kernel~registry~activeGenerationId("test", "rules.hardworld")
  say "  hardworld_version=" || hardVersion
  say "RUNTIME REGISTRY V0.9 HARDWORLD BUNDLE: OK"
  return

addHardWorldSources:
  use arg builder, hardworldRoot
  call mustOk builder~addFile(hardworldRoot || "/HardWorld.cls", "HardWorld.cls"), "add HardWorld.cls"
  call mustOk builder~addFile(hardworldRoot || "/RYTAStateRules.cls", "RYTAStateRules.cls"), "add RYTAStateRules.cls"
  call mustOk builder~addFile(hardworldRoot || "/VirtualRYTA.cls", "VirtualRYTA.cls"), "add VirtualRYTA.cls"
  call mustOk builder~addFile(hardworldRoot || "/plugins/RYTABasicScoring.cls", "plugins/RYTABasicScoring.cls"), "add RYTABasicScoring.cls"
  call mustOk builder~addFile(hardworldRoot || "/plugins/RYTATestExtremeScoring.cls", "plugins/RYTATestExtremeScoring.cls"), "add RYTATestExtremeScoring.cls"
  return

makeWrapper:
  procedure
  use arg label
  lines = .array~new
  lines~append("::class RuntimeHardWorldRules public")
  lines~append("::method generationLabel")
  lines~append('  return "' || label || '"')
  lines~append("::method runtimeSelfTest")
  lines~append("  decisionRun = self~safetyDecision")
  lines~append("  if decisionRun~state <> .RYTAConstant~STATE_REMEDIATION_REQUIRED then return .false")
  lines~append("  if decisionRun~winningRule <> 'RYTA-CUSTODY-UNSAFE' then return .false")
  lines~append('  bigUpsell = decisionRun~action("BIG_UPSELL")')
  lines~append("  if bigUpsell == .nil then return .false")
  lines~append("  if bigUpsell~disposition <> 'PROHIBITED' then return .false")
  lines~append("  if bigUpsell~finalSelected then return .false")
  lines~append('  warning = decisionRun~action("WARNING")')
  lines~append("  if warning == .nil then return .false")
  lines~append("  if warning~disposition <> 'REQUIRED' then return .false")
  lines~append("  if \warning~finalSelected then return .false")
  lines~append("  return .true")
  lines~append("::method modelId")
  lines~append("  ryta = .VirtualRYTA~new")
  lines~append("  return ryta~stateRules~modelId")
  lines~append("::method modelVersion")
  lines~append("  ryta = .VirtualRYTA~new")
  lines~append("  return ryta~stateRules~modelVersion")
  lines~append("::method modelHash")
  lines~append("  ryta = .VirtualRYTA~new")
  lines~append("  return ryta~stateRules~modelHash")
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

assertHardWorldDecision:
  procedure
  use arg decisionRun, label
  call assertEq "REMEDIATION_REQUIRED", decisionRun~state, label || " state"
  call assertEq "RYTA-CUSTODY-UNSAFE", decisionRun~winningRule, label || " winning rule"
  bigUpsell = decisionRun~action("BIG_UPSELL")
  warning = decisionRun~action("WARNING")
  call assertTrue bigUpsell~score > 100000, label || " positive preference survives as preference"
  call assertEq "PROHIBITED", bigUpsell~disposition, label || " big upsell prohibited"
  call assertFalse bigUpsell~finalSelected, label || " prohibited upsell not selected"
  call assertTrue warning~score < -100000, label || " negative warning preference survives as preference"
  call assertEq "REQUIRED", warning~disposition, label || " warning required"
  call assertTrue warning~finalSelected, label || " required warning selected"
  return

mustOk:
  procedure
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 70
  end
  return

assertTrue:
  procedure
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 71
  end
  return

assertFalse:
  procedure
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 72
  end
  return

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 73
  end
  return

::requires "RuntimeBundleBuilder.cls"
