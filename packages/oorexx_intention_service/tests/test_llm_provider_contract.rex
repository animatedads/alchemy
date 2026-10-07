parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("POLICY", .IntentionBucketPolicy~new("FLEXIBLE", 60, 12, .true, .false))
service~feed("POLICY", "Dinner may be arranged after 18:00.", "dinner-policy.txt")
service~register("have dinner", .DemoEvent~new)
llm = .FakeLLM~new
service~registerProvider(.LLMIntentionProvider~provider(llm))
decision = service~input("food would be good")
call assertEquals "CONFIRM", decision~status, "LLM provider maps to registered intention"
call assertEquals "LLM", decision~proposal~providerName, "LLM is hidden behind common provider contract"
call assertContains llm~lastPrompt, "Dinner may be arranged after 18:00.", "bucket corpus is supplied to LLM provider"
say "PASS test_llm_provider_contract"
exit 0

assertEquals: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertContains: procedure
  use arg haystack, needle, label
  if pos(needle, haystack) > 0 then return
  say "FAIL" label
  exit 1

::class FakeLLM public
::method init
  expose lastPrompt
  lastPrompt = ""
::method complete
  expose lastPrompt
  use arg prompt
  lastPrompt = prompt
  return "INTENT=HAVE_DINNER;SCORE=91"
::attribute lastPrompt get

::class DemoEvent public
::method invoke
  use arg decision
  return "OK"

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
