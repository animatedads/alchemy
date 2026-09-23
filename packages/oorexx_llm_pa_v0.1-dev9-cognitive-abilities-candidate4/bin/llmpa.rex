/* Codex command-line PA client. Submits asynchronously by default. */
parse arg commandLine
host = value("LLMPA_BRIDGE_HOST", , "ENVIRONMENT")
if host = "" then host = "127.0.0.1"
port = value("LLMPA_BRIDGE_PORT", , "ENVIRONMENT")
token = value("LLMPA_BRIDGE_TOKEN", , "ENVIRONMENT")
if port = "" | token = "" then do
  say '{"ok":false,"code":"LLMPA_BRIDGE_CONFIG_REQUIRED"}'
  exit 2
end
parsed = .LlmPaCliParser~parse(commandLine)
if \parsed~ok then do
  say .JSON~toJSON(errorObject(parsed~code, parsed~detail))
  exit 2
end
cmd = parsed~value
client = .LlmPaCommandClient~new(host, port, token)
if cmd["command"] = "_next" then outcome = client~nextReply
else do
  made = .LlmPaRequestFactory~create(cmd["command"], cmd["arg1"], cmd["arg2"], "codex", "LLMPA.REPLY")
  if \made~ok then outcome = made
  else outcome = client~submit(made~value)
end
if \outcome~ok then do
  say .JSON~toJSON(errorObject(outcome~code, outcome~detail))
  if outcome~code = "QUEUE_EMPTY" then exit 4
  exit 3
end
out = .directory~new
out["ok"] = .true
out["value"] = outcome~value
say .JSON~toJSON(out)
exit 0

errorObject: procedure
  use arg code, detail = ""
  d = .directory~new
  d["ok"] = .false
  d["code"] = code
  if detail \= "" then d["detail"] = detail
  return d

::requires "LlmPaCommandClient.cls"
