root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "AI TOOL ORCHESTRATOR V0.3 WLU START"
  aiRoot = value("AI_ACCESS_ROOT",, "ENVIRONMENT")
  brokerRoot = value("AI_TOOL_BROKER_ROOT",, "ENVIRONMENT")
  alchemyRoot = value("ALCHEMY_OBJECTS_ROOT",, "ENVIRONMENT")
  if aiRoot = "" then do; say "FAILED: AI_ACCESS_ROOT missing"; exit 60; end
  if brokerRoot = "" then do; say "FAILED: AI_TOOL_BROKER_ROOT missing"; exit 60; end
  if alchemyRoot = "" then do; say "FAILED: ALCHEMY_OBJECTS_ROOT missing"; exit 60; end

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  modelRuntime = stageModel(kernel, verifier, root, aiRoot, alchemyRoot, "ability:orchestrator:model:wlu:v1")
  call ok kernel~activate("prod", "ai.orchestrator.model.fixture", modelRuntime~generationId), "activate WLU model runtime"
  toolRuntime = stageTool(kernel, verifier, brokerRoot || "/fixtures/modules/ToolCapability_v1.cls", "tool:orchestrator:wlu:v1", "1.0.0")
  call ok kernel~activate("prod", "tool.capability", toolRuntime~generationId), "activate WLU tool runtime"

  registry = .AbilityRegistry~new(kernel)
  modelStage = registry~stage("prod", modelProfile(modelRuntime~artifactId)); call ok modelStage, "stage WLU model profile"; modelGeneration = modelStage~value
  call ok registry~activate("prod", "client-ai-orchestrator", modelGeneration~generationId), "activate WLU model profile"
  toolStage = registry~stage("prod", toolProfile(toolRuntime~artifactId)); call ok toolStage, "stage WLU tool profile"; toolGeneration = toolStage~value
  call ok registry~activate("prod", "ai-tool-orchestrator", toolGeneration~generationId), "activate WLU tool profile"

  clock = .WLUTestTimeSource~new(1000000)
  keys = .WLUFastMacKeyRing~new
  ignore = keys~addKey("hot-orch", "000102030405060708090a0b0c0d0e0f")
  ledger = .WLUMemoryLedger~new
  authority = .WLUAuthority~new(keys, ledger, clock)

  modelAccount = .WLUAccount~new("acct-orch-model", 10000000)
  toolAccount = .WLUAccount~new("acct-orch-tool", 10000000)
  authority~addAccount(modelAccount)
  authority~addAccount(toolAccount)
  modelBucket = .WLUCapacityBucket~new("orch-model", 3000000, 250000, clock~nowTick)
  toolBucket = .WLUCapacityBucket~new("orch-tool", 1000000, 250000, clock~nowTick)
  authority~addBucket(modelBucket)
  authority~addBucket(toolBucket)
  authority~bindAccount("client-ai-orchestrator", "ABILITY:*", modelAccount~accountId)
  authority~bindBucket("client-ai-orchestrator", "ABILITY:*", modelBucket~bucketId)
  authority~bindAccount("ai-tool-orchestrator", "ABILITY:*", toolAccount~accountId)
  authority~bindBucket("ai-tool-orchestrator", "ABILITY:*", toolBucket~bucketId)

  modelCard = .WLURateCard~new("orchestrator.ai.tokens", "2026-08")
  modelCard~addRule(.WLURateRule~new("AI_INPUT_TOKEN", 100000))
  modelCard~addRule(.WLURateRule~new("AI_OUTPUT_TOKEN", 100000))
  modelCard~seal
  authority~addRateCard(modelCard)
  authority~bindRateCard("client-ai-orchestrator", "ABILITY:*", "orchestrator.ai.tokens", "2026-08")

  toolCard = .WLURateCard~new("orchestrator.tools", "2026-08")
  toolCard~addRule(.WLURateRule~new("TOOL_CALL", 100000))
  toolCard~seal
  authority~addRateCard(toolCard)
  authority~bindRateCard("ai-tool-orchestrator", "ABILITY:*", "orchestrator.tools", "2026-08")

  bridge = .AbilityWLUBridge~new(authority)
  call ok bridge~registerPlanner("model.complete", .OrchestratorModelWLUPlanner~new), "register model WLU planner"
  call ok bridge~registerPlanner("math.add", .OrchestratorToolWLUPlanner~new), "register tool WLU planner"
  router = .AbilityHttpRouter~new(registry, .AbilityCredentialStore~new, .AbilityResultStore~new(300, 30), bridge)

  catalog = .AIToolCatalog~new(.array~of(.AIToolDefinition~new("add_numbers", "math.add", "Add two integers")))
  broker = .AIToolBroker~new(registry, router, "prod", "ai-tool-orchestrator", catalog)
  orchestrator = .AIToolOrchestrator~new(registry, router, "prod", "client-ai-orchestrator", broker)

  completed = orchestrator~runOnce("fixture-model", "tool-one", 4)
  call yes completed~ok, "WLU-managed orchestrated run succeeds"
  finalValue = completed~value
  call eq 42, finalValue~toolValue~at("sum"), "WLU orchestrated tool result"
  call no finalValue~toolValue~hasIndex("execution"), "tool business value excludes execution metadata"
  modelExecution = finalValue~modelExecution
  toolExecution = finalValue~toolExecution
  continuationExecution = finalValue~continuationModelExecution
  call yes modelExecution \== .nil, "initial model execution evidence retained"
  call yes toolExecution \== .nil, "tool execution evidence retained"
  call yes continuationExecution \== .nil, "continuation model execution evidence retained"
  modelWlu = modelExecution~at("wlu")
  toolWlu = toolExecution~at("wlu")
  continuationWlu = continuationExecution~at("wlu")
  call eq "orchestrator.ai.tokens", modelWlu~at("rate_card_id"), "model WLU rate card"
  call eq 700000, modelWlu~at("expected_micro_wlu"), "model forecast includes prompt, tool offer and max output"
  call eq 200000, modelWlu~at("actual_micro_wlu"), "model actual settled from provider usage"
  call eq "orchestrator.tools", toolWlu~at("rate_card_id"), "tool WLU rate card"
  call eq 400000, toolWlu~at("expected_micro_wlu"), "tool conservative forecast"
  call eq 100000, toolWlu~at("actual_micro_wlu"), "tool actual settled"
  call eq 700000, continuationWlu~at("expected_micro_wlu"), "continuation forecast counts three structured messages plus max output"
  call eq 500000, continuationWlu~at("actual_micro_wlu"), "continuation actual settled from provider usage"
  call eq 700000, modelAccount~spentMicroWlu, "initial plus continuation model work charged actual only"
  call eq 100000, toolAccount~spentMicroWlu, "tool account charged actual only"

  modelInspectOutcome = registry~acquire("prod", "client-ai-orchestrator"); call ok modelInspectOutcome, "inspect model before denial"; modelInspect = modelInspectOutcome~value
  modelModule = modelInspect~module("provider")
  beforeModelDenied = modelModule~runtimeInvocationCount
  modelRemaining = modelBucket~tokensMicroWlu
  modelHold = authority~reserve("client-ai-orchestrator", "ABILITY:MODEL.COMPLETE", modelRemaining, 30, "exhaust-orch-model")
  call ok modelHold, "exhaust model capacity"
  deniedModel = orchestrator~infer("fixture-model", "tool-one", 4)
  call no deniedModel~ok, "model capacity denial returned"
  call eq "AI_MODEL_WLU_DENIED", deniedModel~code, "model WLU denial code"
  call eq 429, deniedModel~httpStatus, "model WLU denial status"
  call eq 3, deniedModel~retryAfterSeconds, "model WLU retry hint"
  call eq beforeModelDenied, modelModule~runtimeInvocationCount, "model WLU denial before provider execution"
  call eq 700000, modelAccount~spentMicroWlu, "model WLU denial not charged"
  ignore = authority~release(modelHold~value)
  call ok modelInspect~release, "release model inspection"

  pendingOutcome = orchestrator~infer("fixture-model", "tool-one", 4)
  call yes pendingOutcome~ok, "model inference succeeds before tool capacity denial"
  pending = pendingOutcome~value
  call yes pending~modelExecution \== .nil, "pending turn retains model execution evidence"
  call eq 200000, pending~modelExecution~at("wlu")~at("actual_micro_wlu"), "pending model work evidence"

  toolInspectOutcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok toolInspectOutcome, "inspect tool before denial"; toolInspect = toolInspectOutcome~value
  toolModule = toolInspect~module("tool")
  beforeToolDenied = toolModule~runtimeInvocationCount
  toolRemaining = toolBucket~tokensMicroWlu
  toolHold = authority~reserve("ai-tool-orchestrator", "ABILITY:MATH.ADD", toolRemaining, 30, "exhaust-orch-tool")
  call ok toolHold, "exhaust tool capacity"
  deniedTool = orchestrator~dispatch(pending)
  call no deniedTool~ok, "tool capacity denial returned"
  call eq "AI_TOOL_WLU_DENIED", deniedTool~code, "tool WLU denial code"
  call eq 429, deniedTool~httpStatus, "tool WLU denial status"
  call eq 2, deniedTool~retryAfterSeconds, "tool WLU retry hint"
  call eq beforeToolDenied, toolModule~runtimeInvocationCount, "tool WLU denial before tool execution"
  call yes deniedTool~modelExecution \== .nil, "tool denial retains already-performed model evidence"
  call eq 200000, deniedTool~modelExecution~at("wlu")~at("actual_micro_wlu"), "tool denial preserves model charge evidence"
  call eq 900000, modelAccount~spentMicroWlu, "second model inference charged actual work"
  call eq 100000, toolAccount~spentMicroWlu, "denied tool adds no charge"
  ignore = authority~release(toolHold~value)
  call ok toolInspect~release, "release tool inspection"

  modelInspect2Outcome = registry~acquire("prod", "client-ai-orchestrator"); call ok modelInspect2Outcome, "inspect model before continuation denial"; modelInspect2 = modelInspect2Outcome~value
  modelBeforeContinuationDenied = modelInspect2~module("provider")~runtimeInvocationCount
  call ok modelInspect2~release, "release continuation-denial model inspection"
  toolInspect2Outcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok toolInspect2Outcome, "inspect tool before continuation denial"; toolInspect2 = toolInspect2Outcome~value
  toolBeforeContinuationDenied = toolInspect2~module("tool")~runtimeInvocationCount
  call ok toolInspect2~release, "release continuation-denial tool inspection"

  modelAvailable = modelBucket~tokensMicroWlu
  modelHoldAmount = modelAvailable - 800000
  call yes modelHoldAmount > 0, "enough model capacity to create continuation-denial window"
  continuationHold = authority~reserve("client-ai-orchestrator", "ABILITY:MODEL.COMPLETE", modelHoldAmount, 30, "leave-only-first-turn-capacity")
  call ok continuationHold, "reserve model capacity leaving 800000 micro-WLU"
  call eq 800000, modelBucket~tokensMicroWlu, "first model turn fits but second model turn cannot fit after actual settlement"

  deniedContinuation = orchestrator~runOnce("fixture-model", "tool-one", 4)
  call no deniedContinuation~ok, "continuation capacity denial returned"
  call eq "AI_MODEL_WLU_DENIED", deniedContinuation~code, "continuation WLU denial code"
  call eq "MODEL_CONTINUATION", deniedContinuation~phase, "continuation WLU denial phase"
  call eq 429, deniedContinuation~httpStatus, "continuation WLU denial status"
  call yes deniedContinuation~modelExecution \== .nil, "continuation denial preserves initial model evidence"
  call yes deniedContinuation~toolExecution \== .nil, "continuation denial preserves executed tool evidence"
  call eq 200000, deniedContinuation~modelExecution~at("wlu")~at("actual_micro_wlu"), "continuation denial initial model charge evidence"
  call eq 100000, deniedContinuation~toolExecution~at("wlu")~at("actual_micro_wlu"), "continuation denial tool charge evidence"
  call eq 1100000, modelAccount~spentMicroWlu, "continuation denial charges initial model work but not denied continuation"
  call eq 200000, toolAccount~spentMicroWlu, "continuation denial retains performed tool charge"

  modelInspect3Outcome = registry~acquire("prod", "client-ai-orchestrator"); call ok modelInspect3Outcome, "inspect model after continuation denial"; modelInspect3 = modelInspect3Outcome~value
  call eq modelBeforeContinuationDenied + 1, modelInspect3~module("provider")~runtimeInvocationCount, "continuation WLU denial occurs before second provider invocation"
  call ok modelInspect3~release, "release post-continuation model inspection"
  toolInspect3Outcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok toolInspect3Outcome, "inspect tool after continuation denial"; toolInspect3 = toolInspect3Outcome~value
  call eq toolBeforeContinuationDenied + 1, toolInspect3~module("tool")~runtimeInvocationCount, "continuation denial occurs after exactly one tool invocation"
  call ok toolInspect3~release, "release post-continuation tool inspection"
  ignore = authority~release(continuationHold~value)

  evidence = .AlchemyCanonical~encode(orchestrator~instrumentationEvents)
  call eq 0, evidence~pos("tool-one"), "WLU instrumentation excludes prompt"
  call eq 0, evidence~pos("ORCHESTRATOR-SECRET-ARG"), "WLU instrumentation excludes tool arguments"

  say "  model_actual_micro_wlu=" || modelWlu~at("actual_micro_wlu")
  say "  tool_actual_micro_wlu=" || toolWlu~at("actual_micro_wlu")
  say "  continuation_actual_micro_wlu=" || continuationWlu~at("actual_micro_wlu")
  say "  model_spent_micro_wlu=" || modelAccount~spentMicroWlu
  say "  tool_spent_micro_wlu=" || toolAccount~spentMicroWlu
  say "AI TOOL ORCHESTRATOR V0.3 WLU: OK"
  return

stageModel:
  procedure
  use arg kernel, verifier, root, aiRoot, alchemyRoot, artifactId
  builder = .RuntimeBundleBuilder~new
  call ok builder~addFile(alchemyRoot || "/src/AlchemyEvidence.cls", "AlchemyEvidence.cls"), "bundle Alchemy evidence"
  call ok builder~addFile(alchemyRoot || "/src/AlchemySecurity.cls", "AlchemySecurity.cls"), "bundle Alchemy security"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyLockedMethod.cls", "AlchemyLockedMethod.cls"), "bundle Alchemy locked method"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyObject.cls", "AlchemyObject.cls"), "bundle Alchemy object"
  call ok builder~addFile(aiRoot || "/src/AIProviderAccess.cls", "AIProviderAccess.cls"), "bundle AI access"
  call ok builder~addFile(root || "/fixtures/modules/OrchestratorModelProvider.cls", "OrchestratorModelProvider.cls"), "bundle orchestrator model fixture"
  built = builder~build; call ok built, "build WLU model bundle"
  bundle = built~value
  call ok verifier~pin(artifactId, bundle~sourceLines), "pin WLU model bundle"
  artifact = .RuntimeArtifact~new("ai.orchestrator.model.fixture", "CAPABILITY", "1.0.0", artifactId, "OrchestratorModelModule", bundle~sourceLines, .AIProviderAccessBuild~API_VERSION)
  staged = kernel~stage("prod", artifact); call ok staged, "stage WLU model bundle"
  return staged~value

stageTool:
  procedure
  use arg kernel, verifier, path, artifactId, version
  sourceOutcome = .RuntimeSourceLoader~readFile(path); call ok sourceOutcome, "read WLU tool fixture"
  call ok verifier~pin(artifactId, sourceOutcome~value), "pin WLU tool fixture"
  artifact = .RuntimeArtifact~new("tool.capability", "CAPABILITY", version, artifactId, "ToolCapability", sourceOutcome~value)
  staged = kernel~stage("prod", artifact); call ok staged, "stage WLU tool fixture"
  return staged~value

modelProfile:
  procedure
  use arg artifactId
  bindings = .array~of(.AbilityRuntimeBinding~new("provider", "ai.orchestrator.model.fixture", artifactId))
  inputSchema = schemaValue('{"type":"object","required":["model","prompt"],"properties":{"model":{"type":"string","minLength":1},"prompt":{"type":"string"},"max_output_tokens":{"type":"integer","minimum":1,"maximum":128},"tools":{"type":"array","maxItems":16,"items":{"type":"object","required":["name","input_schema"],"properties":{"name":{"type":"string","minLength":1},"description":{"type":"string"},"input_schema":{"type":"object"}},"additionalProperties":false}},"messages":{"type":"array","maxItems":64,"items":{"type":"object","required":["role","content"],"properties":{"role":{"type":"string","enum":["user","assistant","tool"]},"content":{"type":"string"},"tool_call_id":{"type":"string"},"tool_calls":{"type":"array","maxItems":64,"items":{"type":"object","required":["call_id","name","arguments"],"properties":{"call_id":{"type":"string","minLength":1},"name":{"type":"string","minLength":1},"arguments":{"type":"object"}},"additionalProperties":false}}},"additionalProperties":false}}},"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["text","model","finish_reason"],"properties":{"text":{"type":"string"},"model":{"type":"string"},"finish_reason":{"type":"string"},"tool_calls":{"type":"array","maxItems":64,"items":{"type":"object","required":["call_id","name","arguments"],"properties":{"call_id":{"type":"string","minLength":1},"name":{"type":"string","minLength":1},"arguments":{"type":"object"}},"additionalProperties":false}}},"additionalProperties":false}')
  abilities = .array~of(.AbilityDescriptor~new("model.complete", "MODEL", .array~of("provider"), .true, "orchestrator model fixture", inputSchema, outputSchema))
  return .AbilityProfileRevision~new("ai-orchestrator-model", "1", "client-ai-orchestrator", bindings, abilities, .array~new, .array~new, "AI tool orchestrator model fixture")

toolProfile:
  procedure
  use arg artifactId
  bindings = .array~of(.AbilityRuntimeBinding~new("tool", "tool.capability", artifactId))
  inputSchema = schemaValue('{"type":"object","required":["a","b"],"properties":{"a":{"type":"integer"},"b":{"type":"integer"},"marker":{"type":"string"},"meta":{"type":"object"}},"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["sum","generation","invocation_count"],"properties":{"sum":{"type":"integer"},"generation":{"type":"string"},"invocation_count":{"type":"integer"}},"additionalProperties":false}')
  abilities = .array~of(.AbilityDescriptor~new("math.add", "CUSTOM", .array~of("tool"), .true, "integer addition tool", inputSchema, outputSchema))
  return .AbilityProfileRevision~new("ai-orchestrator-tools", "1", "ai-tool-orchestrator", bindings, abilities, .array~new, .array~new, "AI tool orchestrator WLU tool fixture")

schemaValue:
  procedure
  use arg text
  parsed = .AbilityJsonSchema~fromJson(text)
  call ok parsed, "parse WLU schema"
  return parsed~value

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

::requires "AIToolOrchestrator.cls"
::requires "OrchestratorModelWLUPlanner.cls"
::requires "ToolWLUPlanner.cls"
::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityHttpServer.cls"
::requires "AbilityWLU.cls"
::requires "WorkLoadUnits.cls"
::requires "AlchemyEvidence.cls"
::requires "json.cls"
