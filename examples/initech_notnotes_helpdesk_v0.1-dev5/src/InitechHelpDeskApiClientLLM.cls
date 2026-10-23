/* InitechHelpDeskApiClientLLM.cls
 * Provider-neutral complete(prompt) bridge. HTTP/TLS remains owned by the
 * existing ooRexx API Client. The help desk only shapes the Responses request.
 */
::class InitechHelpDeskApiClientLLM public
::attribute requestCount get

::method init
  expose client endpoint deployment apiKey requestClass requestCount maxOutputTokens
  use strict arg clientArg, endpointArg, deploymentArg, apiKeyArg="", requestClassArg=.nil, maxOutputTokensArg=768
  if clientArg == .nil then raise syntax 88.900 array("API Client object is required")
  client = clientArg
  endpoint = endpointArg~string~strip("T", "/")
  deployment = deploymentArg~string
  apiKey = apiKeyArg~string
  requestClass = requestClassArg
  if requestClass == .nil then requestClass = .environment~at("APIREQUEST")
  requestCount = 0
  maxOutputTokens = maxOutputTokensArg

::method complete
  expose client endpoint deployment apiKey requestClass requestCount maxOutputTokens
  use strict arg prompt
  if requestClass == .nil then raise syntax 88.900 array("ApiRequest public class is not loaded; load ooRexx API Client v0.4.1")
  requestCount += 1
  headers = .directory~new
  headers["Content-Type"] = "application/json"
  if apiKey <> "" then headers["api-key"] = apiKey
  headers["User-Agent"] = "ooRexx-Initech-NotNotes-HelpDesk/0.1"
  payload = .directory~new
  payload["model"] = deployment
  payload["input"] = prompt
  payload["max_output_tokens"] = maxOutputTokens
  payload["store"] = .false
  metadata = .directory~new
  metadata["component"] = "initech.notnotes.helpdesk"
  metadata["provider"] = "api-client-responses"
  metadata["schema"] = "initech.helpdesk.llm.request/0.1"
  requestId = "initech-helpdesk-" || requestCount || "-" || date("S") || "-" || time("S")
  request = requestClass~new(requestId, "POST", endpoint || "/openai/v1/responses", headers, -
      .json~toJson(payload), "API_CONTROL", 50, 2000000, 2000000, "", metadata, .nil, "")
  response = client~execute(request)
  if response~status < 200 | response~status >= 300 then -
    raise syntax 88.900 array("LLM API request failed status=" || response~status || " transport=" || response~errorCode)
  return self~responseText(response~body)

::method responseText private
  use strict arg body
  root = .json~fromJson(body)
  if root == .nil then raise syntax 88.900 array("LLM response is not JSON")
  if root~hasIndex("output_text") then return root["output_text"]~string
  if root~hasIndex("output") then do item over root["output"]
    if item~hasIndex("content") then do part over item["content"]
      if part~hasIndex("text") then return part["text"]~string
    end
  end
  raise syntax 88.900 array("LLM response contains no output text")

::requires "json.cls"
