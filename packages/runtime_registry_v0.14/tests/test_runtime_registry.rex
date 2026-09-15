parse arg root
if root = "" then root = directory()

runner = .RuntimeRegistryAcceptance~new(root)
exit runner~run

::class RuntimeRegistryAcceptance

::method init
  expose root assertions
  use arg root
  assertions = 0

::method run
  expose root assertions
  say "RUNTIME REGISTRY V0.1 ACCEPTANCE START"

  ok = self~assertEqual("0.14", .RuntimeRegistryBuild~RELEASE, "runtime release marker")
  ok = self~assertEqual("runtime.registry/0.3", .RuntimeRegistryBuild~API_VERSION, "runtime API marker remains stable")

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  registry = kernel~registry

  cap1Lines = self~readLines(root || "/fixtures/modules/DemoCapability_v1.cls")
  cap2Lines = self~readLines(root || "/fixtures/modules/DemoCapability_v2.cls")
  rules1Lines = self~readLines(root || "/fixtures/modules/DemoRules_v1.cls")
  rules2Lines = self~readLines(root || "/fixtures/modules/DemoRules_v2.cls")
  badLines = self~readLines(root || "/fixtures/modules/DemoBad.cls")

  pinResult = verifier~pin("fixture:capability:v1", cap1Lines)
  ok = self~assertTrue(pinResult~ok, "pin capability v1")
  pinResult = verifier~pin("fixture:capability:v2", cap2Lines)
  ok = self~assertTrue(pinResult~ok, "pin capability v2")
  pinResult = verifier~pin("fixture:rules:v1", rules1Lines)
  ok = self~assertTrue(pinResult~ok, "pin rules v1")
  pinResult = verifier~pin("fixture:rules:v2", rules2Lines)
  ok = self~assertTrue(pinResult~ok, "pin rules v2")
  pinResult = verifier~pin("fixture:bad:v1", badLines)
  ok = self~assertTrue(pinResult~ok, "pin bad fixture")

  cap1 = .RuntimeArtifact~new("demo.capability", "CAPABILITY", "1.0.0", "fixture:capability:v1", "DemoCapability", cap1Lines)
  cap2 = .RuntimeArtifact~new("demo.capability", "CAPABILITY", "2.0.0", "fixture:capability:v2", "DemoCapability", cap2Lines)
  rules1 = .RuntimeArtifact~new("demo.rules", "RULE", "1.0.0", "fixture:rules:v1", "DemoRules", rules1Lines)
  rules2 = .RuntimeArtifact~new("demo.rules", "RULE", "2.0.0", "fixture:rules:v2", "DemoRules", rules2Lines)
  badArtifact = .RuntimeArtifact~new("demo.bad", "CAPABILITY", "1.0.0", "fixture:bad:v1", "DemoBad", badLines)

  /* Same artifact, different environment => distinct package/class universes. */
  stageTest = kernel~stage("test", cap2)
  ok = self~assertTrue(stageTest~ok, "stage test capability v2")
  testGen = stageTest~value
  activeResult = kernel~activate("test", "demo.capability", testGen~generationId)
  ok = self~assertTrue(activeResult~ok, "activate test capability v2")

  stageLive = kernel~stage("live", cap1)
  ok = self~assertTrue(stageLive~ok, "stage live capability v1")
  liveGen = stageLive~value
  activeResult = kernel~activate("live", "demo.capability", liveGen~generationId)
  ok = self~assertTrue(activeResult~ok, "activate live capability v1")

  stageProd1 = kernel~stage("prod", cap1)
  ok = self~assertTrue(stageProd1~ok, "stage prod capability v1")
  prodGen1 = stageProd1~value
  activeResult = kernel~activate("prod", "demo.capability", prodGen1~generationId)
  ok = self~assertTrue(activeResult~ok, "activate prod capability v1")

  ok = self~assertNotEqual(liveGen~packageName, prodGen1~packageName, "same artifact gets unique package name per generation")
  testLeaseResult = kernel~acquire("test", "demo.capability")
  liveLeaseResult = kernel~acquire("live", "demo.capability")
  prodLeaseResult = kernel~acquire("prod", "demo.capability")
  ok = self~assertTrue(testLeaseResult~ok, "test environment lease acquired")
  ok = self~assertTrue(liveLeaseResult~ok, "live environment lease acquired")
  ok = self~assertTrue(prodLeaseResult~ok, "prod environment lease acquired")
  testLease = testLeaseResult~value
  liveLease = liveLeaseResult~value
  heldProdLease = prodLeaseResult~value
  ok = self~assertEqual("TWO", testLease~module~version, "test sees v2")
  ok = self~assertEqual("ONE", liveLease~module~version, "live sees v1")
  ok = self~assertEqual("ONE", heldProdLease~module~version, "prod sees v1")
  ok = self~assertTrue(liveLease~module~class \== heldProdLease~module~class, "same public class name is isolated by package generation")
  ok = self~assertTrue(.environment~at("DEMOCAPABILITY") == .nil, "dynamic public class is not installed into global environment")

  /* Lifecycle authority is not exposed through staged handles, registry
   * lookups, or consumer leases. */
  ok = self~assertTrue(\prodGen1~hasMethod("BEGINDRAIN"), "staged generation handle is read-only")
  ok = self~assertTrue(\heldProdLease~generation~hasMethod("BEGINDRAIN"), "lease generation handle is read-only")
  lookedUpGeneration = registry~generation(prodGen1~generationId)
  ok = self~assertTrue(\lookedUpGeneration~hasMethod("RELEASEOBJECTS"), "registry generation lookup is read-only")

  releaseResult = testLease~release
  releaseResult = liveLease~release

  /* Live replacement: old request stays on v1, new request gets v2. */
  stageProd2 = kernel~stage("prod", cap2)
  ok = self~assertTrue(stageProd2~ok, "stage prod capability v2 beside active v1")
  prodGen2 = stageProd2~value
  activeResult = kernel~activate("prod", "demo.capability", prodGen2~generationId)
  ok = self~assertTrue(activeResult~ok, "atomically activate prod v2")
  ok = self~assertEqual("DRAINING", prodGen1~state, "old prod generation enters draining")
  ok = self~assertEqual(1, prodGen1~leaseCount, "old prod generation retains in-flight lease")
  ok = self~assertEqual("ONE:held", heldProdLease~module~answer("held"), "held request remains on v1")

  newProdLeaseResult = kernel~acquire("prod", "demo.capability")
  ok = self~assertTrue(newProdLeaseResult~ok, "new prod lease after activation")
  newProdLease = newProdLeaseResult~value
  ok = self~assertEqual("TWO:new", newProdLease~module~answer("new"), "new request sees v2")
  releaseResult = newProdLease~release

  collectResult = kernel~collectRetired
  ok = self~assertEqual("DRAINING", prodGen1~state, "collection cannot retire leased old generation")
  releaseResult = heldProdLease~release
  ok = self~assertTrue(releaseResult~ok, "release held old lease")
  ok = self~assertEqual("RETIRED", prodGen1~state, "last lease retirement is immediate")

  /* Warm rollback: retired generation can be started and published again. */
  rollbackResult = kernel~activate("prod", "demo.capability", prodGen1~generationId)
  ok = self~assertTrue(rollbackResult~ok, "rollback to retired v1 generation")
  rollbackLeaseResult = kernel~acquire("prod", "demo.capability")
  rollbackLease = rollbackLeaseResult~value
  ok = self~assertEqual("ONE", rollbackLease~module~version, "rollback restores v1 for new work")
  releaseResult = rollbackLease~release
  collectResult = kernel~collectRetired
  ok = self~assertEqual("RETIRED", prodGen2~state, "superseded v2 drains to retired")

  /* Add rules and prove a request snapshot pins a coherent set of generations. */
  stageRules1 = kernel~stage("prod", rules1)
  ok = self~assertTrue(stageRules1~ok, "stage prod rules v1")
  prodRules1 = stageRules1~value
  activeResult = kernel~activate("prod", "demo.rules", prodRules1~generationId)
  ok = self~assertTrue(activeResult~ok, "activate prod rules v1")

  requested = .array~of("demo.capability", "demo.rules")
  snapshot1Result = kernel~snapshot("prod", requested)
  ok = self~assertTrue(snapshot1Result~ok, "acquire two-module request snapshot")
  snapshot1 = snapshot1Result~value
  snapCapGen = snapshot1~generationId("demo.capability")
  snapRuleGen = snapshot1~generationId("demo.rules")
  ok = self~assertEqual(prodGen1~generationId, snapCapGen, "snapshot pins current capability generation")
  ok = self~assertEqual(prodRules1~generationId, snapRuleGen, "snapshot pins current rules generation")
  ok = self~assertEqual("PROHIBITED", snapshot1~module("demo.rules")~disposition("SELL_BAG"), "snapshot rules v1 behavior")

  stageRules2 = kernel~stage("prod", rules2)
  ok = self~assertTrue(stageRules2~ok, "stage prod rules v2")
  prodRules2 = stageRules2~value
  activeResult = kernel~activate("prod", "demo.rules", prodRules2~generationId)
  ok = self~assertTrue(activeResult~ok, "activate prod rules v2")
  ok = self~assertEqual("PROHIBITED", snapshot1~module("demo.rules")~disposition("SELL_BAG"), "existing snapshot remains on rules v1")

  snapshot2Result = kernel~snapshot("prod", requested)
  ok = self~assertTrue(snapshot2Result~ok, "acquire post-upgrade request snapshot")
  snapshot2 = snapshot2Result~value
  ok = self~assertEqual("REQUIRES_APPROVAL", snapshot2~module("demo.rules")~disposition("SELL_BAG"), "new snapshot sees rules v2")
  ok = self~assertEqual(prodGen1~generationId, snapshot2~generationId("demo.capability"), "unrelated capability generation does not change")
  releaseResult = snapshot1~release
  releaseResult = snapshot2~release
  collectResult = kernel~collectRetired
  ok = self~assertEqual("RETIRED", prodRules1~state, "old rules retire after pinned snapshot releases")

  /* Bad code may load but cannot become READY/ACTIVE if self-test fails. */
  badStage = kernel~stage("prod", badArtifact)
  ok = self~assertTrue(\badStage~ok, "self-test failure rejects stage")
  ok = self~assertEqual("MODULE_SELFTEST_FAILED", badStage~code, "self-test failure code")
  badGeneration = badStage~value
  ok = self~assertEqual("QUARANTINED", badGeneration~state, "failed module quarantined")

  /* Malformed source is rejected before publication and cannot disturb active routing. */
  malformedLines = .array~of("::class Broken public", "::method value", "if then")
  pinResult = verifier~pin("fixture:malformed:v1", malformedLines)
  malformedArtifact = .RuntimeArtifact~new("demo.malformed", "CAPABILITY", "1.0.0", "fixture:malformed:v1", "Broken", malformedLines)
  malformedStage = kernel~stage("prod", malformedArtifact)
  ok = self~assertTrue(\malformedStage~ok, "malformed package source rejected")
  ok = self~assertEqual("PACKAGE_LOAD_FAILED", malformedStage~code, "malformed package failure code")
  ok = self~assertEqual(prodGen1~generationId, registry~activeGenerationId("prod", "demo.capability"), "malformed load cannot disturb active capability")

  /* Artifact id cannot be reused with different source under the pinned verifier. */
  tamperedLines = self~copyLines(cap1Lines)
  tamperedLines~append("/* tampered */")
  tampered = .RuntimeArtifact~new("demo.capability", "CAPABILITY", "1.0.0", "fixture:capability:v1", "DemoCapability", tamperedLines)
  tamperedStage = kernel~stage("prod", tampered)
  ok = self~assertTrue(\tamperedStage~ok, "tampered source rejected")
  ok = self~assertEqual("ARTIFACT_SOURCE_MISMATCH", tamperedStage~code, "tamper rejection code")

  /* Retired generation may be released; active generation may not. */
  releaseGenResult = kernel~releaseGeneration(prodGen2~generationId)
  ok = self~assertTrue(releaseGenResult~ok, "release retired v2 generation objects")
  ok = self~assertEqual("RELEASED", prodGen2~state, "retired generation reaches RELEASED")
  ok = self~assertTrue(\prodGen2~moduleResident, "released generation drops module reference")
  ok = self~assertTrue(\prodGen2~packageResident, "released generation drops package reference")

  activeRelease = kernel~releaseGeneration(prodGen1~generationId)
  ok = self~assertTrue(\activeRelease~ok, "active generation cannot be released")
  ok = self~assertEqual("GENERATION_ACTIVE", activeRelease~code, "active release refusal code")

  /* A failed runtimeQuiesce must abort publication. The old generation stays
   * ACTIVE and the candidate returns to READY after its start is unwound. */
  qOldResult = .RuntimeArtifactFactory~fromFile("demo.quiesce", "CAPABILITY", "1.0.0", "fixture:quiesce:v1", "DemoQuiesceFail", root || "/fixtures/modules/DemoQuiesceFail_v1.cls")
  ok = self~assertTrue(qOldResult~ok, "load quiesce-fail fixture")
  qOldArtifact = qOldResult~value
  pinResult = verifier~pin(qOldArtifact~artifactId, qOldArtifact~sourceLines)
  qOldStage = kernel~stage("prod", qOldArtifact)
  ok = self~assertTrue(qOldStage~ok, "stage quiesce-fail old generation")
  qOld = qOldStage~value
  qActivate = kernel~activate("prod", "demo.quiesce", qOld~generationId)
  ok = self~assertTrue(qActivate~ok, "activate quiesce-fail old generation")

  qNewResult = .RuntimeArtifactFactory~fromFile("demo.quiesce", "CAPABILITY", "2.0.0", "fixture:quiesce:v2", "DemoCapability", root || "/fixtures/modules/DemoCapability_v2.cls")
  ok = self~assertTrue(qNewResult~ok, "load quiesce candidate fixture")
  qNewArtifact = qNewResult~value
  pinResult = verifier~pin(qNewArtifact~artifactId, qNewArtifact~sourceLines)
  qNewStage = kernel~stage("prod", qNewArtifact)
  ok = self~assertTrue(qNewStage~ok, "stage quiesce candidate")
  qNew = qNewStage~value
  qSwap = kernel~activate("prod", "demo.quiesce", qNew~generationId)
  ok = self~assertTrue(\qSwap~ok, "failed runtimeQuiesce rejects activation")
  ok = self~assertEqual("MODULE_QUIESCE_FAILED", qSwap~code, "quiesce failure propagated")
  ok = self~assertEqual(qOld~generationId, registry~activeGenerationId("prod", "demo.quiesce"), "old routing pointer survives quiesce failure")
  ok = self~assertEqual("ACTIVE", qOld~state, "old generation remains active after failed quiesce")
  ok = self~assertEqual("READY", qNew~state, "candidate returns to ready after aborted activation")
  qLeaseResult = kernel~acquire("prod", "demo.quiesce")
  ok = self~assertTrue(qLeaseResult~ok, "old generation remains acquirable after failed upgrade")
  qLease = qLeaseResult~value
  ok = self~assertEqual("QUIESCE-FAIL-ONE", qLease~module~version, "old behavior remains routed after failed upgrade")
  releaseResult = qLease~release

  say "  assertions=" || assertions
  say "  test_active=" || registry~activeGeneration("test", "demo.capability")~version
  say "  live_active=" || registry~activeGeneration("live", "demo.capability")~version
  say "  prod_capability_active=" || registry~activeGeneration("prod", "demo.capability")~version
  say "  prod_rules_active=" || registry~activeGeneration("prod", "demo.rules")~version
  say "RUNTIME REGISTRY V0.1 ACCEPTANCE: OK"
  return 0

::method readLines private
  use arg path
  stream = .Stream~new(path)
  openResult = stream~open("read")
  if openResult <> "READY:" then raise syntax 88.900 array("Cannot open fixture " || path || ": " || openResult)
  resultLines = .array~new
  do while stream~lines > 0
    resultLines~append(stream~lineIn)
  end
  closeResult = stream~close
  return resultLines

::method copyLines private
  use arg source
  resultLines = .array~new
  do i = 1 to source~items
    resultLines~append(source~at(i))
  end
  return resultLines

::method assertTrue private
  expose assertions
  use arg condition, label
  assertions = assertions + 1
  if \condition then do
    say "ASSERTION FAILED:" label
    raise syntax 88.900 array(label)
  end
  return .true

::method assertEqual private
  expose assertions
  use arg expected, actual, label
  assertions = assertions + 1
  if expected \== actual then do
    say "ASSERTION FAILED:" label
    say "  expected=" expected
    say "  actual  =" actual
    raise syntax 88.900 array(label)
  end
  return .true

::method assertNotEqual private
  expose assertions
  use arg left, right, label
  assertions = assertions + 1
  if left == right then do
    say "ASSERTION FAILED:" label
    say "  both=" left
    raise syntax 88.900 array(label)
  end
  return .true

::requires "src/RuntimeRegistry.cls"
