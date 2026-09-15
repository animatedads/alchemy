call main
exit 0

main:
  say "RUNTIME REGISTRY V0.2 DEPENDENCIES START"
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  rules1Lines = readLines("fixtures/modules/DemoRules_v1.cls")
  rules2Lines = readLines("fixtures/modules/DemoRules_v2.cls")
  consumerLines = readLines("fixtures/modules/DemoConsumer_v1.cls")
  badLines = readLines("fixtures/modules/DemoBad.cls")

  call mustOk verifier~pin("fixture:rules:v1", rules1Lines), "pin rules1"
  call mustOk verifier~pin("fixture:rules:v2", rules2Lines), "pin rules2"
  call mustOk verifier~pin("fixture:consumer:v1", consumerLines), "pin consumer"
  call mustOk verifier~pin("fixture:bad-dependent:v1", badLines), "pin bad dependent"

  rules1 = .RuntimeArtifact~new("demo.rules", "RULE", "1.0.0", "fixture:rules:v1", "DemoRules", rules1Lines)
  rules2 = .RuntimeArtifact~new("demo.rules", "RULE", "2.0.0", "fixture:rules:v2", "DemoRules", rules2Lines)

  r = kernel~stage("prod", rules1); call mustOk r, "stage rules1"; gRules1 = r~value
  call mustOk kernel~activate("prod", "demo.rules", gRules1~generationId), "activate rules1"

  deps = .array~of(.RuntimeDependency~new("demo.rules", "runtime.module/0.2", "fixture:rules:v1"))
  envs = .array~of("test", "live", "prod")
  manifest = .RuntimeManifest~new("demo.consumer", "CAPABILITY", "1.0.0", "fixture:consumer:v1", "DemoConsumer", deps, envs)
  consumer = .RuntimeArtifact~new(manifest, consumerLines, "fixtures/modules/DemoConsumer_v1.cls")

  r = kernel~stage("prod", consumer); call mustOk r, "stage consumer"; gConsumer = r~value
  call mustOk kernel~activate("prod", "demo.consumer", gConsumer~generationId), "activate consumer"
  l = kernel~acquire("prod", "demo.consumer")~value
  call assertEq "RULES-ONE", l~module~ruleVersion, "consumer binds rules1"
  call assertEq "PROHIBITED", l~module~disposition("SELL_BAG"), "consumer uses rules1 behavior"
  forbiddenRelease = l~module~attemptDependencyRelease
  call assertFalse forbiddenRelease == .nil, "dependent module receives dependency release result"
  call assertFalse forbiddenRelease~ok, "dependent module cannot release registry-owned dependency leases"
  call assertEq "DEPENDENCY_RELEASE_FORBIDDEN", forbiddenRelease~code, "dependency release authority is sealed"
  call assertEq gRules1~generationId, gConsumer~dependencyGenerationId("demo.rules"), "dependency generation recorded"
  call assertEq 1, gRules1~leaseCount, "rules1 has consumer lifetime dependency lease"

  r = kernel~stage("prod", rules2); call mustOk r, "stage rules2"; gRules2 = r~value
  call mustOk kernel~activate("prod", "demo.rules", gRules2~generationId), "activate rules2"
  call assertEq "DRAINING", gRules1~state, "rules1 drains after rules2 activation"
  call assertEq "RULES-ONE", l~module~ruleVersion, "existing consumer remains dependency-pinned to rules1"

  /* Duplicate module names in a snapshot are one logical lease, not two. */
  duplicateSnapshotResult = kernel~snapshot("prod", .array~of("demo.rules", "demo.rules"))
  call mustOk duplicateSnapshotResult, "duplicate snapshot request"
  duplicateSnapshot = duplicateSnapshotResult~value
  call assertEq 1, gRules2~leaseCount, "duplicate snapshot acquires exactly one rules2 lease"
  call mustOk duplicateSnapshot~release, "release duplicate snapshot"
  call assertEq 0, gRules2~leaseCount, "duplicate snapshot leaves no leaked lease"

  /* A candidate which fails self-test must not pin dependencies after quarantine. */
  badDepsPinned = .array~of(.RuntimeDependency~new("demo.rules", "runtime.module/0.2", "fixture:rules:v2"))
  badManifestPinned = .RuntimeManifest~new("demo.bad-dependent", "CAPABILITY", "1.0.0", "fixture:bad-dependent:v1", "DemoBad", badDepsPinned, .array~of("prod"))
  badDependent = .RuntimeArtifact~new(badManifestPinned, badLines, "fixtures/modules/DemoBad.cls")
  badStage = kernel~stage("prod", badDependent)
  call assertFalse badStage~ok, "bad dependent self-test rejected"
  call assertEq "MODULE_SELFTEST_FAILED", badStage~code, "bad dependent self-test code"
  call assertEq 0, gRules2~leaseCount, "quarantined dependent releases rules2 dependency lease"

  /* File manifests reject ambiguous duplicate dependency declarations. */
  manifestLines = .array~of("RUNTIME-MANIFEST/1",,
      "module-id: demo.duplicate-dep",,
      "module-kind: CAPABILITY",,
      "version: 1",,
      "artifact-id: fixture:duplicate-dep",,
      "entry-class: DemoConsumer",,
      "api-version: runtime.module/0.2",,
      "dependency: demo.rules|runtime.module/0.2|fixture:rules:v2",,
      "dependency: demo.rules|runtime.module/0.2|fixture:rules:v2")
  parsedDuplicate = .RuntimeManifestParser~parseLines(manifestLines)
  call assertFalse parsedDuplicate~ok, "duplicate dependency declaration rejected"
  call assertEq "MANIFEST_DEPENDENCY_DUPLICATE", parsedDuplicate~code, "duplicate dependency manifest code"
  call mustOk l~release, "release explicit consumer lease"
  call assertEq 1, gRules1~leaseCount, "consumer generation still owns one dependency lease"

  busy = kernel~releaseGeneration(gRules1~generationId)
  call assertFalse busy~ok, "dependency-pinned rules cannot release"
  call assertEq "GENERATION_BUSY", busy~code, "busy dependency refusal"

  /* Re-stage same consumer while dependency artifact constraint still requires v1: must fail. */
  mismatch = kernel~stage("prod", consumer)
  call assertFalse mismatch~ok, "artifact-pinned dependency mismatch rejected"
  call assertEq "DEPENDENCY_ARTIFACT_MISMATCH", mismatch~code, "artifact mismatch code"

  /* Environment eligibility is checked before load. */
  testOnlyManifest = .RuntimeManifest~new("demo.testonly", "CAPABILITY", "1", "fixture:consumer:v1", "DemoConsumer", .nil, .array~of("test"))
  testOnly = .RuntimeArtifact~new(testOnlyManifest, consumerLines, "memory")
  denied = kernel~stage("prod", testOnly)
  call assertFalse denied~ok, "test-only artifact denied in prod"
  call assertEq "ARTIFACT_ENVIRONMENT_DENIED", denied~code, "environment denial code"

  /* API constraints fail before package construction. */
  badDeps = .array~of(.RuntimeDependency~new("demo.rules", "runtime.module/9.9"))
  badManifest = .RuntimeManifest~new("demo.baddep", "CAPABILITY", "1", "fixture:consumer:v1", "DemoConsumer", badDeps, .array~of("prod"))
  badArtifact = .RuntimeArtifact~new(badManifest, consumerLines, "memory")
  badApi = kernel~stage("prod", badArtifact)
  call assertFalse badApi~ok, "dependency API mismatch rejected"
  call assertEq "DEPENDENCY_API_MISMATCH", badApi~code, "dependency API mismatch code"

  say "  pinned_dependency_generation=" || gConsumer~dependencyGenerationId("demo.rules")
  say "  rules1_state=" || gRules1~state || " leases=" || gRules1~leaseCount
  say "  rules2_state=" || gRules2~state || " leases=" || gRules2~leaseCount
  say "RUNTIME REGISTRY V0.2 DEPENDENCIES: OK"
  return

mustOk:
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 20
  end
  return

assertFalse:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 21
  end
  return

assertEq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 22
  end
  return

readLines:
  use arg path
  s=.Stream~new(path); o=s~open("read")
  if o <> "READY:" then do; say "open failed" path o; exit 23; end
  a=.array~new
  do while s~lines > 0; a~append(s~lineIn); end
  c=s~close
  return a

::requires "src/RuntimeRegistry.cls"
