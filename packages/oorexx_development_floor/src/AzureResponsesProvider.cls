/* AzureResponsesProvider.cls
   Azure OpenAI v1 Responses adapter for Development Floor.

   The worker sees the normal AIProviderRequest/Reply boundary. Azure-specific
   endpoint shape and Responses JSON remain below that boundary. Credential
   material stays behind Secret Broker + OpenAICompatCurlTransport.
*/

::class DFAzureResponsesBuild public
::constant API_VERSION "development.floor.azure-responses/0.1"

::class DFAzureResponsesProviderConfig public
::method fromEnvironment class
  base = value("AZURE_OPENAI_ENDPOINT",, "ENVIRONMENT")~strip
  credentialRef = value("AZURE_OPENAI_CREDENTIAL_REFERENCE",, "ENVIRONMENT")~strip
  models = value("AZURE_OPENAI_MODELS",, "ENVIRONMENT")
  timeoutText = value("AZURE_OPENAI_TIMEOUT",, "ENVIRONMENT")
  maxOutput = value("AZURE_OPENAI_MAX_OUTPUT",, "ENVIRONMENT")
  if base = "" then raise syntax 88.900 array("AZURE_OPENAI_ENDPOINT required")
  if credentialRef = "" then credentialRef = "azure.openai.primary"
  if timeoutText = "" then timeoutText = 60
  if maxOutput = "" then maxOutput = 20000
  if base~right(1) = "/" then base = base~left(base~length - 1)
  if base~lower~right(20) = "/openai/v1/responses" then endpoint = base
  else endpoint = base || "/openai/v1/responses"
  modelList = .OpenAICompatModelPolicy~parseModels(models)
  if modelList~items = 0 then raise syntax 88.900 array("AZURE_OPENAI_MODELS required")
  return .OpenAICompatProviderConfig~new(endpoint, credentialRef, modelList, timeoutText, .false, maxOutput, "API_KEY", "api-key")

::class DFAzureResponsesProviderAdapter subclass AIProviderAdapterBase public
::method init
  expose providerConfig secretBroker httpTransport journal traceSequence lastReasoningSummary
  use strict arg configArg, brokerArg, transportArg, journalArg=.nil
  if configArg == .nil then raise syntax 88.900 array("Azure Responses provider requires config")
  if brokerArg == .nil then raise syntax 88.900 array("Azure Responses provider requires Secret Broker")
  if transportArg == .nil then raise syntax 88.900 array("Azure Responses provider requires transport")
  providerConfig = configArg
  secretBroker = brokerArg
  httpTransport = transportArg
  journal = journalArg
  traceSequence = 0
  lastReasoningSummary = ""
  self~init:super

::method completeRequest protected
  expose providerConfig secretBroker httpTransport journal traceSequence lastReasoningSummary
  use strict arg request
  lastReasoningSummary = ""
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if \providerConfig~allowsModel(request~model) then return .AIProviderReply~failure("AI_PROVIDER_MODEL_NOT_ALLOWED", "requested model is not enabled", .AIProviderUsage~new(0, 0), request~model)
  if request~maxOutputTokens > providerConfig~maxOutputTokensLimit then return .AIProviderReply~failure("AI_PROVIDER_OUTPUT_LIMIT", "requested output token limit exceeds policy", .AIProviderUsage~new(0, 0), request~model)
  if request~messageCount > 0 then return .AIProviderReply~failure("AI_PROVIDER_FEATURE_UNSUPPORTED", "Azure Responses adapter v0.1 accepts prompt requests only", .AIProviderUsage~new(0, 0), request~model)
  if request~toolDefinitionCount > 0 then return .AIProviderReply~failure("AI_PROVIDER_FEATURE_UNSUPPORTED", "Azure Responses adapter v0.1 does not project tools yet", .AIProviderUsage~new(0, 0), request~model)

  bodyObject = .directory~new
  bodyObject["model"] = request~model
  bodyObject["input"] = request~prompt
  bodyObject["max_output_tokens"] = request~maxOutputTokens
  reasoningObject = .Directory~new
  reasoningObject["effort"] = self~reasoningEffort
  reasoningObject["summary"] = self~reasoningSummaryMode
  bodyObject["reasoning"] = reasoningObject
  bodyJson = .JSON~toJSON(bodyObject)
  traceSequence += 1
  traceId = traceSequence~format(4, 0)
  if journal \== .nil then ignore = journal~persist("PROVIDER", "RAW_REQUEST", "provider/" || traceId || ".request.json", bodyJson, "azure-responses")

  secretOutcome = secretBroker~acquire(providerConfig~credentialReference)
  if \secretOutcome~ok then return .AIProviderReply~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "Azure credential unavailable", .AIProviderUsage~new(0, 0), request~model)
  lease = secretOutcome~value
  signal on syntax name postRaised
  postOutcome = httpTransport~postJson(providerConfig~endpoint, bodyJson, lease, providerConfig~timeoutSeconds)
  signal off syntax
  lease~retire

  if journal \== .nil then ignore = journal~persist("PROVIDER", "RAW_RESPONSE", "provider/" || traceId || ".response.json", postOutcome~body, "status=" || postOutcome~status)
  if \postOutcome~ok then return .AIProviderReply~failure(postOutcome~code, postOutcome~detail, .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 401 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "Azure rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 403 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "Azure rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 429 then return .AIProviderReply~failure("AI_PROVIDER_RATE_LIMITED", "Azure rate limit reached", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status < 200 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "Azure returned non-success status", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status >= 300 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "Azure returned non-success status", .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name responseInvalid
  responseObject = .JSON~fromJSON(postOutcome~body)
  if \responseObject~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "Azure response must be object", .AIProviderUsage~new(0, 0), request~model)
  lastReasoningSummary = self~extractReasoningSummary(responseObject)
  text = self~extractText(responseObject)
  if text == .nil then do
    responseStatus = self~stringValue(responseObject["status"])
    incompleteReason = self~incompleteReason(responseObject)
    if translate(responseStatus) = "INCOMPLETE" then do
      if translate(incompleteReason) = "MAX_OUTPUT_TOKENS" then return .AIProviderReply~failure("AI_PROVIDER_OUTPUT_LIMIT", "Azure response incomplete: max_output_tokens", self~usageFrom(responseObject), request~model)
      return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INCOMPLETE", "Azure response incomplete: " || incompleteReason, self~usageFrom(responseObject), request~model)
    end
    return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "Azure response output text missing status=" || responseStatus || " output=" || self~outputShape(responseObject), self~usageFrom(responseObject), request~model)
  end

  inputTokens = 0
  outputTokens = 0
  usageObject = responseObject["usage"]
  if usageObject \== .nil then do
    if usageObject~isa(.Directory) then do
      inputValue = usageObject["input_tokens"]
      outputValue = usageObject["output_tokens"]
      if inputValue \== .nil then if datatype(inputValue~string, "W") then inputTokens = inputValue~string
      if outputValue \== .nil then if datatype(outputValue~string, "W") then outputTokens = outputValue~string
    end
  end
  responseModel = request~model
  modelValue = responseObject["model"]
  if modelValue \== .nil then responseModel = modelValue~string
  finishReason = "completed"
  statusValue = responseObject["status"]
  if statusValue \== .nil then finishReason = statusValue~string
  signal off syntax
  return .AIProviderReply~success(text, responseModel, finishReason, .AIProviderUsage~new(inputTokens, outputTokens))

postRaised:
  say "Azure Responses post syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  if lease \== .nil then lease~retire
  return .AIProviderReply~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "Azure transport raised a condition", .AIProviderUsage~new(0, 0), request~model)

responseInvalid:
  say "Azure Responses parse syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "Azure returned invalid JSON", .AIProviderUsage~new(0, 0), request~model)

::method lastReasoningSummary public
  expose lastReasoningSummary
  return lastReasoningSummary

::method reasoningEffort
  valueText = value("DF_LUNA_REASONING_EFFORT",, "ENVIRONMENT")~strip~lower
  if valueText = "" then valueText = "low"
  if valueText <> "minimal" then do
    if valueText <> "low" then if valueText <> "medium" then if valueText <> "high" then valueText = "low"
  end
  return valueText

::method reasoningSummaryMode
  valueText = value("DF_LUNA_REASONING_SUMMARY",, "ENVIRONMENT")~strip~lower
  if valueText = "" then valueText = "concise"
  if valueText <> "concise" then if valueText <> "auto" then valueText = "concise"
  return valueText

::method extractReasoningSummary
  use strict arg responseObject
  output = responseObject["output"]
  if output == .nil then return ""
  if \output~isa(.Array) then return ""
  answer = ""
  do item over output
    if item~isa(.Directory) then do
      kind = item["type"]
      if kind \== .nil then if kind~string = "reasoning" then do
        summaries = item["summary"]
        if summaries \== .nil then if summaries~isa(.Array) then do summaryPart over summaries
          if summaryPart~isa(.Directory) then do
            summaryText = summaryPart["text"]
            if summaryText \== .nil then do
              if answer \= "" then answer ||= "0a"x
              answer ||= summaryText~string
            end
          end
          else do
            if answer \= "" then answer ||= "0a"x
            answer ||= summaryPart~string
          end
        end
      end
    end
  end
  return answer

::method usageFrom
  use strict arg responseObject
  inputTokens = 0
  outputTokens = 0
  usageObject = responseObject["usage"]
  if usageObject \== .nil then do
    if usageObject~isa(.Directory) then do
      inputValue = usageObject["input_tokens"]
      outputValue = usageObject["output_tokens"]
      if inputValue \== .nil then if datatype(inputValue~string, "W") then inputTokens = inputValue~string
      if outputValue \== .nil then if datatype(outputValue~string, "W") then outputTokens = outputValue~string
    end
  end
  return .AIProviderUsage~new(inputTokens, outputTokens)

::method stringValue
  use strict arg valueArg
  if valueArg == .nil then return ""
  return valueArg~string

::method incompleteReason
  use strict arg responseObject
  details = responseObject["incomplete_details"]
  if details == .nil then return "unspecified"
  if \details~isa(.Directory) then return "invalid-incomplete-details"
  reason = details["reason"]
  if reason == .nil then return "unspecified"
  return reason~string

::method outputShape
  use strict arg responseObject
  output = responseObject["output"]
  if output == .nil then return "missing"
  if \output~isa(.Array) then return "not-array"
  answer = ""
  do item over output
    if item~isa(.Directory) then do
      kind = item["type"]
      if kind == .nil then kindText = "?"
      else kindText = kind~string
      if answer \= "" then answer ||= ","
      answer ||= kindText
    end
  end
  if answer = "" then answer = "empty"
  return answer

::method extractText
  use strict arg responseObject
  direct = responseObject["output_text"]
  if direct \== .nil then return direct~string
  output = responseObject["output"]
  if output == .nil then return .nil
  if \output~isa(.Array) then return .nil
  answer = ""
  found = .false
  do item over output
    if item~isa(.Directory) then do
      content = item["content"]
      if content \== .nil then do
        if content~isa(.Array) then do part over content
          if part~isa(.Directory) then do
            partType = part["type"]
            partText = part["text"]
            if partType \== .nil then do
              if partType~string = "output_text" then do
                if partText \== .nil then do
                  answer ||= partText~string
                  found = .true
                end
              end
            end
          end
        end
      end
    end
  end
  if \found then return .nil
  return answer

::requires "AutonomousCodingWorker.cls"
::requires "OpenAICompatProvider.cls"
::requires "AIProviderAccess.cls"
::requires "SecretBroker.cls"
::requires "json.cls"
