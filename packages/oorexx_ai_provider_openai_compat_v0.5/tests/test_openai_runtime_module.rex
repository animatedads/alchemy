root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "OPENAI COMPAT RUNTIME MODULE V0.5 START"
  secretMarker = "FAKE-OPENAI-SECRET-7E4B"
  call value "AI_OPENAI_COMPAT_ENDPOINT", "http://fixture.invalid/v1/chat/completions", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CREDENTIAL_REFERENCE", "provider.primary", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CREDENTIAL_ENV", "AI_OPENAI_COMPAT_TEST_SECRET", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_TEST_SECRET", secretMarker, "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_MODELS", "fixture-model, second-model", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_TIMEOUT", "5", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_MAX_OUTPUT", "32", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CURL", root || "/tests/fixtures/fake_curl.sh", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_ALLOW_HTTP_TEST", "1", "ENVIRONMENT"

  module = .OpenAICompatRuntimeModule~new
  call yes module~runtimeSelfTest, "runtime module self-test"
  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = "hello provider"
  body["max_output_tokens"] = 7
  context = .FakeProviderContext~new(body)
  invocation = module~runtimeInvokeAbility("model.complete", context)
  call yes invocation~ok, "runtime module completion"
  call eq "provider says hello", invocation~value["text"], "runtime projected text"
  call eq "fixture-model-actual", invocation~value["model"], "runtime projected provider model"
  call no invocation~value~hasIndex("usage"), "runtime business result excludes usage object"
  call no invocation~value~hasIndex("credential"), "runtime business result excludes credential"

  evidence = .AlchemyCanonical~encode(module~instrumentationEvents)
  call eq 0, evidence~pos(secretMarker), "runtime instrumentation excludes provider secret"
  call eq 0, evidence~pos("hello provider"), "runtime instrumentation excludes prompt"

  call value "AI_OPENAI_COMPAT_TEST_SECRET", "", "ENVIRONMENT"
  say "  invocations=" || module~runtimeInvocationCount
  say "OPENAI COMPAT RUNTIME MODULE V0.5: OK"
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 51
  end
  return

yes:
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 52
  end
  return

no:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 53
  end
  return

::class FakeProviderResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg
  detail = detailArg
  value = valueArg
::method success class
  use arg value = .nil
  return self~new(.true, "OK", "", value)
::method failure class
  use arg code, detail = ""
  return self~new(.false, code, detail, .nil)

::class FakeProviderContext public
::method init
  expose requestBody
  use arg bodyArg
  requestBody = bodyArg
::method body
  expose requestBody
  return requestBody
::method wluManaged
  return .false
::method success
  use arg value = .nil
  return .FakeProviderResult~success(value)
::method failure
  use arg code, detail = ""
  return .FakeProviderResult~failure(code, detail)

::requires "OpenAICompatProvider.cls"
