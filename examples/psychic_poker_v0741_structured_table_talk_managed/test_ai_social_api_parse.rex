port = random(20000, 40000)
serverScript = directory() || "/test_ai_social_api_server.py"
serverLog = "/tmp/hardworld-social-api-" || port || ".log"
cmd = 'python3 "' || serverScript || '" ' || port || ' >"' || serverLog || '" 2>&1 &'
address system cmd
call SysSleep 1

oldX = value("XAI_API_KEY",, "ENVIRONMENT")
oldG = value("GEMINI_API_KEY",, "ENVIRONMENT")
call value "XAI_API_KEY", "dummy-xai", "ENVIRONMENT"
call value "GEMINI_API_KEY", "dummy-gemini", "ENVIRONMENT"

g = .GrokAPIClient~new("grok-social-test", "http://127.0.0.1:" || port || "/xai", 5)
gd = g~decideWithTemperature("test social prompt", 0)
if gd == .nil then raise syntax 93.900 array("Grok local social response did not parse")
if gd["action"] \= "CALL" then raise syntax 93.900 array("Grok action parse mismatch")
if gd["talk"] \= "CALL_OUT" then raise syntax 93.900 array("Grok TALK parse mismatch")
if gd["talk_target"] \= "Hugo" then raise syntax 93.900 array("Grok TALK_TARGET parse mismatch")
if gd["social_evidence"] \= "E2" then raise syntax 93.900 array("Grok SOCIAL_EVIDENCE parse mismatch")

gem = .GeminiAPIClient~new("gemini-social-test", "http://127.0.0.1:" || port || "/models/", 5)
gmd = gem~decideWithTemperature("test social prompt", 0)
if gmd == .nil then raise syntax 93.900 array("Gemini local social response did not parse")
if gmd["action"] \= "RAISE" then raise syntax 93.900 array("Gemini action parse mismatch")
if gmd["amount"] \= 17 then raise syntax 93.900 array("Gemini amount parse mismatch")
if gmd["talk"] \= "NICE_HAND" then raise syntax 93.900 array("Gemini TALK parse mismatch")
if gmd["talk_target"] \= "Ada" then raise syntax 93.900 array("Gemini TALK_TARGET parse mismatch")
if gmd["social_evidence"] \= "E1" then raise syntax 93.900 array("Gemini SOCIAL_EVIDENCE parse mismatch")

call value "XAI_API_KEY", oldX, "ENVIRONMENT"
call value "GEMINI_API_KEY", oldG, "ENVIRONMENT"
call SysFileDelete serverLog
say "PASS Grok/Gemini real HTTP JSON parsing for SOCIAL_EVIDENCE and deterministic temperature path"
exit 0

::requires "poker.cls"
::requires "ai_grok.cls"
::requires "ai_gemini.cls"
