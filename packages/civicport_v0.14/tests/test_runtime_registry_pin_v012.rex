call test_runtime_registry_pin_v012
say "PASS test_runtime_registry_pin_v012"
exit 0

test_runtime_registry_pin_v012:
  registryRoot = value("RUNTIME_REGISTRY_ROOT",, "ENVIRONMENT")
  if registryRoot = "" then raise syntax 93.900 additional("RUNTIME_REGISTRY_ROOT is required")

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  fixture1 = stageFixture(kernel, verifier, "RuntimeCivicContractFixture_v1.cls", "civic.runtime.handler", "CAPABILITY", "0.8-fixture1", "civic:handler:fixture1", "RuntimeCivicContractFixture", "prod")
  call mustOk kernel~activate("prod", "civic.runtime.handler", fixture1~generationId), "activate fixture handler v1"

  contract = .CivicPostcodeApiContract~new
  pin1 = contract~profilePin("client-civic", "1", "civic", "civic.runtime.handler", "civic:handler:fixture1")
  profile1 = pin1~profile
  call assertEqual "client-civic/civicport-postcode@1", profile1~identity, "profile identity deterministic"
  call assertTrue profile1~canonicalText~pos("postcodes.io.postcode/0.2") > 0, "mapping generation participates in profile canonical text"
  call assertTrue profile1~canonicalText~pos("civic.postcode.lookup/0.1") > 0, "contract generation participates in profile canonical text"

  registry = .AbilityRegistry~new(kernel)
  staged1 = registry~stage("prod", profile1)
  call mustOk staged1, "stage CivicPort profile v1"
  generation1 = staged1~value
  call mustOk registry~activate("prod", "client-civic", generation1~generationId), "activate CivicPort profile v1"
  acquired1 = registry~acquire("prod", "client-civic")
  call mustOk acquired1, "acquire pinned CivicPort session v1"
  session1 = acquired1~value

  check1 = pin1~validateSession(session1)
  call mustOk check1, "CivicPort pin validates exact session v1"
  call assertEqual "civic:handler:fixture1", session1~runtimeArtifactId("civic"), "session pins handler artifact v1"
  open1 = pin1~openApi(session1)
  call mustOk open1, "generate pinned OpenAPI v1"
  api1 = open1~value
  call assertEqual "3.2.0", api1["openapi"], "Runtime Registry OpenAPI version"
  call assertTrue api1["paths"]~hasIndex("/v1/abilities/civic.postcode.lookup"), "literal CivicPort ability path published"
  operation = api1["paths"]["/v1/abilities/civic.postcode.lookup"]["post"]
  call assertEqual "civic.postcode.lookup", operation["x-oorexx-ability-id"], "OpenAPI ability id exact"
  inputSchema = operation["requestBody"]["content"]["application/json"]["schema"]
  call assertTrue inputSchema["properties"]~hasIndex("postcode"), "OpenAPI input schema exposes postcode"
  call assertTrue \inputSchema["properties"]~hasIndex("url"), "OpenAPI does not expose arbitrary URL"
  outputSchema = operation["x-oorexx-output-schema"]
  call assertEqual "civic.postcode.lookup/0.1", outputSchema["properties"]["contract_generation"]["const"], "OpenAPI pins contract generation"
  call assertEqual "postcodes.io.postcode/0.2", outputSchema["properties"]["mapping_generation"]["const"], "OpenAPI pins mapping generation"
  etag1 = pin1~etag(session1)
  call mustOk etag1, "obtain pinned ETag v1"

  fixture2 = stageFixture(kernel, verifier, "RuntimeCivicContractFixture_v2.cls", "civic.runtime.handler", "CAPABILITY", "0.8-fixture2", "civic:handler:fixture2", "RuntimeCivicContractFixture", "prod")
  call mustOk kernel~activate("prod", "civic.runtime.handler", fixture2~generationId), "activate fixture handler v2 globally"

  call assertEqual "civic:handler:fixture1", session1~runtimeArtifactId("civic"), "held v1 session remains artifact-pinned after global runtime upgrade"
  call mustOk pin1~validateSession(session1), "held v1 session remains valid against old pin"
  open1Again = pin1~openApi(session1)
  call mustOk open1Again, "held v1 OpenAPI still generated from pinned session"
  etag1Again = pin1~etag(session1)
  call mustOk etag1Again, "held v1 ETag still available"
  call assertEqual etag1~value, etag1Again~value, "held v1 ETag unchanged by global runtime upgrade"

  wrongRevisionReuse = contract~profilePin("client-civic", "1", "civic", "civic.runtime.handler", "civic:handler:fixture2")
  driftStage = registry~stage("prod", wrongRevisionReuse~profile)
  call assertTrue \driftStage~ok, "same profile revision cannot silently move to another artifact"
  call assertEqual "ABILITY_PROFILE_IDENTITY_REUSED", driftStage~code, "profile revision drift rejected"

  pin2 = contract~profilePin("client-civic", "2", "civic", "civic.runtime.handler", "civic:handler:fixture2")
  staged2 = registry~stage("prod", pin2~profile)
  call mustOk staged2, "stage CivicPort profile v2"
  generation2 = staged2~value
  call mustOk registry~activate("prod", "client-civic", generation2~generationId), "activate CivicPort profile v2"
  acquired2 = registry~acquire("prod", "client-civic")
  call mustOk acquired2, "acquire pinned CivicPort session v2"
  session2 = acquired2~value
  call mustOk pin2~validateSession(session2), "CivicPort pin validates exact session v2"
  call assertEqual "civic:handler:fixture2", session2~runtimeArtifactId("civic"), "session v2 pins handler artifact v2"
  badOldCheck = pin1~validateSession(session2)
  call assertTrue \badOldCheck~ok, "old pin refuses replacement profile session"
  call assertEqual "CIVIC_PROFILE_PIN_MISMATCH", badOldCheck~code, "old pin mismatch explicit"
  etag2 = pin2~etag(session2)
  call mustOk etag2, "obtain pinned ETag v2"
  call assertTrue etag2~value \== etag1~value, "profile generation change produces different OpenAPI ETag"

  call mustOk session2~release, "release session v2"
  call mustOk session1~release, "release session v1"
  return

stageFixture:
  procedure
  use arg kernel, verifier, path, moduleId, kind, version, artifactId, entryClass, environment
  source = .RuntimeSourceLoader~readFile(path)
  call mustOk source, "read runtime fixture " || path
  call mustOk verifier~pin(artifactId, source~value), "pin runtime fixture " || artifactId
  artifact = .RuntimeArtifact~new(moduleId, kind, version, artifactId, entryClass, source~value)
  staged = kernel~stage(environment, artifact)
  call mustOk staged, "stage runtime fixture " || artifactId
  return staged~value

mustOk:
  procedure
  use arg outcome, label
  if \outcome~ok then do
    say "FAIL:" label outcome~code outcome~detail
    raise syntax 93.900 additional(label)
  end
  return .true

::requires "TestSupport.cls"
::requires "CivicRuntime.cls"
