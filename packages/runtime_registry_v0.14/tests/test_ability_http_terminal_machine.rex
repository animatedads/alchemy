parse arg registryRoot terminalRoot
if registryRoot = "" then registryRoot = "."
if terminalRoot = "" then do
  say "ABILITY HTTP TERMINAL MACHINE: SKIP (no Terminal Machine root)"
  exit 0
end
call main registryRoot, terminalRoot
exit 0

main:
  procedure
  use arg registryRoot, terminalRoot
  terminalVersion = detectTerminalVersion(terminalRoot)
  say "ABILITY HTTP TERMINAL MACHINE V" || terminalVersion || " START"
  call assertTrue stream(terminalRoot || "/src/TN5250Automation.cls", "c", "query exists") <> "", "Terminal Machine automation source exists"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  abilityRegistry = .AbilityRegistry~new(kernel)
  staged = stageTerminal(kernel, verifier, registryRoot, terminalRoot)
  call mustOk kernel~activate("prod", "terminal.machine", staged~generationId), "activate Terminal Machine ability"

  runtimeBindings = .array~of(.AbilityRuntimeBinding~new("terminal", "terminal.machine", staged~artifactId))
  abilities = .array~new
  abilities~append(.AbilityDescriptor~new("terminal.snapshot", "TERMINAL_READ", .array~of("terminal"), .true, "Read detached terminal snapshot"))
  abilities~append(.AbilityDescriptor~new("terminal.set-field", "TERMINAL_INPUT", .array~of("terminal"), .false, "Set an input field through safe automation"))
  abilities~append(.AbilityDescriptor~new("terminal.press", "TERMINAL_AID", .array~of("terminal"), .false, "Send an AID through safe automation"))
  profile = .AbilityProfileRevision~new("terminal-bot", "1", "client-terminal", runtimeBindings, abilities, .array~new, .array~new, "AI-safe TN5250 profile")
  profileStage = abilityRegistry~stage("prod", profile); call mustOk profileStage, "stage Terminal profile"
  profileGeneration = profileStage~value
  call mustOk abilityRegistry~activate("prod", "client-terminal", profileGeneration~generationId), "activate Terminal profile"

  credentials = .AbilityCredentialStore~new
  call mustOk credentials~register("terminal-key", "terminal-secret", "prod", "client-terminal"), "register Terminal HTTP key"
  router = .AbilityHttpRouter~new(abilityRegistry, credentials)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096, 16384, 48, 65536), 32)
  serverActivity = server~start("serve")
  do waitHttp = 1 to 500 while \server~listening
    call SysSleep 0.01
  end
  call assertTrue server~listening, "Terminal HTTP server listening"
  port = server~port
  authHeader = "Authorization: Bearer ab1.terminal-key.terminal-secret"

  snapshotResponse = postAbility(port, authHeader, "terminal.snapshot", "{}")
  call assertEq 200, httpStatus(snapshotResponse), "terminal snapshot succeeds"
  snapshotResult = httpJson(snapshotResponse)~at("result")
  call assertTrue pos("PUB400 SIGN ON", snapshotResult~at("visible_text")) > 0, "safe snapshot contains host-visible text"
  generationValue = snapshotResult~at("generation")
  call assertTrue generationValue > 0, "terminal generation present"

  userBody = '{"generation":' || generationValue || ',"field_id":"F0740","value":"FRED"}'
  userResponse = postAbility(port, authHeader, "terminal.set-field", userBody)
  call assertEq 200, httpStatus(userResponse), "visible terminal field accepted"
  call assertTrue pos("FRED", httpBody(userResponse)) > 0, "visible field may appear in safe snapshot"

  secretBody = '{"generation":' || generationValue || ',"field_id":"F0820","value":"SECRET"}'
  secretResponse = postAbility(port, authHeader, "terminal.set-field", secretBody)
  call assertEq 200, httpStatus(secretResponse), "nondisplay terminal field accepted"
  call assertEq 0, pos('"SECRET"', httpBody(secretResponse)), "secret value never echoed by HTTP capability"
  secretResult = httpJson(secretResponse)~at("result")
  call assertTrue snapshotContainsRedacted(secretResult~at("snapshot")), "nondisplay field is redacted in safe snapshot"

  pressBody = '{"generation":' || generationValue || ',"aid":"ENTER"}'
  pressResponse = postAbility(port, authHeader, "terminal.press", pressBody)
  call assertEq 200, httpStatus(pressResponse), "terminal AID accepted"
  pressResult = httpJson(pressResponse)~at("result")
  call assertTrue pressResult~at("transport_output_pending")~value, "safe receipt reports trusted transport output pending"
  call assertEq 0, pos("outbound_bytes", httpBody(pressResponse)~lower), "HTTP result has no raw wire field"
  call assertEq 0, pos('"SECRET"', httpBody(pressResponse)), "password absent from action response"

  staleBody = '{"generation":-1,"field_id":"F0740","value":"NOPE"}'
  staleResponse = postAbility(port, authHeader, "terminal.set-field", staleBody)
  call assertEq 422, httpStatus(staleResponse), "stale terminal generation rejected"

  call mustOk server~stop, "stop Terminal HTTP server"
  do waitStop = 1 to 500 while server~listening
    call SysSleep 0.01
  end
  call assertFalse server~listening, "Terminal HTTP server stopped"

  say "  generation=" || staged~generationId
  say "  profile=" || profileGeneration~generationId
  say "  terminal_generation=" || generationValue
  say "  secret_redaction=OK"
  say "ABILITY HTTP TERMINAL MACHINE V" || terminalVersion || ": OK"
  return

snapshotContainsRedacted:
  procedure
  use arg snapshotObject
  fields = snapshotObject~at("fields")
  do i = 1 to fields~items
    field = fields~at(i)
    if field~at("field_id") = "F0820" then do
      if \field~at("non_display")~value then return .false
      display = field~at("display_value")
      if display = "" then return .false
      return display~verify("*") = 0
    end
  end
  return .false

stageTerminal:
  procedure
  use arg kernel, verifier, registryRoot, terminalRoot
  builder = .RuntimeBundleBuilder~new
  call SysFileTree terminalRoot || "/src/*.cls", "sources.", "FO"
  call assertTrue sources.0 > 0, "Terminal Machine source closure discovered"
  do i = 1 to sources.0
    path = sources.i
    slash = path~lastpos("/")
    if slash = 0 then name = path
    else name = path~substr(slash + 1)
    call mustOk builder~addFile(path, name), "add Terminal source " || name
  end
  call mustOk builder~addFile(registryRoot || "/fixtures/modules/terminal_ability/RuntimeTerminalAbility.cls", "RuntimeTerminalAbility.cls"), "add Terminal ability wrapper"
  bundleResult = builder~build; call mustOk bundleResult, "build Terminal bundle"; bundle = bundleResult~value
  version = detectTerminalVersion(terminalRoot)
  artifactId = "terminal-machine:v" || version || ":ability"
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin Terminal ability"
  artifact = .RuntimeArtifact~new("terminal.machine", "CAPABILITY", version, artifactId, "RuntimeTerminalAbility", bundle~sourceLines)
  stagedResult = kernel~stage("prod", artifact); call mustOk stagedResult, "stage Terminal ability"
  return stagedResult~value

detectTerminalVersion:
  procedure
  use arg terminalRoot
  readme = .RuntimeSourceLoader~readFile(terminalRoot || "/README.md")
  if \readme~ok then return "unknown"
  lines = readme~value
  if lines~items = 0 then return "unknown"
  first = lines~at(1)
  marker = " v"
  p = pos(marker, first)
  if p = 0 then return "unknown"
  return word(substr(first, p + marker~length), 1)

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
