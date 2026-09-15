root = arg(1)
if root = "" then root = "."
registryRoot = value("RUNTIME_REGISTRY_ROOT",, "ENVIRONMENT")
if registryRoot = "" then registryRoot = "../runtime_registry_v0.13"
call main root, registryRoot
exit 0

main:
  procedure
  use arg root, registryRoot
  say "AI TOOL BROKER V0.4 CORE START"

  call eq "0.4", .AIToolBrokerBuild~RELEASE, "broker release marker"
  call eq "ai.tool.broker/0.4", .AIToolBrokerBuild~API_VERSION, "broker API marker"
  call eq "0.13", .RuntimeRegistryBuild~RELEASE, "Runtime Registry dependency marker"
  call eq "0.7", .AbilityHttpBuild~RELEASE, "Ability HTTP dependency marker"
  call eq "0.7", .AlchemyObject~VERSION, "Alchemy base dependency marker"
  call eq "0.5", .AIProviderAccessBuild~RELEASE, "AI Access value-contract dependency marker"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  tool1 = stage(kernel, verifier, root || "/fixtures/modules/ToolCapability_v1.cls", "tool.capability", "tool:capability:v1", "1.0.0")
  tool2 = stage(kernel, verifier, root || "/fixtures/modules/ToolCapability_v2.cls", "tool.capability", "tool:capability:v2", "2.0.0")
  call ok kernel~activate("prod", "tool.capability", tool1~generationId), "activate tool runtime v1"

  registry = .AbilityRegistry~new(kernel)
  p1 = profile(tool1~artifactId, "1")
  staged1 = registry~stage("prod", p1); call ok staged1, "stage profile v1"; ag1 = staged1~value
  call ok registry~activate("prod", "ai-tool-client", ag1~generationId), "activate profile v1"

  keys = .AbilityCredentialStore~new
  router = .AbilityHttpRouter~new(registry, keys, .AbilityResultStore~new(300, 20))
  definition = .AIToolDefinition~new("add_numbers", "math.add", "Add two integers")
  catalog = .AIToolCatalog~new(.array~of(definition))
  broker = .AIToolBroker~new(registry, router, "prod", "ai-tool-client", catalog)

  call yes catalog~isa(.AlchemyObject), "catalog uses Alchemy base"
  call yes broker~isa(.AlchemyObject), "broker uses Alchemy base"
  call yes catalog~checkSurfaceContract~ok, "catalog Alchemy surface contract"
  call yes broker~checkSurfaceContract~ok, "broker Alchemy surface contract"
  call no proposalClassIsAlchemy(), "proposal DTO remains narrow plain object"
  call no definition~isa(.AlchemyObject), "definition DTO remains narrow plain object"
  descriptions = catalog~descriptions
  call eq 1, descriptions~items, "one model-visible tool"
  publicDescription = descriptions~at(1)
  call eq "add_numbers", publicDescription~at("name"), "public tool name"
  call no publicDescription~hasIndex("ability_id"), "internal Ability id not model-visible"

  offered1Outcome = broker~offer; call ok offered1Outcome, "derive v1 tool offer"; offered1 = offered1Outcome~value
  call no offered1~isa(.AlchemyObject), "tool offer is non-authority plain DTO"
  call eq ag1~generationId, offered1~generationId, "offer stamped with active v1 Ability generation"
  call eq 1, offered1~count, "offer contains one granted tool"
  providerDefinition = offered1~toolDefinitions~at(1)
  call yes providerDefinition~isa(.AIProviderToolDefinition), "offer uses provider-neutral tool definition"
  call eq "add_numbers", providerDefinition~name, "offered provider tool name"
  call no providerDefinition~hasMethod("ABILITYID"), "offered definition exposes no private Ability id"
  call no providerDefinition~hasMethod("GENERATIONID"), "provider definition does not expose generation stamp"
  offeredSchema = providerDefinition~inputSchema
  call eq "object", offeredSchema~at("type"), "offered schema is exact Ability input object schema"
  call eq "MODEL-SCHEMA-DO-NOT-INSTRUMENT", offeredSchema~at("description"), "Ability schema annotation reaches model-safe offer"
  offeredSchema["description"] = "tampered"
  call eq "MODEL-SCHEMA-DO-NOT-INSTRUMENT", providerDefinition~inputSchema~at("description"), "offered schema accessor detached"

  original = .directory~new
  original["a"] = 20
  original["b"] = 22
  original["marker"] = "SECRET-TOOL-ARG-DO-NOT-LOG"
  nested = .directory~new; nested["phase"] = "approved"; original["meta"] = nested
  proposal = .AIToolProposal~new("call-001", "add_numbers", original)
  original["a"] = 900
  nested["phase"] = "mutated-after-proposal"
  proposalCopy = proposal~arguments
  proposalCopy["b"] = 999
  proposalCopy~at("meta")["phase"] = "mutated-copy"

  prepared = broker~prepare(proposal); call ok prepared, "prepare v1 ticket"; ticket = prepared~value
  call yes ticket~isa(.AlchemyObject), "ticket uses Alchemy base"
  call yes ticket~checkSurfaceContract~ok, "ticket Alchemy surface contract"
  call eq ag1~generationId, ticket~generationId, "ticket pins profile v1"
  call eq 1, registry~generation(ag1~generationId)~leaseCount, "ticket owns one held session"

  call ok kernel~activate("prod", "tool.capability", tool2~generationId), "activate tool runtime v2"
  p2 = profile(tool2~artifactId, "2")
  staged2 = registry~stage("prod", p2); call ok staged2, "stage profile v2"; ag2 = staged2~value
  call ok registry~activate("prod", "ai-tool-client", ag2~generationId), "activate profile v2"
  call eq "DRAINING", registry~generation(ag1~generationId)~state, "held ticket keeps v1 draining"
  call eq 1, registry~generation(ag1~generationId)~leaseCount, "v1 lease retained across activation"

  staleArgs = .directory~new; staleArgs["a"] = 3; staleArgs["b"] = 4; staleArgs["marker"] = "STALE-OFFER-ARG"; staleArgs["meta"] = .directory~new
  staleCall = .AIProviderToolCall~new("call-stale-001", "add_numbers", staleArgs)
  beforeStaleLease = registry~generation(ag2~generationId)~leaseCount
  stalePrepared = broker~prepareOffered(offered1, staleCall)
  call no stalePrepared~ok, "v1 model offer rejected after v2 profile activation"
  call eq "AI_TOOL_OFFER_STALE", stalePrepared~code, "stale offer code"
  call eq beforeStaleLease, registry~generation(ag2~generationId)~leaseCount, "stale offer releases newly acquired v2 session"

  result1 = broker~execute(ticket)
  call yes result1~ok, "execute held v1 ticket"
  call eq 200, result1~httpStatus, "v1 ticket HTTP status"
  call eq 42, result1~value~at("sum"), "detached proposal arguments immune to later mutation"
  call eq "TOOL-V1", result1~value~at("generation"), "held ticket executes v1"
  call eq ag1~generationId, result1~generationId, "dispatch reports pinned v1 generation"
  call eq "CONSUMED", ticket~state, "ticket consumed after dispatch"
  call eq 0, registry~generation(ag1~generationId)~leaseCount, "ticket releases held v1 session"
  call eq "RETIRED", registry~generation(ag1~generationId)~state, "v1 retires when ticket releases"

  repeated = broker~execute(ticket)
  call no repeated~ok, "ticket cannot execute twice"
  call eq "AI_TOOL_TICKET_CONSUMED", repeated~code, "one-shot ticket code"

  offered2Outcome = broker~offer; call ok offered2Outcome, "derive v2 tool offer"; offered2 = offered2Outcome~value
  call eq ag2~generationId, offered2~generationId, "fresh offer stamped with v2 generation"
  args2 = .directory~new; args2["a"] = 7; args2["b"] = 8; args2["marker"] = "SECOND-MARKER"; args2["meta"] = .directory~new
  providerCall2 = .AIProviderToolCall~new("call-002", "add_numbers", args2)
  prepared2 = broker~prepareOffered(offered2, providerCall2); call ok prepared2, "prepare v2 ticket from provider call and matching offer"
  ticket2 = prepared2~value
  call eq ag2~generationId, ticket2~generationId, "new offered ticket pins v2"
  result2 = broker~execute(ticket2)
  call yes result2~ok, "execute v2 ticket"
  call eq 15, result2~value~at("sum"), "v2 sum"
  call eq "TOOL-V2", result2~value~at("generation"), "new ticket executes v2"

  beforeDeniedLease = registry~generation(ag2~generationId)~leaseCount
  badArgs = .directory~new; badArgs["a"] = "not-an-integer"; badArgs["b"] = 2; badArgs["marker"] = "BAD-SCHEMA"; badArgs["meta"] = .directory~new
  deniedSchema = broker~prepare(.AIToolProposal~new("call-003", "add_numbers", badArgs))
  call no deniedSchema~ok, "schema-invalid proposal denied"
  call eq "AI_TOOL_ARGUMENT_SCHEMA", deniedSchema~code, "schema denial code"
  call eq beforeDeniedLease, registry~generation(ag2~generationId)~leaseCount, "schema denial releases acquired session"

  unknownArgs = .directory~new; unknownArgs["x"] = 1
  deniedTool = broker~prepare(.AIToolProposal~new("call-004", "shell_exec", unknownArgs))
  call no deniedTool~ok, "unknown tool denied"
  call eq "AI_TOOL_NOT_ALLOWED", deniedTool~code, "allowlist denial code"
  call eq beforeDeniedLease, registry~generation(ag2~generationId)~leaseCount, "allowlist denial acquires no session"

  unofferedCall = .AIProviderToolCall~new("call-004b", "shell_exec", unknownArgs)
  unoffered = broker~prepareOffered(offered2, unofferedCall)
  call no unoffered~ok, "provider cannot call a tool absent from its stamped offer"
  call eq "AI_TOOL_NOT_OFFERED", unoffered~code, "not-offered denial code"
  call eq beforeDeniedLease, registry~generation(ag2~generationId)~leaseCount, "not-offered denial acquires no session"

  cancelArgs = .directory~new; cancelArgs["a"] = 1; cancelArgs["b"] = 1; cancelArgs["marker"] = "CANCEL-MARKER"; cancelArgs["meta"] = .directory~new
  cancelPrepared = broker~prepare(.AIToolProposal~new("call-005", "add_numbers", cancelArgs)); call ok cancelPrepared, "prepare cancellable ticket"
  cancelTicket = cancelPrepared~value
  call eq beforeDeniedLease + 1, registry~generation(ag2~generationId)~leaseCount, "cancel ticket holds session"
  call yes cancelTicket~cancel, "cancel releases unexecuted ticket"
  call eq "CANCELLED", cancelTicket~state, "cancel ticket state"
  call eq beforeDeniedLease, registry~generation(ag2~generationId)~leaseCount, "cancel released held session"
  call no cancelTicket~cancel, "second cancel refused"
  cancelledDispatch = broker~execute(cancelTicket)
  call no cancelledDispatch~ok, "cancelled ticket cannot execute"
  call eq "AI_TOOL_TICKET_CONSUMED", cancelledDispatch~code, "cancelled dispatch code"

  evidence = .AlchemyCanonical~encode(broker~instrumentationEvents)
  call yes evidence~pos("AI.TOOL.OFFER") > 0, "offer instrumentation present"
  call yes evidence~pos("AI.TOOL.PREPARE") > 0, "prepare instrumentation present"
  call yes evidence~pos("AI.TOOL.EXECUTE") > 0, "execute instrumentation present"
  call eq 0, evidence~pos("SECRET-TOOL-ARG-DO-NOT-LOG"), "tool argument content excluded from instrumentation"
  call eq 0, evidence~pos("mutated-after-proposal"), "nested tool argument content excluded from instrumentation"
  call eq 0, evidence~pos("MODEL-SCHEMA-DO-NOT-INSTRUMENT"), "offered schema contents excluded from instrumentation"
  call eq 0, evidence~pos("STALE-OFFER-ARG"), "stale provider call arguments excluded from instrumentation"

  say "  pinned_generation=" || ag1~generationId
  say "  current_generation=" || ag2~generationId
  say "  broker_events=" || broker~instrumentationEvents~items
  say "AI TOOL BROKER V0.4 CORE: OK"
  return

proposalClassIsAlchemy:
  procedure
  d = .directory~new
  p = .AIToolProposal~new("surface-probe", "add_numbers", d)
  return p~isa(.AlchemyObject)

profile:
  procedure
  use arg artifactId, revision
  bindings = .array~of(.AbilityRuntimeBinding~new("tool", "tool.capability", artifactId))
  inputSchema = schemaValue('{"type":"object","description":"MODEL-SCHEMA-DO-NOT-INSTRUMENT","required":["a","b"],"properties":{"a":{"type":"integer"},"b":{"type":"integer"},"marker":{"type":"string"},"meta":{"type":"object"}},"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["sum","generation","invocation_count"],"properties":{"sum":{"type":"integer"},"generation":{"type":"string"},"invocation_count":{"type":"integer"}},"additionalProperties":false}')
  abilities = .array~of(.AbilityDescriptor~new("math.add", "CUSTOM", .array~of("tool"), .true, "integer addition tool", inputSchema, outputSchema))
  return .AbilityProfileRevision~new("ai-tool-profile", revision, "ai-tool-client", bindings, abilities, .array~new, .array~new, "AI tool broker fixture")

schemaValue:
  procedure
  use arg text
  parsed = .AbilityJsonSchema~fromJson(text)
  call ok parsed, "parse tool schema"
  return parsed~value

stage:
  procedure
  use arg kernel, verifier, path, moduleId, artifactId, version
  sourceOutcome = .RuntimeSourceLoader~readFile(path); call ok sourceOutcome, "read tool fixture"
  call ok verifier~pin(artifactId, sourceOutcome~value), "pin tool fixture"
  artifact = .RuntimeArtifact~new(moduleId, "CAPABILITY", version, artifactId, "ToolCapability", sourceOutcome~value)
  stageOutcome = kernel~stage("prod", artifact); call ok stageOutcome, "stage tool fixture"
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

::requires "AIToolBroker.cls"
::requires "RuntimeRegistry.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityApiDescription.cls"
::requires "AbilityHttpServer.cls"
::requires "AlchemyEvidence.cls"
::requires "json.cls"
