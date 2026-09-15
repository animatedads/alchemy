::class OrchestratorModelProvider subclass AIProviderAdapterBase public
::method completeRequest protected
  use arg request
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if request~hasMethod("BROKER") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "broker")
  if request~hasMethod("ABILITYID") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "ability-id")
  prompt = request~prompt
  inputTokens = 1
  if prompt~strip = "" then inputTokens = 0

  if request~messageCount > 0 then do
    firstMessage = request~messages~at(1)
    lastMessage = request~messages~at(request~messageCount)
    if lastMessage~role \= "tool" then return .AIProviderReply~failure("AI_PROVIDER_CONTINUATION_INVALID", "continuation must end with tool result", .AIProviderUsage~new(0, 0), request~model)
    if firstMessage~content = "tool-loop" then do
      argsLoop = .directory~new; argsLoop["a"] = 1; argsLoop["b"] = 1; argsLoop["meta"] = .directory~new
      loopCall = .AIProviderToolCall~new("orch-call-loop-2", "add_numbers", argsLoop)
      return .AIProviderReply~success("", request~model, "tool_calls", .AIProviderUsage~new(3, 1), .array~of(loopCall))
    end
    parsedResult = .JSON~fromJSON(lastMessage~content)
    if \parsedResult~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_CONTINUATION_INVALID", "tool result must decode to object", .AIProviderUsage~new(0, 0), request~model)
    continuationText = "ORCH-CONTINUED:" || parsedResult~at("sum") || ":" || parsedResult~at("generation")
    return .AIProviderReply~success(continuationText, request~model, "stop", .AIProviderUsage~new(3, 2))
  end

  toolPrompt = prompt = "tool-one"
  if \toolPrompt then toolPrompt = prompt = "tool-loop"
  if toolPrompt then do
    offered = .false
    do definition over request~toolDefinitions
      if definition~name = "add_numbers" then offered = .true
    end
    if \offered then return .AIProviderReply~failure("AI_PROVIDER_TOOL_NOT_OFFERED", "add_numbers not offered", .AIProviderUsage~new(inputTokens, 0), request~model)
    args = .directory~new
    args["a"] = 20
    args["b"] = 22
    args["marker"] = "ORCHESTRATOR-SECRET-ARG"
    args["meta"] = .directory~new
    toolCall = .AIProviderToolCall~new("orch-call-001", "add_numbers", args)
    return .AIProviderReply~success("", request~model, "tool_calls", .AIProviderUsage~new(inputTokens, 1), .array~of(toolCall))
  end

  if prompt = "tool-many" then do
    args1 = .directory~new; args1["a"] = 1; args1["b"] = 2; args1["meta"] = .directory~new
    args2 = .directory~new; args2["a"] = 3; args2["b"] = 4; args2["meta"] = .directory~new
    call1 = .AIProviderToolCall~new("orch-call-many-1", "add_numbers", args1)
    call2 = .AIProviderToolCall~new("orch-call-many-2", "add_numbers", args2)
    return .AIProviderReply~success("", request~model, "tool_calls", .AIProviderUsage~new(inputTokens, 2), .array~of(call1, call2))
  end

  return .AIProviderReply~success("ORCH:" || prompt, request~model, "stop", .AIProviderUsage~new(inputTokens, 1))

::class OrchestratorModelModule subclass AIProviderRuntimeCapability public
::method createProvider protected
  return .OrchestratorModelProvider~new

::requires "AIProviderAccess.cls"
