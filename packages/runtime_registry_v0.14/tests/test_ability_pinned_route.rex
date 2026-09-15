root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "ABILITY PINNED ROUTE V0.1 START"
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  data1 = stage(kernel, verifier, root || "/fixtures/modules/HttpData_v1.cls", "http.data", "http:data:pinned:v1", "1.0.0")
  data2 = stage(kernel, verifier, root || "/fixtures/modules/HttpData_v2.cls", "http.data", "http:data:pinned:v2", "2.0.0")
  call ok kernel~activate("prod", "http.data", data1~generationId), "activate data v1"

  registry = .AbilityRegistry~new(kernel)
  p1 = profile(data1~artifactId, "1")
  staged1 = registry~stage("prod", p1); call ok staged1, "stage profile v1"; ag1 = staged1~value
  call ok registry~activate("prod", "tool-client", ag1~generationId), "activate profile v1"

  keys = .AbilityCredentialStore~new
  call ok keys~register("tool", "secret", "prod", "tool-client"), "register normal route credential"
  router = .AbilityHttpRouter~new(registry, keys, .AbilityResultStore~new(300, 20))

  heldOutcome = registry~acquire("prod", "tool-client"); call ok heldOutcome, "acquire pinned session"; held = heldOutcome~value
  call eq ag1~generationId, held~generationId, "held session pins profile v1"

  call ok kernel~activate("prod", "http.data", data2~generationId), "activate data v2"
  p2 = profile(data2~artifactId, "2")
  staged2 = registry~stage("prod", p2); call ok staged2, "stage profile v2"; ag2 = staged2~value
  call ok registry~activate("prod", "tool-client", ag2~generationId), "activate profile v2"

  request = makeRequest("echo.custom", '{"message":"tool call"}', .false)
  pinned = router~routePinnedAbility(held, "echo.custom", request)
  call eq 200, pinned~status, "pinned dynamic ability succeeds"
  pj = .JSON~fromJSON(pinned~body)
  call eq "DATA-ONE", pj~at("result")~at("generation"), "pinned dispatch uses old runtime generation"
  call eq ag1~generationId, pj~at("ability_generation"), "pinned response reports held Ability generation"

  normalRequest = makeRequest("echo.custom", '{"message":"tool call"}', .true)
  normal = router~route(normalRequest)
  call eq 200, normal~status, "normal route succeeds after activation"
  nj = .JSON~fromJSON(normal~body)
  call eq "DATA-TWO", nj~at("result")~at("generation"), "normal route uses new runtime generation"
  call eq ag2~generationId, nj~at("ability_generation"), "normal route reports current Ability generation"

  materialized = router~routePinnedAbility(held, "query", makeRequest("query", '{"q":"x"}', .false))
  call eq 409, materialized~status, "pinned route rejects query materialization alias"
  mismatch = router~routePinnedAbility(held, "echo.custom", makeRequest("other.tool", '{"message":"x"}', .false))
  call eq 409, mismatch~status, "pinned route rejects path/ability mismatch"

  call ok held~release, "release pinned session"
  released = router~routePinnedAbility(held, "echo.custom", request)
  call eq 409, released~status, "released pinned session rejected"

  say "  pinned_generation=" || ag1~generationId
  say "  current_generation=" || ag2~generationId
  say "ABILITY PINNED ROUTE V0.1: OK"
  return

profile:
  procedure
  use arg artifactId, revision
  runtimeBindings = .array~of(.AbilityRuntimeBinding~new("data", "http.data", artifactId))
  inputSchema = schemaValue('{"type":"object","required":["message"],"properties":{"message":{"type":"string","minLength":1}} ,"additionalProperties":false}')
  outputSchema = schemaValue('{"type":"object","required":["echo","generation"],"properties":{"echo":{"type":"string"},"generation":{"type":"string"},"invocation_count":{"type":"integer"},"rules_visible":{"type":"boolean"}},"additionalProperties":true}')
  abilities = .array~of(.AbilityDescriptor~new("echo.custom", "CUSTOM", .array~of("data"), .true, "pinned dynamic tool fixture", inputSchema, outputSchema))
  dataBindings = .array~of(.AbilityDataBinding~new("orders", "data", "customer_orders", "READ"))
  return .AbilityProfileRevision~new("pinned-tool-profile", revision, "tool-client", runtimeBindings, abilities, dataBindings, .array~new, "pinned tool route profile")

schemaValue:
  procedure
  use arg text
  parsed = .AbilityJsonSchema~fromJson(text)
  call ok parsed, "parse fixture schema"
  return parsed~value

stage:
  procedure
  use arg kernel, verifier, path, moduleId, artifactId, version
  sourceResult = .RuntimeSourceLoader~readFile(path); call ok sourceResult, "read fixture source"
  call ok verifier~pin(artifactId, sourceResult~value), "pin fixture source"
  artifact = .RuntimeArtifact~new(moduleId, "CAPABILITY", version, artifactId, "HttpDataCapability", sourceResult~value)
  staged = kernel~stage("prod", artifact); call ok staged, "stage fixture runtime"
  return staged~value

makeRequest:
  procedure
  use arg abilityId, bodyText, withAuth
  headers = .directory~new
  headers["content-type"] = "application/json"
  headers["content-length"] = bodyText~length
  if withAuth then headers["authorization"] = "Bearer ab1.tool.secret"
  return .AbilityHttpRequest~new("POST", "/v1/abilities/" || abilityId, "HTTP/1.1", headers, bodyText)

ok:
  use arg outcome, label
  if outcome == .nil then do; say "FAILED:" label "nil"; exit 81; end
  if \outcome~ok then do; say "FAILED:" label outcome~code outcome~detail; exit 81; end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 82
  end
  return

::requires "RuntimeRegistry.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityApiDescription.cls"
::requires "AbilityHttpServer.cls"
::requires "json.cls"
