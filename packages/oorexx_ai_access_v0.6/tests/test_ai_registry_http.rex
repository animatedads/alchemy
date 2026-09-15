packageRoot = arg(1)
if packageRoot = "" then packageRoot = "."
call main packageRoot
exit 0

main:
  procedure
  use arg packageRoot
  say "AI ACCESS V0.6 REGISTRY HTTP START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  v1 = stageBundle(kernel, verifier, packageRoot, "v1", "ability:ai:provider:v1")
  call ok kernel~activate("prod", "ai.provider.fixture", v1~generationId), "activate provider v1"

  abilityRegistry = .AbilityRegistry~new(kernel)
  profile1 = loadProfile(packageRoot || "/fixtures/profiles/ai_provider_v1.ability")
  staged1 = abilityRegistry~stage("prod", profile1); call ok staged1, "stage profile p1"; p1 = staged1~value
  call ok abilityRegistry~activate("prod", "client-ai", p1~generationId), "activate profile p1"

  heldOutcome = abilityRegistry~acquire("prod", "client-ai"); call ok heldOutcome, "hold p1 session"; held = heldOutcome~value
  heldModule = held~module("provider")
  call yes heldModule \== .nil, "p1 provider module"
  call no heldModule~hasMethod("STAGE"), "dynamic provider has no Registry stage authority"
  call yes heldModule~hasMethod("ALCHEMYOBJECTID"), "generation-private provider module carries AlchemyObject behavior"
  call yes heldModule~hasMethod("CHECKSURFACECONTRACT"), "generation-private provider module carries Alchemy contracts"
  call yes heldModule~checkSurfaceContract~ok, "generation-private provider surface contract"
  heldClass = heldModule~class~identityHash

  credentials = .AbilityCredentialStore~new
  call ok credentials~register("ai1", "secret", "prod", "client-ai"), "register AI credential"
  router = .AbilityHttpRouter~new(abilityRegistry, credentials, .AbilityResultStore~new(300, 100))
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096,16384,32,2048), 32)
  activity = server~start("serve")
  call awaitServer server
  port = server~port
  auth = "Authorization: Bearer ab1.ai1.secret"

  response = req(port, "GET /v1/abilities HTTP/1.1", .array~of("Host: localhost", auth), "")
  call eq 200, status(response), "ability catalogue"
  abilities = json(response)~at("abilities")
  call eq 1, abilities~items, "one AI ability"
  modelAbility = abilities~at(1)
  call eq "model.complete", modelAbility~at("id"), "ability id"
  call eq "MODEL", modelAbility~at("kind"), "ability kind"
  call eq "/v1/abilities/model.complete", modelAbility~at("invoke_uri"), "exact invoke URI"
  call no modelAbility~at("wlu_admission")~value, "WLU optional without bridge"

  beforeCount = heldModule~runtimeInvocationCount
  invalidBody = '{"model":"fixture-model","prompt":"bad","max_output_tokens":129}'
  response = post(port, auth, invalidBody)
  call eq 422, status(response), "input schema rejects over-bound output request"
  call eq beforeCount, heldModule~runtimeInvocationCount, "schema rejection happens before provider execution"

  body = '{"model":"fixture-model","prompt":"hello registry","max_output_tokens":4}'
  response = post(port, auth, body)
  call eq 200, status(response), "v1 model completion"
  envelope = json(response)
  reply = envelope~at("result")
  call eq "V1:hello registry", reply~at("text"), "v1 provider result"
  call no reply~hasIndex("usage"), "business result has no usage accounting"
  call no envelope~hasIndex("execution"), "no WLU means no accounting envelope"

  badToolCount = heldModule~runtimeInvocationCount
  badToolBody = '{"model":"fixture-model","prompt":"tool-proposal","max_output_tokens":4,"tools":[{"name":"lookup.weather","description":"weather","input_schema":{"type":"object"},"ability_id":"internal.weather"}]}'
  response = post(port, auth, badToolBody)
  call eq 422, status(response), "HTTP schema rejects private Ability id in model tool definition"
  call eq badToolCount, heldModule~runtimeInvocationCount, "tool schema rejection happens before provider execution"

  toolBody = '{"model":"fixture-model","prompt":"tool-proposal","max_output_tokens":4,"tools":[{"name":"lookup.weather","description":"weather","input_schema":{"type":"object","required":["city"],"properties":{"city":{"type":"string"}},"additionalProperties":false}}]}'
  response = post(port, auth, toolBody)
  call eq 200, status(response), "v1 tool proposal"
  toolEnvelope = json(response)
  toolReply = toolEnvelope~at("result")
  toolCalls = toolReply~at("tool_calls")
  call yes toolCalls~isa(.Array), "tool proposal array"
  call eq 1, toolCalls~items, "one v1 tool proposal"
  call eq "call-fixture-1", toolCalls~at(1)~at("call_id"), "v1 tool call id"
  call eq "lookup.weather", toolCalls~at(1)~at("name"), "v1 tool name"
  call no toolCalls~at(1)~hasIndex("ability_id"), "provider proposal contains no internal Ability id"
  call no toolEnvelope~hasIndex("execution"), "tool proposal has no WLU envelope when WLU absent"

  v2 = stageBundle(kernel, verifier, packageRoot, "v2", "ability:ai:provider:v2")
  call ok kernel~activate("prod", "ai.provider.fixture", v2~generationId), "activate provider v2 globally"

  response = post(port, auth, body)
  call eq 200, status(response), "p1 remains active after runtime v2 publication"
  call eq "V1:hello registry", json(response)~at("result")~at("text"), "active p1 remains pinned to v1 runtime"

  profile2 = loadProfile(packageRoot || "/fixtures/profiles/ai_provider_v2.ability")
  staged2 = abilityRegistry~stage("prod", profile2); call ok staged2, "stage profile p2"; p2 = staged2~value
  call ok abilityRegistry~activate("prod", "client-ai", p2~generationId), "activate profile p2"

  response = post(port, auth, body)
  call eq 200, status(response), "v2 model completion"
  call eq "V2:hello registry", json(response)~at("result")~at("text"), "new request uses v2"

  response = post(port, auth, toolBody)
  call eq 200, status(response), "v2 tool proposal"
  call eq "call-fixture-2", json(response)~at("result")~at("tool_calls")~at(1)~at("call_id"), "new profile uses v2 tool proposal"

  newOutcome = abilityRegistry~acquire("prod", "client-ai"); call ok newOutcome, "acquire p2 session"; fresh = newOutcome~value
  freshModule = fresh~module("provider")
  call yes freshModule \== .nil, "p2 provider module"
  call no heldClass = freshModule~class~identityHash, "same public provider class is generation-private"

  heldBody = .directory~new
  heldBody["model"] = "fixture-model"
  heldBody["prompt"] = "held request"
  heldBody["max_output_tokens"] = 3
  heldDescriptor = held~ability("model.complete")
  heldContext = .AbilityInvocationContext~new(held, heldDescriptor, heldBody)
  heldInvocation = heldModule~runtimeInvokeAbility("model.complete", heldContext)
  call ok heldInvocation, "held p1 invocation"
  call eq "V1:held request", heldInvocation~value~at("text"), "held p1 remains v1 after p2 activation"

  p1RuntimeId = held~runtimeGenerationId("provider")
  p2RuntimeId = fresh~runtimeGenerationId("provider")
  call ok fresh~release, "release p2 session"
  call ok held~release, "release p1 session"
  call ok server~stop, "stop HTTP server"
  call awaitStopped server

  say "  port=" || port
  say "  p1_runtime=" || p1RuntimeId
  say "  p2_runtime=" || p2RuntimeId
  say "AI ACCESS V0.6 REGISTRY HTTP: OK"
  return

stageBundle:
  procedure
  use arg kernel, verifier, packageRoot, versionLabel, artifactId
  builder = .RuntimeBundleBuilder~new
  alchemyRoot = value("ALCHEMY_OBJECTS_ROOT",, "ENVIRONMENT")
  if alchemyRoot = "" then do
    say "FAILED: ALCHEMY_OBJECTS_ROOT not set"
    exit 55
  end
  call ok builder~addFile(alchemyRoot || "/src/AlchemyEvidence.cls", "AlchemyEvidence.cls"), "add Alchemy evidence base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemySecurity.cls", "AlchemySecurity.cls"), "add Alchemy security base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyLockedMethod.cls", "AlchemyLockedMethod.cls"), "add Alchemy locked-method base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyObject.cls", "AlchemyObject.cls"), "add Alchemy object base"
  call ok builder~addFile(packageRoot || "/src/AIProviderAccess.cls", "AIProviderAccess.cls"), "add AI provider core"
  call ok builder~addFile(packageRoot || "/fixtures/modules/DeterministicAIProvider_" || versionLabel || ".cls", "DeterministicAIProvider.cls"), "add provider fixture"
  built = builder~build; call ok built, "build provider bundle"
  bundle = built~value
  call ok verifier~pin(artifactId, bundle~sourceLines), "pin provider bundle"
  artifact = .RuntimeArtifact~new("ai.provider.fixture", "CAPABILITY", versionLabel || ".0.0", artifactId, "DeterministicAIProviderModule", bundle~sourceLines, .AIProviderAccessBuild~API_VERSION)
  staged = kernel~stage("prod", artifact); call ok staged, "stage provider " || versionLabel
  return staged~value

loadProfile:
  procedure
  use arg path
  loaded = .AbilityProfileLoader~readFile(path)
  call ok loaded, "load profile " || path
  return loaded~value

post:
  procedure
  use arg port, auth, requestBody
  headers = .array~of("Host: localhost", auth, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  return req(port, "POST /v1/abilities/model.complete HTTP/1.1", headers, requestBody)

awaitServer:
  procedure
  use arg server
  do i = 1 to 500 while \server~listening
    call SysSleep 0.01
  end
  call yes server~listening, "server listening"
  return

awaitStopped:
  procedure
  use arg server
  do i = 1 to 500 while server~listening
    call SysSleep 0.01
  end
  call no server~listening, "server stopped"
  return

req:
  procedure
  use arg port, line, headers, requestBody
  crlf = "0d0a"x
  text = line || crlf
  do i = 1 to headers~items
    text = text || headers~at(i) || crlf
  end
  return raw(port, text || crlf || requestBody)

raw:
  procedure
  use arg port, text
  socket = .Socket~new
  if socket~connect(.InetAddress~new("127.0.0.1", port)) < 0 then exit 90
  offset = 1
  do while offset <= text~length
    sent = socket~send(substr(text, offset))
    if sent == .nil then leave
    if sent <= 0 then leave
    offset = offset + sent
  end
  response = ""
  do forever
    chunk = socket~recv(4096)
    if chunk == .nil then leave
    if chunk == "" then leave
    response = response || chunk
  end
  socket~close
  return response

status:
  procedure
  use arg response
  p = pos("0d0a"x, response)
  if p = 0 then return -1
  return word(left(response, p - 1), 2)

body:
  procedure
  use arg response
  marker = "0d0a0d0a"x
  p = pos(marker, response)
  if p = 0 then return ""
  return substr(response, p + marker~length)

json:
  procedure
  use arg response
  return .JSON~fromJSON(body(response))

ok:
  use arg outcome, label
  if outcome == .nil then do
    say "FAILED:" label "nil outcome"
    exit 51
  end
  if \outcome~ok then do
    say "FAILED:" label outcome~code outcome~detail
    exit 51
  end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 52
  end
  return

yes:
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 53
  end
  return

no:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 54
  end
  return

::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityApiDescription.cls"
::requires "AbilityHttpServer.cls"
::requires "AIProviderAccess.cls"
::requires "json.cls"
