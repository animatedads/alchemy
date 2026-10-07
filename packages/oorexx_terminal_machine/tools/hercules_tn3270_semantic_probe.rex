parse arg host port timeout
if host~strip="" then do
  say "usage: rexx tools/hercules_tn3270_semantic_probe.rex HOST [PORT] [TIMEOUT]"
  exit 2
end
if port~strip="" then port=3270
if timeout~strip="" then timeout=10
transport=.TcpTerminalTransport~new(host,port)
wire=.TN3270Wire~new
session=.TN3270LiveSession~new(transport,wire)
r=session~open
if \r~ok then do; say "OPEN FAIL" r~code r~detail; exit 3; end
p=session~pumpUntilGeneration(0,timeout)
if \p~ok then do; say "PUMP FAIL" p~code p~detail; ignore=session~close; exit 4; end
s=session~snapshot
if s==.nil then do; say "SNAPSHOT FAIL"; ignore=session~close; exit 5; end
say "protocol=" s~metadata["protocol"] "terminal=" s~terminalType "generation=" s~generation
say "size="s~rows||"x"||s~columns "cursor="s~cursorRow||","||s~cursorColumn "keyboard="s~keyboardState
say "layout="s~layoutFingerprint "content="s~contentDigest "fields="s~fields~items
cat=.MVS3270KnownStates~catalog
m=cat~match(s)
say "known_state_status="m~status "known_state_id="m~matchedStateId
say "--- SCREEN ---"
say s~visibleText
ignore=session~close
exit 0

::requires "TN3270LiveSession.cls"
::requires "MVS3270KnownStates.cls"
