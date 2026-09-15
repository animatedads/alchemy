root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "AI ACCESS V0.6 PROVIDER CONTRACT START"

  module = .DeterministicAIProviderModule~new
  call yes module~runtimeSelfTest, "provider self-test"
  call yes module~isa(.AlchemyObject), "provider runtime capability inherits AlchemyObject"
  call yes module~checkSurfaceContract~ok, "provider runtime capability surface contract"
  call no module~hasMethod("STAGE"), "provider module has no Registry stage authority"
  call no module~hasMethod("ACTIVATE"), "provider module has no Registry activate authority"
  call no module~hasMethod("RELEASEGENERATION"), "provider module has no Registry release authority"

  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = "alpha beta gamma"
  body["max_output_tokens"] = 4
  context = .FakeAIContext~new(body, .false)
  invocation = module~runtimeInvokeAbility("model.complete", context)
  call yes invocation~ok, "direct model completion"
  reply = invocation~value
  call eq "V1:alpha beta gamma", reply~at("text"), "provider text"
  call eq "fixture-model", reply~at("model"), "provider model"
  call eq "stop", reply~at("finish_reason"), "finish reason"
  call no reply~hasIndex("usage"), "business reply has no usage accounting object"
  call no reply~hasIndex("provider_request_id"), "business reply has no raw provider request id"
  call eq 0, context~meterFacts~items, "no WLU means no metering calls"

  managed = .FakeAIContext~new(body, .true)
  invocation = module~runtimeInvokeAbility("model.complete", managed)
  call yes invocation~ok, "managed completion"
  facts = managed~meterFacts
  call eq 2, facts~items, "input and output metering facts"
  call eq "AI_INPUT_TOKEN", facts~at(1)~at("type"), "input fact type"
  call eq 3, facts~at(1)~at("quantity"), "input fact quantity"
  call eq "AI_OUTPUT_TOKEN", facts~at(2)~at("type"), "output fact type"
  call eq 2, facts~at(2)~at("quantity"), "output fact quantity"

  rejectBody = .directory~new
  rejectBody["model"] = "fixture-model"
  rejectBody["prompt"] = "reject-before"
  rejectBody["max_output_tokens"] = 4
  beforeContext = .FakeAIContext~new(rejectBody, .true)
  rejected = module~runtimeInvokeAbility("model.complete", beforeContext)
  call no rejected~ok, "pre-work rejection"
  call eq "AI_PROVIDER_REJECT_BEFORE", rejected~code, "pre-work rejection code"
  call eq 0, beforeContext~meterFacts~items, "pre-work rejection emits no facts"

  rejectBody["prompt"] = "reject-after"
  afterContext = .FakeAIContext~new(rejectBody, .true)
  rejected = module~runtimeInvokeAbility("model.complete", afterContext)
  call no rejected~ok, "post-work rejection"
  call eq "AI_PROVIDER_REJECT_AFTER", rejected~code, "post-work rejection code"
  call eq 2, afterContext~meterFacts~items, "post-work rejection preserves performed-work facts"

  provider = .DeterministicAIProvider~new
  call yes provider~isa(.AlchemyObject), "provider adapter inherits AlchemyObject"
  call yes provider~checkSurfaceContract~ok, "provider adapter surface contract"

  request = .AIProviderRequest~new("fixture-model", "safe request", 3)
  call no request~isa(.AlchemyObject), "narrow provider request does not inherit broad behavioral base"
  call yes request~hasMethod("MODEL"), "provider request exposes model"
  call yes request~hasMethod("PROMPT"), "provider request exposes prompt"
  call no request~hasMethod("BODY"), "provider request exposes no raw Ability body"
  call no request~hasMethod("MODULE"), "provider request exposes no runtime module access"
  call no request~hasMethod("METERFACT"), "provider request exposes no WLU meter"
  call no request~hasMethod("WLURESERVATIONID"), "provider request exposes no WLU reservation"
  call no request~hasMethod("SEALEDINTROSPECTION"), "provider request exposes no Alchemy introspection surface"

  raisedRequest = .AIProviderRequest~new("fixture-model", "raise-provider", 3)
  signal on syntax name expectedProviderRaise
  ignore = provider~complete(raisedRequest)
  signal off syntax
  say "FAILED: provider exception fixture did not raise"
  exit 44
expectedProviderRaise:
  signal off syntax
  providerEvidence = .AlchemyCanonical~encode(provider~instrumentationEvents)
  call eq 0, providerEvidence~pos("SECRET-PROVIDER-INTERNAL-MESSAGE"), "provider instrumentation excludes raw exception message"

  raisedBody = .directory~new
  raisedBody["model"] = "fixture-model"
  raisedBody["prompt"] = "raise-provider"
  raisedBody["max_output_tokens"] = 3
  raisedContext = .FakeAIContext~new(raisedBody, .false)
  raisedInvocation = module~runtimeInvokeAbility("model.complete", raisedContext)
  call no raisedInvocation~ok, "provider exception becomes bounded runtime failure"
  call eq "AI_PROVIDER_EXCEPTION", raisedInvocation~code, "provider exception code"
  call eq "provider raised a condition", raisedInvocation~detail, "provider exception detail is sanitised"
  moduleEvidence = .AlchemyCanonical~encode(module~instrumentationEvents)
  call eq 0, moduleEvidence~pos("SECRET-PROVIDER-INTERNAL-MESSAGE"), "runtime instrumentation excludes raw provider exception message"

  say "  invocations=" || module~runtimeInvocationCount
  say "  managed_facts=" || facts~items
  say "AI ACCESS V0.6 PROVIDER CONTRACT: OK"
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 41
  end
  return

yes:
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 42
  end
  return

no:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 43
  end
  return

::class FakeAIResult public
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

::class FakeAIContext public
::method init
  expose requestBody managed facts
  use arg bodyArg, managedArg = .false
  requestBody = bodyArg
  managed = managedArg == .true
  facts = .array~new
::method body
  expose requestBody
  return requestBody
::method wluManaged
  expose managed
  return managed
::method meterFact
  expose facts
  use arg factType, quantity = 1, source = "", dimensions = .nil
  fact = .directory~new
  fact["type"] = factType
  fact["quantity"] = quantity
  fact["source"] = source
  facts~append(fact)
  return .FakeAIResult~success(fact)
::method meterFacts
  expose facts
  return facts
::method success
  use arg value = .nil
  return .FakeAIResult~success(value)
::method failure
  use arg code, detail = ""
  return .FakeAIResult~failure(code, detail)

::requires "AIProviderAccess.cls"
::requires "DeterministicAIProvider_v1.cls"
