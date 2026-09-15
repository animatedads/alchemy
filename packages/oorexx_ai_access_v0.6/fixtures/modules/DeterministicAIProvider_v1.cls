::class DeterministicAIProvider subclass AIProviderAdapterBase public
::method completeRequest protected
  use arg request
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if request~hasMethod("BODY") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "body")
  if request~hasMethod("MODULE") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "module")
  if request~hasMethod("RUNTIMEGENERATIONID") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "runtime-generation")
  if request~hasMethod("METERFACT") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "wlu-meter")
  if request~hasMethod("WLURESERVATIONID") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "wlu-reservation")
  if request~hasMethod("BROKER") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "broker")
  if request~hasMethod("ABILITYID") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "ability-id")

  prompt = request~prompt
  if request~messageCount > 0 then do
    lastMessage = request~messages~at(request~messageCount)
    if lastMessage~role = "tool" then do
      usage = .AIProviderUsage~new(3, 2)
      return .AIProviderReply~success("V1:CONTINUATION:" || lastMessage~content, request~model, "stop", usage)
    end
  end
  promptText = request~prompt~strip
  if promptText = "" then inputTokens = 0
  else inputTokens = words(promptText)

  if prompt = "tool-proposal" then do
    offered = .false
    do definition over request~toolDefinitions
      if definition~name = "lookup.weather" then do
        offered = .true
        if definition~hasMethod("ABILITYID") then return .AIProviderReply~failure("AI_PROVIDER_AUTHORITY_LEAK", "tool-definition-ability-id")
        schemaCopy = definition~inputSchema
        if \schemaCopy~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_TOOL_SCHEMA_INVALID", "tool schema")
      end
    end
    if \offered then return .AIProviderReply~failure("AI_PROVIDER_TOOL_NOT_OFFERED", "lookup.weather was not offered", .AIProviderUsage~new(inputTokens, 0), request~model)
    callArgs = .directory~new
    callArgs["city"] = "SECRET-TOOL-ARGUMENT"
    call = .AIProviderToolCall~new("call-fixture-1", "lookup.weather", callArgs)
    usage = .AIProviderUsage~new(inputTokens, 1)
    return .AIProviderReply~success("", request~model, "tool_calls", usage, .array~of(call))
  end

  if prompt = "raise-provider" then raise syntax 88.900 array("SECRET-PROVIDER-INTERNAL-MESSAGE")
  if prompt = "reject-before" then return .AIProviderReply~failure("AI_PROVIDER_REJECT_BEFORE", "fixture rejection before work", .AIProviderUsage~new(0, 0), request~model)
  if prompt = "reject-after" then return .AIProviderReply~failure("AI_PROVIDER_REJECT_AFTER", "fixture rejection after work", .AIProviderUsage~new(inputTokens, 1), request~model)

  outputTokens = 2
  if request~maxOutputTokens < outputTokens then outputTokens = request~maxOutputTokens
  usage = .AIProviderUsage~new(inputTokens, outputTokens)
  return .AIProviderReply~success("V1:" || prompt, request~model, "stop", usage)

::class DeterministicAIProviderModule subclass AIProviderRuntimeCapability public
::method createProvider protected
  return .DeterministicAIProvider~new

::requires "AIProviderAccess.cls"
