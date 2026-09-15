root = arg(1)
if root = "" then root = "."
registryRoot = value("RUNTIME_REGISTRY_ROOT",, "ENVIRONMENT")
if registryRoot = "" then registryRoot = "../runtime_registry_v0.13"
call main root, registryRoot
exit 0

main:
  procedure
  use arg root, registryRoot
  say "AI TOOL BROKER V0.4 WLU START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  tool = stage(kernel, verifier, root || "/fixtures/modules/ToolCapability_v1.cls", "tool.capability", "tool:capability:wlu:v1", "1.0.0")
  call ok kernel~activate("prod", "tool.capability", tool~generationId), "activate tool runtime"

  registry = .AbilityRegistry~new(kernel)
  staged = registry~stage("prod", profile(tool~artifactId)); call ok staged, "stage tool profile"; generation = staged~value
  call ok registry~activate("prod", "ai-tool-client", generation~generationId), "activate tool profile"

  clock = .WLUTestTimeSource~new(1000000)
  keys = .WLUFastMacKeyRing~new
  ignore = keys~addKey("hot-2026-08", "000102030405060708090a0b0c0d0e0f")
  ledger = .WLUMemoryLedger~new
  authority = .WLUAuthority~new(keys, ledger, clock)
  account = .WLUAccount~new("acct-ai-tool", 10000000)
  authority~addAccount(account)
  bucket = .WLUCapacityBucket~new("ai-tool-provider", 1000000, 250000, clock~nowTick)
  authority~addBucket(bucket)
  authority~bindAccount("ai-tool-client", "ABILITY:*", account~accountId)
  authority~bindBucket("ai-tool-client", "ABILITY:*", bucket~bucketId)
  card = .WLURateCard~new("ability.tools", "2026-08")
  card~addRule(.WLURateRule~new("TOOL_CALL", 100000))
  card~seal
  authority~addRateCard(card)
  authority~bindRateCard("ai-tool-client", "ABILITY:*", "ability.tools", "2026-08")

  bridge = .AbilityWLUBridge~new(authority)
  planner = .ToolWLUPlanner~new
  call ok bridge~registerPlanner("math.add", planner), "register tool WLU planner"

  router = .AbilityHttpRouter~new(registry, .AbilityCredentialStore~new, .AbilityResultStore~new(300, 20), bridge)
  catalog = .AIToolCatalog~new(.array~of(.AIToolDefinition~new("add_numbers", "math.add", "Add two integers")))
  broker = .AIToolBroker~new(registry, router, "prod", "ai-tool-client", catalog)
  offerOutcome = broker~offer; call ok offerOutcome, "derive WLU tool offer"; toolOffer = offerOutcome~value
  call eq generation~generationId, toolOffer~generationId, "WLU offer generation stamp"

  successArgs = .directory~new; successArgs["a"] = 30; successArgs["b"] = 12; successArgs["marker"] = "WLU-SUCCESS-SECRET"; successArgs["meta"] = .directory~new
  successCall = .AIProviderToolCall~new("wlu-call-001", "add_numbers", successArgs)
  prepared = broker~prepareOffered(toolOffer, successCall); call ok prepared, "prepare offered WLU success ticket"
  success = broker~execute(prepared~value)
  call yes success~ok, "WLU-managed tool succeeds"
  call eq 42, success~value~at("sum"), "WLU tool business value"
  call no success~value~hasIndex("wlu"), "business value excludes WLU"
  call no success~value~hasIndex("execution"), "business value excludes execution metadata"
  execution = success~execution
  call yes execution \== .nil, "detached execution metadata present"
  wlu = execution~at("wlu")
  call eq "ability.tools", wlu~at("rate_card_id"), "tool WLU rate card"
  call eq "2026-08", wlu~at("rate_card_version"), "tool WLU rate card version"
  call eq 400000, wlu~at("expected_micro_wlu"), "tool WLU conservative forecast"
  call eq 500000, wlu~at("ceiling_micro_wlu"), "tool WLU reservation ceiling"
  call eq 100000, wlu~at("actual_micro_wlu"), "tool WLU actual charge"
  call eq 1, wlu~at("actual_fact_count"), "tool WLU actual fact count"
  call eq "work.load.units/0.11", wlu~at("wlu_api_version"), "tool WLU API evidence"
  call eq 100000, account~spentMicroWlu, "successful tool charged actual only"

  inspectOutcome = registry~acquire("prod", "ai-tool-client"); call ok inspectOutcome, "acquire tool inspection session"; inspect = inspectOutcome~value
  fixture = inspect~module("tool")
  beforeDenied = fixture~runtimeInvocationCount

  deniedArgs = .directory~new; deniedArgs["a"] = 1; deniedArgs["b"] = 2; deniedArgs["marker"] = "WLU-DENIED-SECRET"; deniedArgs["meta"] = .directory~new
  deniedCall = .AIProviderToolCall~new("wlu-call-002", "add_numbers", deniedArgs)
  deniedPrepared = broker~prepareOffered(toolOffer, deniedCall); call ok deniedPrepared, "prepare offered ticket before capacity exhaustion"
  remaining = bucket~tokensMicroWlu
  hold = authority~reserve("ai-tool-client", "ABILITY:MATH.ADD", remaining, 30, "exhaust-ai-tool")
  call ok hold, "exhaust tool provider bucket"
  call eq 0, bucket~tokensMicroWlu, "tool provider bucket exhausted"

  denied = broker~execute(deniedPrepared~value)
  call no denied~ok, "capacity denied tool dispatch"
  call eq 429, denied~httpStatus, "tool WLU denial HTTP 429"
  call eq "AI_TOOL_WLU_DENIED", denied~code, "broker distinguishes WLU admission denial"
  call eq 2, denied~retryAfterSeconds, "broker retains retry hint"
  call eq beforeDenied, fixture~runtimeInvocationCount, "WLU denial occurs before tool execution"
  call eq 100000, account~spentMicroWlu, "denied tool work not charged"
  call eq "CONSUMED", deniedPrepared~value~state, "denied dispatch still consumes one-shot ticket"

  ignore = authority~release(hold~value)
  call ok inspect~release, "release inspection session"

  evidence = .AlchemyCanonical~encode(broker~instrumentationEvents)
  call yes evidence~pos("AI.TOOL.OFFER") > 0, "WLU path records tool offer event"
  call eq 0, evidence~pos("WLU-SUCCESS-SECRET"), "success arguments excluded from broker instrumentation"
  call eq 0, evidence~pos("WLU-DENIED-SECRET"), "denied arguments excluded from broker instrumentation"

  say "  actual_micro_wlu=" || wlu~at("actual_micro_wlu")
  say "  spent_micro_wlu=" || account~spentMicroWlu
  say "  retry_after=" || denied~retryAfterSeconds
  say "AI TOOL BROKER V0.4 WLU: OK"
  return

profile:
  procedure
  use arg artifactId
  bindings = .array~of(.AbilityRuntimeBinding~new("tool", "tool.capability", artifactId))
  inputSchema = schemaValue('{"type":"object","required":["a","b"],"properties":{"a":{"type":"integer"},"b":{"type":"integer"},"marker":{"type":"string"},"meta":{"type":"object"}},"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["sum","generation","invocation_count"],"properties":{"sum":{"type":"integer"},"generation":{"type":"string"},"invocation_count":{"type":"integer"}},"additionalProperties":false}')
  abilities = .array~of(.AbilityDescriptor~new("math.add", "CUSTOM", .array~of("tool"), .true, "integer addition tool", inputSchema, outputSchema))
  return .AbilityProfileRevision~new("ai-tool-wlu-profile", "1", "ai-tool-client", bindings, abilities, .array~new, .array~new, "AI tool broker WLU fixture")

schemaValue:
  procedure
  use arg text
  parsed = .AbilityJsonSchema~fromJson(text)
  call ok parsed, "parse tool WLU schema"
  return parsed~value

stage:
  procedure
  use arg kernel, verifier, path, moduleId, artifactId, version
  sourceOutcome = .RuntimeSourceLoader~readFile(path); call ok sourceOutcome, "read tool WLU fixture"
  call ok verifier~pin(artifactId, sourceOutcome~value), "pin tool WLU fixture"
  artifact = .RuntimeArtifact~new(moduleId, "CAPABILITY", version, artifactId, "ToolCapability", sourceOutcome~value)
  stageOutcome = kernel~stage("prod", artifact); call ok stageOutcome, "stage tool WLU fixture"
  return stageOutcome~value

ok:
  use arg outcome, label
  if outcome == .nil then do; say "FAILED:" label "nil"; exit 81; end
  if \outcome~ok then do; say "FAILED:" label outcome~code outcome~detail; exit 81; end
  return

yes:
  use arg conditionValue, label
  if \conditionValue then do; say "FAILED:" label; exit 82; end
  return

no:
  use arg conditionValue, label
  if conditionValue then do; say "FAILED:" label; exit 83; end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 84
  end
  return

::class ToolWLUPlanner public
::method plan
  use arg session, descriptor, requestBody
  facts = .array~of(.AbilityMeterFact~new("TOOL_CALL", 4, "ai-tool-broker-forecast"))
  scope = "ABILITY:" || descriptor~abilityId~upper
  return .AbilityWLUPlan~new(scope, facts, 500000, 0, 30, "")

::requires "AIToolBroker.cls"
::requires "AbilityWLU.cls"
::requires "WorkLoadUnits.cls"
::requires "AlchemyEvidence.cls"
