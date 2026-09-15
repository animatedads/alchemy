parse arg registryRoot queueRoot
if registryRoot = "" then registryRoot = "."
if queueRoot = "" then do
  say "ABILITY HTTP QUEUE FABRIC: SKIP (no Queue Fabric root)"
  exit 0
end
call main registryRoot, queueRoot
exit 0

main:
  procedure
  use arg registryRoot, queueRoot
  queuePackageVersion = detectQueueVersion(queueRoot)
  say "ABILITY HTTP QUEUE FABRIC V" || queuePackageVersion || " START"

  call assertTrue stream(queueRoot || "/src/ObjectQueueFabric.cls", "c", "query exists") <> "", "Queue Fabric core source exists"
  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  abilityRegistry = .AbilityRegistry~new(kernel)

  queue1 = stageQueue(kernel, verifier, queueRoot, "Q1")
  call mustOk kernel~activate("prod", "queue.fabric", queue1~generationId), "activate Queue Fabric Q1"
  profile1 = makeProfile("1", queue1~artifactId)
  profile1Stage = abilityRegistry~stage("prod", profile1); call mustOk profile1Stage, "stage Queue profile P1"; ability1 = profile1Stage~value
  call mustOk abilityRegistry~activate("prod", "client-queue", ability1~generationId), "activate Queue profile P1"

  credentials = .AbilityCredentialStore~new
  call mustOk credentials~register("queue-key", "queue-secret", "prod", "client-queue"), "register queue HTTP key"
  router = .AbilityHttpRouter~new(abilityRegistry, credentials)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096, 16384, 48, 65536), 32)
  serverActivity = server~start("serve")
  do waitHttp = 1 to 500 while \server~listening
    call SysSleep 0.01
  end
  call assertTrue server~listening, "queue HTTP server listening"
  port = server~port
  authHeader = "Authorization: Bearer ab1.queue-key.queue-secret"

  payloadText = '{"payload":{"kind":"ORDER","customer":"ACME","lines":[{"sku":"A1","qty":2}]}}'
  submit1 = postAbility(port, authHeader, "queue.submit", payloadText)
  call assertEq 200, httpStatus(submit1), "P1 queue submit succeeds"
  submitJson = httpJson(submit1)~at("result")
  call assertEq "Q1", submitJson~at("generation"), "P1 submit uses Q1"
  call assertEq 1, submitJson~at("depth_total"), "Q1 depth after first submit"
  call assertFalse submitJson~at("runtime_registry_attached")~value, "client queue module has no raw Runtime Registry"

  depth1 = postAbility(port, authHeader, "queue.depth", "{}")
  call assertEq 200, httpStatus(depth1), "P1 queue depth succeeds"
  depthJson = httpJson(depth1)~at("result")
  call assertEq "Q1", depthJson~at("generation"), "P1 depth uses Q1"
  call assertEq 1, depthJson~at("total"), "P1 queue depth is one"

  held1Result = abilityRegistry~acquire("prod", "client-queue"); call mustOk held1Result, "acquire held P1"; held1 = held1Result~value
  queueModule1 = held1~module("queue")
  richPayload = queueModule1~peekPayload("client-queue")
  call assertTrue richPayload~isa(.Directory), "queued JSON payload remains a Directory object"
  call assertEq "ORDER", richPayload~at("kind"), "rich queued payload kind retained"
  call assertTrue richPayload~at("lines")~isa(.Array), "nested queued payload remains Array"
  firstLine = richPayload~at("lines")~at(1)
  call assertTrue firstLine~isa(.Directory), "nested line remains Directory"
  call assertEq "A1", firstLine~at("sku"), "nested line SKU retained"
  call assertFalse queueModule1~runtimeRegistryAttached, "Q1 wrapper confirms no Runtime Registry reference"

  /* Publish Q2 globally. The active profile remains pinned to Q1. */
  queue2 = stageQueue(kernel, verifier, queueRoot, "Q2")
  call mustOk kernel~activate("prod", "queue.fabric", queue2~generationId), "activate Queue Fabric Q2 globally"
  depthStill1 = postAbility(port, authHeader, "queue.depth", "{}")
  call assertEq 200, httpStatus(depthStill1), "P1 depth after global Q2 publication"
  depthStillJson = httpJson(depthStill1)~at("result")
  call assertEq "Q1", depthStillJson~at("generation"), "active P1 remains on Q1"
  call assertEq 1, depthStillJson~at("total"), "Q1 state remains intact after global Q2 publication"

  /* P2 adopts Q2. Q2 is a separate memory-only object universe, so it starts empty. */
  profile2 = makeProfile("2", queue2~artifactId)
  profile2Stage = abilityRegistry~stage("prod", profile2); call mustOk profile2Stage, "stage Queue profile P2"; ability2 = profile2Stage~value
  call mustOk abilityRegistry~activate("prod", "client-queue", ability2~generationId), "activate Queue profile P2"
  depth2 = postAbility(port, authHeader, "queue.depth", "{}")
  call assertEq 200, httpStatus(depth2), "P2 depth succeeds"
  depth2Json = httpJson(depth2)~at("result")
  call assertEq "Q2", depth2Json~at("generation"), "P2 now uses Q2"
  call assertEq 0, depth2Json~at("total"), "new memory-only Q2 starts with independent state"

  /* Held P1 still has its exact Q1 module and rich payload after P2 publication. */
  call assertEq "Q1", queueModule1~generationLabel, "held P1 remains Q1 after P2 publication"
  heldPayload = queueModule1~peekPayload("client-queue")
  call assertEq "ACME", heldPayload~at("customer"), "held P1 payload remains reachable"

  call mustOk held1~release, "release held P1"
  call mustOk server~stop, "stop queue HTTP server"
  do waitStop = 1 to 500 while server~listening
    call SysSleep 0.01
  end
  call assertFalse server~listening, "queue HTTP server stopped"

  say "  http_port=" || port
  say "  q1=" || queue1~generationId || " state=" || queue1~state
  say "  q2=" || queue2~generationId || " state=" || queue2~state
  say "  p1=" || ability1~generationId || " state=" || ability1~state
  say "  p2=" || ability2~generationId || " state=" || ability2~state
  say "  rich_payload_class=" || richPayload~class~id
  say "  q1_depth=" || depthStillJson~at("total") || " q2_depth=" || depth2Json~at("total")
  say "ABILITY HTTP QUEUE FABRIC V" || queuePackageVersion || ": OK"
  return

makeProfile:
  procedure
  use arg revision, queueArtifactId
  runtimeBindings = .array~of(.AbilityRuntimeBinding~new("queue", "queue.fabric", queueArtifactId))
  abilities = .array~new
  abilities~append(.AbilityDescriptor~new("queue.submit", "QUEUE_SUBMIT", .array~of("queue"), .false, "Submit a work package"))
  abilities~append(.AbilityDescriptor~new("queue.depth", "QUEUE_READ", .array~of("queue"), .true, "Read queue depth"))
  dataBindings = .array~of(.AbilityDataBinding~new("work-queue", "queue", "WORK", "PUT,BROWSE"))
  return .AbilityProfileRevision~new("queue-bot", revision, "client-queue", runtimeBindings, abilities, dataBindings, .array~new, "queue ability profile")

stageQueue:
  procedure
  use arg kernel, verifier, queueRoot, label
  builder = .RuntimeBundleBuilder~new
  addResult = builder~addFile(queueRoot || "/src/ObjectQueueFabric.cls", "ObjectQueueFabric.cls")
  if \addResult~ok then do
    say "FAILED: add Queue Fabric core" addResult~code addResult~detail
    exit 90
  end
  addResult = builder~addUnit("RuntimeQueueFabricCapability.cls", queueWrapper(label))
  if \addResult~ok then do
    say "FAILED: add Queue Fabric wrapper" addResult~code addResult~detail
    exit 91
  end
  bundleResult = builder~build; call mustOk bundleResult, "build Queue Fabric bundle"; bundle = bundleResult~value
  queueVersion = detectQueueVersion(queueRoot)
  if queueVersion = "" then queueVersion = "unknown"
  artifactId = "queue-fabric:v" || queueVersion || ":ability:" || label
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin Queue Fabric " || label
  artifact = .RuntimeArtifact~new("queue.fabric", "CAPABILITY", queueVersion || "+" || label, artifactId, "RuntimeQueueFabricCapability", bundle~sourceLines)
  stageResult = kernel~stage("prod", artifact); call mustOk stageResult, "stage Queue Fabric " || label
  return stageResult~value

detectQueueVersion:
  procedure
  use arg queueRoot
  readme = .RuntimeSourceLoader~readFile(queueRoot || "/README.md")
  if \readme~ok then return ""
  lines = readme~value
  if lines~items = 0 then return ""
  first = lines~at(1)
  p = pos("v", first)
  if p = 0 then return ""
  return word(substr(first, p + 1)~strip, 1)

queueWrapper:
  procedure
  use arg label
  lines = .array~new
  lines~append("::class RuntimeQueueFabricCapability public")
  lines~append("::method generationLabel")
  lines~append('  return "' || label || '"')
  lines~append("::method runtimePrepare")
  lines~append("  expose manager")
  lines~append("  use arg context")
  lines~append('  manager = .ObjectQueueManager~new("", .nil, "queue-admin")')
  lines~append('  createResult = manager~createQueue("WORK", .QueueLifecycle~TEMPORARY, "CLIENT", 100, "queue-admin")')
  lines~append("  if \createResult~ok then return .false")
  lines~append('  grantResult = manager~grant("WORK", "client-queue", .QueueAccess~PUT, "queue-admin")')
  lines~append("  if \grantResult~ok then return .false")
  lines~append('  grantResult = manager~grant("WORK", "client-queue", .QueueAccess~BROWSE, "queue-admin")')
  lines~append("  if \grantResult~ok then return .false")
  lines~append('  grantResult = manager~grant("WORK", "client-queue", .QueueAccess~GET, "queue-admin")')
  lines~append("  if \grantResult~ok then return .false")
  lines~append("  return .true")
  lines~append("::method runtimeSelfTest")
  lines~append("  expose manager")
  lines~append("  if manager == .nil then return .false")
  lines~append("  if manager~runtimeRegistry \== .nil then return .false")
  lines~append('  depthResult = manager~depth("WORK", "client-queue")')
  lines~append("  if \depthResult~ok then return .false")
  lines~append("  if depthResult~value['total'] <> 0 then return .false")
  lines~append("  return .true")
  lines~append("::method runtimeQuiesce")
  lines~append("  return .true")
  lines~append("::method runtimeStop")
  lines~append("  expose manager")
  lines~append("  manager = .nil")
  lines~append("  return .true")
  lines~append("::method runtimeRegistryAttached")
  lines~append("  expose manager")
  lines~append("  return manager~runtimeRegistry \== .nil")
  lines~append("::method peekPayload")
  lines~append("  expose manager")
  lines~append("  use arg principal")
  lines~append('  browseResult = manager~browse("WORK", principal)')
  lines~append("  if \browseResult~ok then return .nil")
  lines~append("  return browseResult~value~payload")
  lines~append("::method runtimeInvokeAbility")
  lines~append("  expose manager")
  lines~append("  use arg abilityId, context")
  lines~append("  body = context~body")
  lines~append("  queueBinding = context~dataBinding('work-queue')")
  lines~append("  if queueBinding == .nil then return context~failure('QUEUE_BINDING_REQUIRED', 'work-queue')")
  lines~append("  queueName = queueBinding~resourceName")
  lines~append("  select")
  lines~append('    when abilityId = "queue.submit" then do')
  lines~append('      payload = body~at("payload")')
  lines~append("      if payload == .nil then return context~failure('PAYLOAD_REQUIRED', 'payload')")
  lines~append("      options = .table~new")
  lines~append('      priority = body~at("priority")')
  lines~append('      if priority \== .nil then options["priority"] = priority')
  lines~append('      putResult = manager~put(queueName, payload, options, context~clientId)')
  lines~append("      if \putResult~ok then return context~failure(putResult~code, putResult~detail)")
  lines~append('      depthResult = manager~depth(queueName, context~clientId)')
  lines~append("      if \depthResult~ok then return context~failure(depthResult~code, depthResult~detail)")
  lines~append("      responseData = .directory~new")
  lines~append("      responseData['generation'] = self~generationLabel")
  lines~append("      responseData['package_id'] = putResult~value~packageId")
  lines~append("      responseData['payload_class'] = putResult~value~payloadClass")
  lines~append("      responseData['depth_total'] = depthResult~value['total']")
  lines~append("      responseData['runtime_registry_attached'] = context~boolean(self~runtimeRegistryAttached)")
  lines~append("      return context~success(responseData)")
  lines~append("    end")
  lines~append('    when abilityId = "queue.depth" then do')
  lines~append('      depthResult = manager~depth(queueName, context~clientId)')
  lines~append("      if \depthResult~ok then return context~failure(depthResult~code, depthResult~detail)")
  lines~append("      responseData = .directory~new")
  lines~append("      responseData['generation'] = self~generationLabel")
  lines~append("      responseData['ready'] = depthResult~value['ready']")
  lines~append("      responseData['inflight'] = depthResult~value['inflight']")
  lines~append("      responseData['total'] = depthResult~value['total']")
  lines~append("      responseData['runtime_registry_attached'] = context~boolean(self~runtimeRegistryAttached)")
  lines~append("      return context~success(responseData)")
  lines~append("    end")
  lines~append("    otherwise return context~failure('ABILITY_UNKNOWN', abilityId)")
  lines~append("  end")
  return lines

postAbility:
  procedure
  use arg port, authHeader, abilityId, bodyText
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || bodyText~length)
  return httpRequest(port, "POST /v1/abilities/" || abilityId || " HTTP/1.1", headers, bodyText)

httpRequest:
  procedure
  use arg port, requestLine, headers, bodyText
  crlf = "0d0a"x
  requestText = requestLine || crlf
  do i = 1 to headers~items
    requestText = requestText || headers~at(i) || crlf
  end
  requestText = requestText || crlf || bodyText
  socket = .Socket~new
  if socket~connect(.InetAddress~new("127.0.0.1", port)) < 0 then do
    say "FAILED: HTTP client connect" socket~errno
    exit 92
  end
  offset = 1
  do while offset <= requestText~length
    sent = socket~send(substr(requestText, offset))
    if sent == .nil then leave
    if sent <= 0 then leave
    offset = offset + sent
  end
  responseText = ""
  do forever
    chunk = socket~recv(4096)
    if chunk == .nil then leave
    if chunk == "" then leave
    responseText = responseText || chunk
  end
  socket~close
  return responseText

httpStatus:
  procedure
  use arg responseText
  eol = pos("0d0a"x, responseText)
  if eol = 0 then return -1
  return word(left(responseText, eol - 1), 2)

httpBody:
  procedure
  use arg responseText
  marker = "0d0a0d0a"x
  markerPos = pos(marker, responseText)
  if markerPos = 0 then return ""
  return substr(responseText, markerPos + marker~length)

httpJson:
  procedure
  use arg responseText
  return .JSON~fromJSON(httpBody(responseText))

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label "expected=" expected "actual=" actual
    exit 93
  end
  return

assertTrue:
  procedure
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 94
  end
  return

assertFalse:
  procedure
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 95
  end
  return

mustOk:
  procedure
  use arg operationResult, label
  if \operationResult~ok then do
    say "FAILED:" label operationResult~code operationResult~detail
    exit 96
  end
  return

::requires "AbilityHttpServer.cls"
::requires "RuntimeBundleBuilder.cls"
