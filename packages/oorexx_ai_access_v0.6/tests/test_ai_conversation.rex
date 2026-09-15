root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "AI ACCESS V0.6 CONVERSATION START"

  callArgs = .directory~new
  callArgs["city"] = "LONDON"
  nested = .directory~new
  nested["marker"] = "MESSAGE-SECRET-ARG"
  callArgs["meta"] = nested
  providerCall = .AIProviderToolCall~new("call-cont-1", "lookup.weather", callArgs)
  assistantMessage = .AIProviderMessage~assistant("", .array~of(providerCall))
  toolMessage = .AIProviderMessage~tool("call-cont-1", '{"temperature":21,"marker":"TOOL-RESULT-SECRET"}')
  userMessage = .AIProviderMessage~user("weather please")

  call eq "assistant", assistantMessage~role, "assistant role"
  call eq 1, assistantMessage~toolCallCount, "assistant carries one typed call"
  call eq "call-cont-1", toolMessage~toolCallId, "tool result binds provider call id"
  call no toolMessage~hasMethod("ABILITYID"), "message has no Ability authority"
  call no toolMessage~hasMethod("BROKER"), "message has no broker authority"
  call no toolMessage~hasMethod("METERFACT"), "message has no WLU authority"

  callArgs["city"] = "TAMPERED"
  nested["marker"] = "TAMPERED"
  stored = assistantMessage~toolCalls~at(1)~arguments
  call eq "LONDON", stored~at("city"), "assistant tool call arguments detached"
  call eq "MESSAGE-SECRET-ARG", stored~at("meta")~at("marker"), "nested arguments detached"

  messages = .array~of(userMessage, assistantMessage, toolMessage)
  request = .AIProviderRequest~new("fixture-model", "", 16, .array~new, messages)
  call eq 3, request~messageCount, "request carries structured messages"
  call eq 0, request~prompt~length, "structured request carries no duplicate prompt content"

  provider = .DeterministicAIProvider~new
  reply = provider~complete(request)
  call yes reply~ok, "deterministic continuation reply"
  call eq 'V1:CONTINUATION:{"temperature":21,"marker":"TOOL-RESULT-SECRET"}', reply~text, "provider receives tool-result message"
  evidence = .AlchemyCanonical~encode(provider~instrumentationEvents)
  call eq 0, evidence~pos("TOOL-RESULT-SECRET"), "provider instrumentation excludes message content"
  call eq 0, evidence~pos("MESSAGE-SECRET-ARG"), "provider instrumentation excludes historical tool arguments"
  call yes evidence~pos("message_count") > 0, "provider instrumentation records message count"

  module = .DeterministicAIProviderModule~new
  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = ""
  body["max_output_tokens"] = 16
  wireMessages = .array~new
  m1 = .directory~new; m1["role"] = "user"; m1["content"] = "weather please"; wireMessages~append(m1)
  m2 = .directory~new; m2["role"] = "assistant"; m2["content"] = ""
  wc = .directory~new; wc["call_id"] = "call-cont-1"; wc["name"] = "lookup.weather"; wc["arguments"] = providerCall~arguments
  m2["tool_calls"] = .array~of(wc); wireMessages~append(m2)
  m3 = .directory~new; m3["role"] = "tool"; m3["content"] = '{"temperature":21,"marker":"TOOL-RESULT-SECRET"}'; m3["tool_call_id"] = "call-cont-1"; wireMessages~append(m3)
  body["messages"] = wireMessages
  context = .FakeConversationContext~new(body)
  outcome = module~runtimeInvokeAbility("model.complete", context)
  call yes outcome~ok, "runtime decodes structured conversation"
  call yes outcome~value~at("text")~pos("TOOL-RESULT-SECRET") > 0, "runtime provider sees typed tool result"

  badBody = .JSON~fromJSON(.JSON~toJSON(body))
  badBody~at("messages")~at(1)["ability_id"] = "private.internal"
  badOutcome = module~runtimeInvokeAbility("model.complete", .FakeConversationContext~new(badBody))
  call no badOutcome~ok, "private field rejected from message"
  call eq "AI_REQUEST_INVALID", badOutcome~code, "private message field rejection code"

  duplicateBody = .JSON~fromJSON(.JSON~toJSON(body))
  duplicateBody["prompt"] = "duplicate context"
  duplicateOutcome = module~runtimeInvokeAbility("model.complete", .FakeConversationContext~new(duplicateBody))
  call no duplicateOutcome~ok, "prompt plus messages content rejected"
  call eq "AI_REQUEST_INVALID", duplicateOutcome~code, "duplicate context code"

  say "  messages=" || request~messageCount
  say "AI ACCESS V0.6 CONVERSATION: OK"
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

::class FakeConversationResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg; code = codeArg; detail = detailArg; value = valueArg
::method success class
  use arg value = .nil
  return self~new(.true, "OK", "", value)
::method failure class
  use arg code, detail = ""
  return self~new(.false, code, detail, .nil)

::class FakeConversationContext public
::method init
  expose requestBody
  use arg bodyArg
  requestBody = bodyArg
::method body
  expose requestBody
  return requestBody
::method wluManaged
  return .false
::method meterFact
  return .FakeConversationResult~success
::method success
  use arg value = .nil
  return .FakeConversationResult~success(value)
::method failure
  use arg code, detail = ""
  return .FakeConversationResult~failure(code, detail)

::requires "AIProviderAccess.cls"
::requires "DeterministicAIProvider_v1.cls"
::requires "json.cls"
