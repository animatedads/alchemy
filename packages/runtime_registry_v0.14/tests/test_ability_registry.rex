parse arg registryRoot
if registryRoot = "" then registryRoot = "."
call main registryRoot
exit 0

main:
  procedure
  use arg registryRoot
  say "ABILITY REGISTRY V0.1 ACCEPTANCE START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  cap1 = stageFixture(kernel, verifier, registryRoot || "/fixtures/modules/DemoCapability_v1.cls", "data.orders", "CAPABILITY", "1.0.0", "ability:data:1", "DemoCapability", "prod")
  rules1 = stageFixture(kernel, verifier, registryRoot || "/fixtures/modules/DemoRules_v1.cls", "rules.customer", "RULE", "1.0.0", "ability:rules:1", "DemoRules", "prod")
  call mustOk kernel~activate("prod", "data.orders", cap1~generationId), "activate data v1"
  call mustOk kernel~activate("prod", "rules.customer", rules1~generationId), "activate rules v1"

  abilityRegistry = .AbilityRegistry~new(kernel)
  profile1 = makeProfile("customer-bot", "1", "client-acme", "ability:data:1", "ability:rules:1")
  stagedProfile1 = abilityRegistry~stage("prod", profile1)
  call mustOk stagedProfile1, "stage profile revision 1"
  ability1 = stagedProfile1~value
  call assertFalse ability1~hasMethod("BEGINDRAIN"), "staged ability generation is a read-only view"
  call assertFalse abilityRegistry~generation(ability1~generationId)~hasMethod("RELEASEOBJECTS"), "ability registry lookup is read-only"

  driftRuntimeBindings = .array~new
  driftRuntimeBindings~append(.AbilityRuntimeBinding~new("data", "data.orders", "ability:data:1"))
  driftRuntimeBindings~append(.AbilityRuntimeBinding~new("rules", "rules.customer", "ability:rules:1"))
  driftAbilities = .array~of(.AbilityDescriptor~new("query", "QUERY", .array~of("data"), .true, "Bounded federated query"))
  driftData = .array~of(.AbilityDataBinding~new("orders", "data", "DIFFERENT_RESOURCE", "READ"))
  driftRules = .array~of(.AbilityRuleBinding~new("customer-policy", "rules", "customer-policy"))
  driftProfile = .AbilityProfileRevision~new("customer-bot", "1", "client-acme", driftRuntimeBindings, driftAbilities, driftData, driftRules, "drift attempt")
  driftStage = abilityRegistry~stage("prod", driftProfile)
  call assertFalse driftStage~ok, "same profile revision cannot be reused for different configuration"
  call assertEq "ABILITY_PROFILE_IDENTITY_REUSED", driftStage~code, "profile revision drift error code"

  call mustOk abilityRegistry~activate("prod", "client-acme", ability1~generationId), "activate profile revision 1"

  firstSessionResult = abilityRegistry~acquire("prod", "client-acme")
  call mustOk firstSessionResult, "acquire first profile session"
  firstSession = firstSessionResult~value
  call assertEq "1", firstSession~revision, "first session profile revision"
  call assertEq "ONE:first", firstSession~module("data")~answer("first"), "first session data v1"
  call assertEq "RULES-ONE", firstSession~module("rules")~version, "first session rules v1"
  call assertEq cap1~generationId, firstSession~runtimeGenerationId("data"), "first session data generation pinned"
  call assertEq rules1~generationId, firstSession~runtimeGenerationId("rules"), "first session rules generation pinned"
  dataRuntimeEvidence = firstSession~runtimeExecutionEvidence("data")
  call assertEq cap1~generationId, dataRuntimeEvidence~generationId, "session data runtime evidence generation pinned"
  call assertEq "ACTIVE", dataRuntimeEvidence~generationState, "session data runtime evidence initially active"
  richValue = .directory~new
  richValue["value"] = "retained"
  dataEnvelope = firstSession~runtimeEnvelope("data", richValue, "ability://orders/retained")
  call assertTrue dataEnvelope~value == richValue, "session runtime envelope retains exact value identity"
  call assertEq cap1~generationId, dataEnvelope~runtimeEvidence~generationId, "session runtime envelope pins data generation"
  call assertEq "query", firstSession~ability("query")~abilityId, "query ability available"
  call assertEq "orders", firstSession~dataBinding("orders")~logicalName, "orders data binding available"
  call assertEq "customer-policy", firstSession~ruleBinding("customer-policy")~logicalName, "rule binding available"

  /* Publish new runtime generations globally. P1 owns a RuntimeSnapshot and
   * therefore remains semantically pinned to the old closure. */
  cap2 = stageFixture(kernel, verifier, registryRoot || "/fixtures/modules/DemoCapability_v2.cls", "data.orders", "CAPABILITY", "2.0.0", "ability:data:2", "DemoCapability", "prod")
  rules2 = stageFixture(kernel, verifier, registryRoot || "/fixtures/modules/DemoRules_v2.cls", "rules.customer", "RULE", "2.0.0", "ability:rules:2", "DemoRules", "prod")
  call mustOk kernel~activate("prod", "data.orders", cap2~generationId), "activate data v2 globally"
  call mustOk kernel~activate("prod", "rules.customer", rules2~generationId), "activate rules v2 globally"

  call assertEq "DRAINING", cap1~state, "data v1 drains but profile pins it"
  call assertEq "DRAINING", rules1~state, "rules v1 drains but profile pins it"
  call assertEq "DRAINING", firstSession~runtimeExecutionEvidence("data")~generationState, "session runtime evidence observes pinned generation draining"
  call assertEq "ACTIVE", dataRuntimeEvidence~generationState, "previous session runtime evidence remains detached snapshot"
  call assertEq "ACTIVE", dataEnvelope~runtimeEvidence~generationState, "ability envelope runtime evidence remains detached snapshot"
  call assertEq 1, cap1~leaseCount, "profile anchor is one data v1 lease"
  call assertEq 1, rules1~leaseCount, "profile anchor is one rules v1 lease"

  oldProfileNewRequestResult = abilityRegistry~acquire("prod", "client-acme")
  call mustOk oldProfileNewRequestResult, "new request while P1 remains active"
  oldProfileNewRequest = oldProfileNewRequestResult~value
  call assertEq "ONE:after-runtime-upgrade", oldProfileNewRequest~module("data")~answer("after-runtime-upgrade"), "P1 new request remains data v1"
  call assertEq "RULES-ONE", oldProfileNewRequest~module("rules")~version, "P1 new request remains rules v1"

  /* A pinned profile revision rejects the wrong active runtime rather than
   * silently changing semantics. */
  badProfile = makeProfile("customer-bot", "bad", "client-acme", "ability:data:1", "ability:rules:1")
  badStage = abilityRegistry~stage("prod", badProfile)
  call assertFalse badStage~ok, "old artifact-pinned profile cannot stage against v2"
  call assertEq "ABILITY_RUNTIME_ARTIFACT_MISMATCH", badStage~code, "profile pin mismatch is explicit"
  call assertEq 0, cap2~leaseCount, "failed profile staging releases temporary data v2 snapshot"
  call assertEq 0, rules2~leaseCount, "failed profile staging releases temporary rules v2 snapshot"

  /* Stage replacement P2 against the now-active runtime v2 closure. */
  profile2 = makeProfile("customer-bot", "2", "client-acme", "ability:data:2", "ability:rules:2")
  stagedProfile2 = abilityRegistry~stage("prod", profile2)
  call mustOk stagedProfile2, "stage profile revision 2"
  ability2 = stagedProfile2~value
  call assertEq 1, cap2~leaseCount, "P2 anchor pins data v2"
  call assertEq 1, rules2~leaseCount, "P2 anchor pins rules v2"
  call mustOk abilityRegistry~activate("prod", "client-acme", ability2~generationId), "activate profile revision 2"

  call assertEq "DRAINING", ability1~state, "P1 drains after P2 publication"
  call assertEq 2, ability1~leaseCount, "two P1 request sessions held"
  currentSessionResult = abilityRegistry~acquire("prod", "client-acme")
  call mustOk currentSessionResult, "acquire P2 session"
  currentSession = currentSessionResult~value
  call assertEq "2", currentSession~revision, "new session profile revision 2"
  call assertEq "TWO:new", currentSession~module("data")~answer("new"), "P2 receives data v2"
  call assertEq "RULES-TWO", currentSession~module("rules")~version, "P2 receives rules v2"
  call assertEq "REQUIRES_APPROVAL", currentSession~module("rules")~disposition("SELL_BAG"), "P2 receives changed rule semantics"
  call assertEq "PROHIBITED", firstSession~module("rules")~disposition("SELL_BAG"), "held P1 session retains old rule semantics"

  call mustOk oldProfileNewRequest~release, "release second P1 session"
  call mustOk firstSession~release, "release first P1 session"
  call assertEq "RETIRED", ability1~state, "P1 retires when request sessions drain"
  call assertEq 1, cap1~leaseCount, "warm retired P1 still anchors data v1 for rollback"
  call assertEq 1, rules1~leaseCount, "warm retired P1 still anchors rules v1 for rollback"

  /* Roll back the client profile only. The global RuntimeRegistry remains on
   * v2, but the retired P1 snapshot is still a valid warm closure. */
  call mustOk abilityRegistry~activate("prod", "client-acme", ability1~generationId), "rollback client to P1"
  rollbackResult = abilityRegistry~acquire("prod", "client-acme")
  call mustOk rollbackResult, "acquire rollback P1 session"
  rollbackSession = rollbackResult~value
  call assertEq "1", rollbackSession~revision, "rollback profile revision 1"
  call assertEq "ONE:rollback", rollbackSession~module("data")~answer("rollback"), "rollback uses old data code"
  call assertEq "RULES-ONE", rollbackSession~module("rules")~version, "rollback uses old rule code"
  call assertEq cap2~generationId, kernel~registry~activeGenerationId("prod", "data.orders"), "global data runtime remains v2"
  call assertEq rules2~generationId, kernel~registry~activeGenerationId("prod", "rules.customer"), "global rules runtime remains v2"

  /* Return client to P2, then release P1. Only release of the retired ability
   * generation releases its runtime snapshot and allows runtime v1 to retire. */
  call mustOk abilityRegistry~activate("prod", "client-acme", ability2~generationId), "return client to P2"
  call mustOk rollbackSession~release, "release rollback P1 session"
  call assertEq "RETIRED", ability1~state, "P1 retired again"
  busyRuntimeRelease = kernel~releaseGeneration(cap1~generationId)
  call assertFalse busyRuntimeRelease~ok, "runtime v1 cannot release while warm P1 owns snapshot"
  call assertEq "GENERATION_BUSY", busyRuntimeRelease~code, "runtime v1 busy reason explicit"
  call mustOk abilityRegistry~releaseGeneration(ability1~generationId), "release retired P1 ability generation"
  call assertEq "RELEASED", ability1~state, "P1 references released"
  call assertEq "RETIRED", cap1~state, "data v1 retires after profile snapshot release"
  call assertEq "RETIRED", rules1~state, "rules v1 retires after profile snapshot release"
  call mustOk kernel~releaseGeneration(cap1~generationId), "release data v1 code closure"
  call mustOk kernel~releaseGeneration(rules1~generationId), "release rules v1 code closure"

  call mustOk currentSession~release, "release P2 session"

  say "  p1=" || ability1~generationId || " state=" || ability1~state
  say "  p2=" || ability2~generationId || " state=" || ability2~state
  say "  runtime_data_active=" || kernel~registry~activeGenerationId("prod", "data.orders")
  say "  runtime_rules_active=" || kernel~registry~activeGenerationId("prod", "rules.customer")
  say "ABILITY REGISTRY V0.1 ACCEPTANCE: OK"
  return

makeProfile:
  procedure
  use arg profileId, revision, clientId, dataArtifactId, rulesArtifactId
  runtimeBindings = .array~new
  runtimeBindings~append(.AbilityRuntimeBinding~new("data", "data.orders", dataArtifactId))
  runtimeBindings~append(.AbilityRuntimeBinding~new("rules", "rules.customer", rulesArtifactId))

  abilities = .array~new
  abilities~append(.AbilityDescriptor~new("query", "QUERY", .array~of("data"), .true, "Bounded federated query"))
  abilities~append(.AbilityDescriptor~new("evaluate", "EVALUATE", .array~of("rules", "data"), .true, "Rule evaluation"))

  dataBindings = .array~new
  dataBindings~append(.AbilityDataBinding~new("orders", "data", "customer_orders", "READ"))

  ruleBindings = .array~new
  ruleBindings~append(.AbilityRuleBinding~new("customer-policy", "rules", "customer-policy"))

  return .AbilityProfileRevision~new(profileId, revision, clientId, runtimeBindings, abilities, dataBindings, ruleBindings, "customer chatbot profile")

stageFixture:
  procedure
  use arg kernel, verifier, path, moduleId, moduleKind, version, artifactId, entryClass, environment
  sourceResult = .RuntimeSourceLoader~readFile(path)
  call mustOk sourceResult, "read fixture " || path
  call mustOk verifier~pin(artifactId, sourceResult~value), "pin fixture " || artifactId
  artifact = .RuntimeArtifact~new(moduleId, moduleKind, version, artifactId, entryClass, sourceResult~value)
  stageResult = kernel~stage(environment, artifact)
  call mustOk stageResult, "stage fixture " || artifactId
  return stageResult~value

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
  use arg condition, label
  if \condition then do
    say "FAILED:" label
    exit 72
  end
  return

assertFalse:
  procedure
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 71
  end
  return

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 72
  end
  return

::requires "AbilityRegistry.cls"
