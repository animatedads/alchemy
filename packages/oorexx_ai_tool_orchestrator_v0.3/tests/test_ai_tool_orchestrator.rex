root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "AI TOOL ORCHESTRATOR V0.3 CORE START"
  call eq "0.3", .AIToolOrchestratorBuild~RELEASE, "orchestrator release contract"
  call eq "0.13", .RuntimeRegistryBuild~RELEASE, "Runtime Registry release contract"
  call eq "0.7", .AbilityHttpBuild~RELEASE, "Ability HTTP release contract"
  call eq "0.5", .AIProviderAccessBuild~RELEASE, "AI Access release contract"
  call eq "0.4", .AIToolBrokerBuild~RELEASE, "AI Tool Broker release contract"
  aiRoot = value("AI_ACCESS_ROOT",, "ENVIRONMENT")
  brokerRoot = value("AI_TOOL_BROKER_ROOT",, "ENVIRONMENT")
  alchemyRoot = value("ALCHEMY_OBJECTS_ROOT",, "ENVIRONMENT")
  if aiRoot = "" then do; say "FAILED: AI_ACCESS_ROOT missing"; exit 60; end
  if brokerRoot = "" then do; say "FAILED: AI_TOOL_BROKER_ROOT missing"; exit 60; end
  if alchemyRoot = "" then do; say "FAILED: ALCHEMY_OBJECTS_ROOT missing"; exit 60; end

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  modelRuntime = stageModel(kernel, verifier, root, aiRoot, alchemyRoot, "ability:orchestrator:model:v1")
  call ok kernel~activate("prod", "ai.orchestrator.model.fixture", modelRuntime~generationId), "activate model runtime"
  tool1 = stageTool(kernel, verifier, brokerRoot || "/fixtures/modules/ToolCapability_v1.cls", "tool:orchestrator:v1", "1.0.0")
  call ok kernel~activate("prod", "tool.capability", tool1~generationId), "activate tool runtime v1"

  registry = .AbilityRegistry~new(kernel)
  modelStage = registry~stage("prod", modelProfile(modelRuntime~artifactId)); call ok modelStage, "stage model profile"; modelGeneration = modelStage~value
  call ok registry~activate("prod", "client-ai-orchestrator", modelGeneration~generationId), "activate model profile"
  toolStage1 = registry~stage("prod", toolProfile(tool1~artifactId, "1")); call ok toolStage1, "stage tool profile v1"; toolGeneration1 = toolStage1~value
  call ok registry~activate("prod", "ai-tool-orchestrator", toolGeneration1~generationId), "activate tool profile v1"

  router = .AbilityHttpRouter~new(registry, .AbilityCredentialStore~new, .AbilityResultStore~new(300, 30))
  catalog = .AIToolCatalog~new(.array~of(.AIToolDefinition~new("add_numbers", "math.add", "Add two integers")))
  broker = .AIToolBroker~new(registry, router, "prod", "ai-tool-orchestrator", catalog)
  orchestrator = .AIToolOrchestrator~new(registry, router, "prod", "client-ai-orchestrator", broker)
  call yes orchestrator~isa(.AlchemyObject), "orchestrator uses Alchemy base"
  call yes orchestrator~checkSurfaceContract~ok, "orchestrator Alchemy surface contract"

  plain = orchestrator~infer("fixture-model", "text-only", 4)
  call yes plain~ok, "text-only inference"
  pendingText = plain~value
  call no pendingText~hasToolCall, "text-only turn has no tool proposal"
  call no pendingText~isa(.AlchemyObject), "pending turn remains plain DTO"
  call no pendingText~hasMethod("RELEASE"), "pending turn has no session release authority"
  call no pendingText~hasMethod("MODULE"), "pending turn has no Runtime module authority"
  call eq 0, registry~generation(modelGeneration~generationId)~leaseCount, "model inference retains no model lease"
  call eq 0, registry~generation(toolGeneration1~generationId)~leaseCount, "model inference retains no tool lease"
  plainFinal = orchestrator~dispatch(pendingText)
  call yes plainFinal~ok, "text-only pending turn completes"
  call no plainFinal~value~toolExecuted, "text-only completion executes no tool"
  call eq "ORCH:text-only", plainFinal~value~text, "text-only model output preserved"

  stable = orchestrator~runOnce("fixture-model", "tool-one", 4)
  call yes stable~ok, "stable one-tool run"
  stableValue = stable~value
  call yes stableValue~toolExecuted, "one tool executed"
  call eq "add_numbers", stableValue~toolName, "tool name"
  call eq "orch-call-001", stableValue~toolCallId, "tool call id"
  call eq 42, stableValue~toolValue~at("sum"), "tool result sum"
  call eq "TOOL-V1", stableValue~toolValue~at("generation"), "stable run used tool v1"
  call eq toolGeneration1~generationId, stableValue~toolGenerationId, "stable run reports v1 Ability generation"
  call no stableValue~toolValue~hasIndex("execution"), "tool business value excludes execution metadata"
  call yes stableValue~continuationPerformed, "stable run performs one structured continuation"
  call eq "ORCH-CONTINUED:42:TOOL-V1", stableValue~text, "stable run returns continuation model text"
  call yes stableValue~continuationModelGenerationId <> "", "stable run reports continuation model generation"

  inspect1Outcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok inspect1Outcome, "inspect tool v1"; inspect1 = inspect1Outcome~value
  toolModule1 = inspect1~module("tool")
  beforeLoop = toolModule1~runtimeInvocationCount
  call ok inspect1~release, "release tool v1 inspection"

  loopPendingOutcome = orchestrator~infer("fixture-model", "tool-loop", 4)
  call yes loopPendingOutcome~ok, "loop fixture initial inference"
  loopDenied = orchestrator~dispatch(loopPendingOutcome~value)
  call no loopDenied~ok, "continuation tool proposal rejected"
  call eq "AI_TOOL_CONTINUATION_CALL_UNSUPPORTED", loopDenied~code, "continuation tool proposal code"
  call eq "MODEL_CONTINUATION", loopDenied~phase, "continuation loop rejected at model boundary"
  inspectLoopOutcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok inspectLoopOutcome, "inspect after continuation loop"; inspectLoop = inspectLoopOutcome~value
  call eq beforeLoop + 1, inspectLoop~module("tool")~runtimeInvocationCount, "continuation rejection executes exactly the first tool and no second tool"
  beforeMany = inspectLoop~module("tool")~runtimeInvocationCount
  call ok inspectLoop~release, "release continuation loop inspection"

  many = orchestrator~infer("fixture-model", "tool-many", 4)
  call no many~ok, "multiple tool calls rejected"
  call eq "AI_TOOL_MULTIPLE_CALLS_UNSUPPORTED", many~code, "multiple call rejection code"
  inspectManyOutcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok inspectManyOutcome, "inspect after multiple call"; inspectMany = inspectManyOutcome~value
  call eq beforeMany, inspectMany~module("tool")~runtimeInvocationCount, "multiple call response causes no partial tool execution"
  call ok inspectMany~release, "release multiple-call inspection"

  staleInfer = orchestrator~infer("fixture-model", "tool-one", 4)
  call yes staleInfer~ok, "derive pending v1 tool turn"
  stalePending = staleInfer~value
  call yes stalePending~hasToolCall, "pending v1 turn has one proposal"
  call eq toolGeneration1~generationId, stalePending~toolOffer~generationId, "pending offer stamped v1"
  call no stalePending~toolCall~hasMethod("ABILITYID"), "provider call exposes no private Ability id"
  call eq 0, registry~generation(toolGeneration1~generationId)~leaseCount, "pending v1 turn retains no tool lease"

  tool2 = stageTool(kernel, verifier, brokerRoot || "/fixtures/modules/ToolCapability_v2.cls", "tool:orchestrator:v2", "2.0.0")
  call ok kernel~activate("prod", "tool.capability", tool2~generationId), "activate tool runtime v2"
  toolStage2 = registry~stage("prod", toolProfile(tool2~artifactId, "2")); call ok toolStage2, "stage tool profile v2"; toolGeneration2 = toolStage2~value
  call ok registry~activate("prod", "ai-tool-orchestrator", toolGeneration2~generationId), "activate tool profile v2"

  inspect2Outcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok inspect2Outcome, "inspect tool v2"; inspect2 = inspect2Outcome~value
  toolModule2 = inspect2~module("tool")
  beforeStale = toolModule2~runtimeInvocationCount
  call ok inspect2~release, "release tool v2 inspection"

  staleDispatch = orchestrator~dispatch(stalePending)
  call no staleDispatch~ok, "stale pending turn refused"
  call eq "AI_TOOL_OFFER_STALE", staleDispatch~code, "stale offer code propagated"
  call eq "TOOL_PREPARE", staleDispatch~phase, "stale refusal happens before tool execution"
  call eq 0, registry~generation(toolGeneration2~generationId)~leaseCount, "stale refusal leaks no v2 lease"
  inspectStaleOutcome = registry~acquire("prod", "ai-tool-orchestrator"); call ok inspectStaleOutcome, "inspect after stale refusal"; inspectStale = inspectStaleOutcome~value
  call eq beforeStale, inspectStale~module("tool")~runtimeInvocationCount, "stale refusal invokes no v2 tool"
  call ok inspectStale~release, "release stale inspection"

  fresh = orchestrator~runOnce("fixture-model", "tool-one", 4)
  call yes fresh~ok, "fresh run after tool deployment"
  call eq "TOOL-V2", fresh~value~toolValue~at("generation"), "fresh inference executes v2 tool"
  call eq toolGeneration2~generationId, fresh~value~toolGenerationId, "fresh result reports v2 Ability generation"
  call eq "ORCH-CONTINUED:42:TOOL-V2", fresh~value~text, "fresh run continuation sees v2 tool result"
  call yes fresh~value~continuationPerformed, "fresh run performs exactly one continuation"

  evidence = .AlchemyCanonical~encode(orchestrator~instrumentationEvents)
  call yes evidence~pos("AI.ORCHESTRATION.INFER") > 0, "inference instrumentation present"
  call yes evidence~pos("AI.ORCHESTRATION.DISPATCH") > 0, "dispatch instrumentation present"
  call eq 0, evidence~pos("tool-one"), "prompt excluded from orchestrator instrumentation"
  call eq 0, evidence~pos("ORCHESTRATOR-SECRET-ARG"), "tool arguments excluded from orchestrator instrumentation"
  call eq 0, evidence~pos("ORCHESTRATOR-SCHEMA-DO-NOT-LOG"), "tool schema excluded from orchestrator instrumentation"

  say "  model_generation=" || modelGeneration~generationId
  say "  stale_tool_generation=" || toolGeneration1~generationId
  say "  current_tool_generation=" || toolGeneration2~generationId
  say "  events=" || orchestrator~instrumentationEvents~items
  say "AI TOOL ORCHESTRATOR V0.3 CORE: OK"
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
  built = builder~build; call ok built, "build orchestrator model bundle"
  bundle = built~value
  call ok verifier~pin(artifactId, bundle~sourceLines), "pin orchestrator model bundle"
  artifact = .RuntimeArtifact~new("ai.orchestrator.model.fixture", "CAPABILITY", "1.0.0", artifactId, "OrchestratorModelModule", bundle~sourceLines, .AIProviderAccessBuild~API_VERSION)
  staged = kernel~stage("prod", artifact); call ok staged, "stage orchestrator model bundle"
  return staged~value

stageTool:
  procedure
  use arg kernel, verifier, path, artifactId, version
  sourceOutcome = .RuntimeSourceLoader~readFile(path); call ok sourceOutcome, "read tool fixture"
  call ok verifier~pin(artifactId, sourceOutcome~value), "pin tool fixture"
  artifact = .RuntimeArtifact~new("tool.capability", "CAPABILITY", version, artifactId, "ToolCapability", sourceOutcome~value)
  staged = kernel~stage("prod", artifact); call ok staged, "stage tool fixture"
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
  use arg artifactId, revision
  bindings = .array~of(.AbilityRuntimeBinding~new("tool", "tool.capability", artifactId))
  inputSchema = schemaValue('{"type":"object","description":"ORCHESTRATOR-SCHEMA-DO-NOT-LOG","required":["a","b"],"properties":{"a":{"type":"integer"},"b":{"type":"integer"},"marker":{"type":"string"},"meta":{"type":"object"}},"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["sum","generation","invocation_count"],"properties":{"sum":{"type":"integer"},"generation":{"type":"string"},"invocation_count":{"type":"integer"}},"additionalProperties":false}')
  abilities = .array~of(.AbilityDescriptor~new("math.add", "CUSTOM", .array~of("tool"), .true, "integer addition tool", inputSchema, outputSchema))
  return .AbilityProfileRevision~new("ai-orchestrator-tools", revision, "ai-tool-orchestrator", bindings, abilities, .array~new, .array~new, "AI tool orchestrator tool fixture")

schemaValue:
  procedure
  use arg text
  parsed = .AbilityJsonSchema~fromJson(text)
  call ok parsed, "parse schema"
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
::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityHttpServer.cls"
::requires "AlchemyEvidence.cls"
::requires "json.cls"
