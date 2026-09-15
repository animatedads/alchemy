oldKey = value("XAI_API_KEY",, "ENVIRONMENT")
call value "XAI_API_KEY", "acceptance-dummy-key", "ENVIRONMENT"

c = .GrokAPIClient~new("grok-test", "http://127.0.0.1:1/chat/completions", 1)
d = c~decide("test prompt")

call value "XAI_API_KEY", oldKey, "ENVIRONMENT"

if d \== .nil then raise syntax 93.900 array("closed endpoint unexpectedly returned a Grok decision")
if c~attempts \= 3 then raise syntax 93.900 array("Grok transport failure did not retry three times")
if c~lastHttp \= "000" then raise syntax 93.900 array("Grok transport status should be 000")
if c~lastError~caselessPos("transport rc=") = 0 then raise syntax 93.900 array("Grok lastError lacks transport rc")
if c~lastError~caselessPos("stderr=") = 0 then raise syntax 93.900 array("Grok lastError lacks captured stderr")

say "PASS Grok API retry count and transport diagnostics"
exit 0
::requires "ai_grok.cls"
