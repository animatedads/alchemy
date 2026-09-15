/* FlyLo's Grok-facing customer-assistance boundary.
   Grok authored the provider object used here; FlyLo adds strict xAI JSON-schema
   structured outputs and keeps airline/legal/transaction authority outside the model. */
::class FlyLoGrokAssistant public
::method init
  expose provider model maxOutput
  use arg providerArg, modelArg = "grok-4.3", maxOutputArg = 700
  if providerArg == .nil then raise syntax 88.900 array("FLYLO_GROK_PROVIDER_REQUIRED")
  provider = providerArg
  model = modelArg~string~strip
  maxOutput = maxOutputArg
  if model = "" then raise syntax 88.900 array("FLYLO_GROK_MODEL_REQUIRED")
  if \datatype(maxOutput, "W") then raise syntax 88.900 array("FLYLO_GROK_MAX_OUTPUT_INVALID")
  if maxOutput < 1 | maxOutput > 8192 then raise syntax 88.900 array("FLYLO_GROK_MAX_OUTPUT_INVALID")

::method fromEnvironment class
  model = value("FLYLO_GROK_MODEL",, "ENVIRONMENT")
  if model = "" then model = "grok-4.3"
  maxOutput = value("FLYLO_GROK_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOutput = "" then maxOutput = 700
  return self~new(.FlyLoGrokStructuredProvider~fromEnvironment, model, maxOutput)

::method explain
  expose provider model maxOutput
  use arg question, operationalEvidence, legalEvidence
  return self~assist(question, operationalEvidence, legalEvidence, "")

::method assist
  expose provider model maxOutput
  use arg question, operationalEvidence, legalEvidence, conversationEvidence = ""
  questionText = self~bounded(question, 4000)
  operationalText = self~bounded(operationalEvidence, 12000)
  legalText = self~bounded(legalEvidence, 8000)
  conversationText = self~bounded(conversationEvidence, 12000)
  prompt = "FLYLO CUSTOMER ASSISTANT" || '0a'x
  prompt ||= "You are FlyLo's helpful customer-facing airline assistant." || '0a'x
  prompt ||= "Be concise, friendly and practical. Explain authoritative results supplied below; never create airline facts or legal entitlements." || '0a'x
  prompt ||= "Never claim a booking change, payment, cancellation, rebooking, refund or compensation unless a transactional FlyLo authority reports it." || '0a'x
  prompt ||= "Do not ask for full card numbers, passwords or authentication secrets." || '0a'x || '0a'x
  prompt ||= "OPERATIONAL EVIDENCE:" || '0a'x || operationalText || '0a'x || '0a'x
  prompt ||= "LEGAL EFFECT EVIDENCE:" || '0a'x || legalText || '0a'x || '0a'x
  if conversationText <> "" then prompt ||= "RECENT CONVERSATION:" || '0a'x || conversationText || '0a'x || '0a'x
  prompt ||= "CUSTOMER QUESTION:" || '0a'x || questionText
  return provider~complete(.AIProviderRequest~new(model, prompt, maxOutput))

::method interpretationSchema private
  return .JSON~fromJSON('{"type":"object","properties":{"schema":{"type":"string","const":"flylo.assistant.interpretation/0.2"},"intent":{"type":"string","enum":["BOOK_JOURNEY","MANAGE_BOOKING","TRAVEL_REQUIREMENTS","CUSTOMS_HELP","AIRLINE_HELP","COMPARE_AIRLINE","OFF_TOPIC","UNKNOWN"]},"serviceRequest":{"type":"string","enum":["NONE","BOOKING_LOOKUP","ADD_CHECKED_BAG"]},"informationRequest":{"type":"string","enum":["NONE","BAGGAGE_RULES","IMMIGRATION_ENTRY","CUSTOMS_TOBACCO"]},"requestAction":{"type":"string","enum":["SEARCH","NONE"]},"slots":{"type":"object","properties":{"origin":{"type":"string"},"destination":{"type":"string"},"outboundDay":{"type":"integer","minimum":0,"maximum":31},"outboundMonth":{"type":"integer","minimum":0,"maximum":12},"outboundYear":{"type":"integer","minimum":0,"maximum":2200},"monthRelation":{"type":"string","enum":["NONE","THIS_MONTH","NEXT_MONTH"]},"passengers":{"type":"integer","minimum":0},"tripType":{"type":"string","enum":["","ONE_WAY","RETURN"]},"returnDay":{"type":"integer","minimum":0,"maximum":31},"returnMonth":{"type":"integer","minimum":0,"maximum":12},"returnYear":{"type":"integer","minimum":0,"maximum":2200},"bookingRef":{"type":"string"},"familyName":{"type":"string"},"documentCountry":{"type":"string"},"travellerAge":{"type":"integer","minimum":0,"maximum":120},"companionChildMentioned":{"type":"boolean"},"tobaccoForCompanion":{"type":"boolean"}},"required":["origin","destination","outboundDay","outboundMonth","outboundYear","monthRelation","passengers","tripType","returnDay","returnMonth","returnYear","bookingRef","familyName","documentCountry","travellerAge","companionChildMentioned","tobaccoForCompanion"],"additionalProperties":false}},"required":["schema","intent","serviceRequest","informationRequest","requestAction","slots"],"additionalProperties":false}')

::method responsePlanSchema private
  return .JSON~fromJSON('{"type":"object","properties":{"schema":{"type":"string","const":"flylo.assistant.utterance-plan/0.2"},"text":{"type":"string","minLength":1,"maxLength":4000},"communicativeAct":{"type":"string","enum":["GENERAL","INFORMATION","SERVICE_RESOLUTION","APOLOGY","REFUSAL","SALESPROP"]},"intendedAct":{"type":"string","minLength":1,"maxLength":80},"intendedRegister":{"type":"string","enum":["HELPFUL"]},"intendedOutcome":{"type":"string","minLength":1,"maxLength":80}},"required":["schema","text","communicativeAct","intendedAct","intendedRegister","intendedOutcome"],"additionalProperties":false}')

::method interpretStructured
  expose provider model maxOutput
  use arg question, currentFrame, referenceDate, conversationEvidence = ""
  questionText = self~bounded(question, 4000)
  conversationText = self~bounded(conversationEvidence, 10000)
  if currentFrame == .nil then currentFrame = .directory~new
  frameJson = .JSON~toJSON(currentFrame)
  prompt = "FLYLO STRUCTURED LANGUAGE UNDERSTANDING" || '0a'x
  prompt ||= "The xAI response is constrained by FlyLo's JSON schema. Extract only meaning supported by the customer's message and recent conversation." || '0a'x
  prompt ||= "The output is semantic state, never an executable airline command." || '0a'x
  prompt ||= "If the customer says they already booked, use intent=MANAGE_BOOKING. If they want an extra/checked bag, serviceRequest=ADD_CHECKED_BAG. Do not require passenger count or trip type merely for post-booking servicing." || '0a'x
  prompt ||= "A booking reference is an alphanumeric airline locator such as FL123456; do not mistake a name, route or date for the booking reference." || '0a'x
  prompt ||= "Extract familyName when the customer gives their own full name in a booking-help context. Do not invent it." || '0a'x
  prompt ||= "For immigration/entry questions set informationRequest=IMMIGRATION_ENTRY and extract the travel-document country/nationality wording into documentCountry. Keep a pending serviceRequest from the existing frame unless the customer clearly replaces it." || '0a'x
  prompt ||= "For cigarettes/tobacco/customs questions set informationRequest=CUSTOMS_TOBACCO. If the customer says the tobacco is for a daughter/son/child, set companionChildMentioned=true and tobaccoForCompanion=true; set travellerAge only if an age is actually given." || '0a'x
  prompt ||= "Use city/airport wording as supplied; FlyLo resolves airport codes deterministically. For 29-08 set day=29 month=8; if no year is supplied FlyLo resolves the next non-past occurrence against the server date." || '0a'x
  prompt ||= "For 'next month', set monthRelation=NEXT_MONTH. A bare number is passenger count only when context clearly makes it so. Do not clamp legitimate party sizes to nine: for '10 tickets' set passengers=10 exactly." || '0a'x
  prompt ||= "If existing intent is BOOK_JOURNEY and this is a continuation, keep it unless the customer clearly changes task." || '0a'x
  prompt ||= "CURRENT SERVER DATE: " || referenceDate~string || '0a'x
  prompt ||= "CURRENT STRUCTURED FRAME: " || frameJson || '0a'x
  if conversationText <> "" then prompt ||= "RECENT CONVERSATION:" || '0a'x || conversationText || '0a'x
  prompt ||= "CUSTOMER MESSAGE:" || '0a'x || questionText
  request = .FlyLoStructuredAIRequest~new(model, prompt, maxOutput, "flylo_assistant_interpretation", self~interpretationSchema)
  return provider~complete(request)

::method planStructuredResponse
  expose provider model maxOutput
  use arg question, frame, work, conversationEvidence = "", browserContext = .nil
  questionText = self~bounded(question, 4000)
  conversationText = self~bounded(conversationEvidence, 8000)
  if frame == .nil then frame = .directory~new
  if work == .nil then work = .directory~new
  frameJson = .JSON~toJSON(frame); workJson = .JSON~toJSON(work)
  if browserContext == .nil then browserContext = .directory~new
  browserJson = .JSON~toJSON(browserContext)
  prompt = "FLYLO STRUCTURED RESPONSE GENERATION" || '0a'x
  prompt ||= "The xAI response is constrained by FlyLo's JSON schema. Be concise, human and useful." || '0a'x
  prompt ||= "STRUCTURED FRAME is customer conversation state; ORCHESTRATOR WORK is the only authority for airline-system and government-rule facts." || '0a'x
  prompt ||= "Never ask again for a slot already present. For a post-booking extra-bag request, ask only for missing booking lookup identifiers shown in WORK.missing; do not ask passenger count or one-way/return unless an authoritative servicing operation actually needs them." || '0a'x
  prompt ||= "If BOOKING_SERVICE_PRECHECK says bookingRef is missing, explain that the booking reference is needed to retrieve the booking and continue the bag request. Keep any route/date/name already supplied." || '0a'x
  prompt ||= "If entry evidence is present, distinguish airline document checking from the US government's admission decision. Do not predict that a traveller will or will not be admitted. Use the evidence to explain what document status still needs checking." || '0a'x
  prompt ||= "If customs tobacco evidence is present, answer the checked-bag question directly: ordinary cigarettes may be in checked baggage according to the cited security evidence, but checked baggage and duty-free purchase do not change US customs limits. If a daughter/child is involved and age is unknown, explain that CBP's cited tobacco exemption is for adults 21+ and ask the daughter's age only if needed to assess her own allowance." || '0a'x
  prompt ||= "Never tell the customer that duty-free cigarettes are automatically customs-free. Mention declaration/seizure risk when the supplied CBP evidence establishes it." || '0a'x
  prompt ||= "Never claim you changed, booked, cancelled, rebooked, refunded, charged or added baggage unless a transactional FlyLo authority says so. A quote/precheck is not a transaction." || '0a'x
  prompt ||= "If a journey SEARCH result is present, present route/date/passengers/fare and connection legs directly. If SEARCH_UNAVAILABLE is present, explain that FlyLo could not find an itinerary with enough availability for the requested route/date/party and offer to change the search facts; treat that as an airline search result, never as a language-layer failure. If BOOK_JOURNEY is incomplete but passengers is already known, preserve that exact party size and ask only for the missing search details; do not imply that ten or more passengers is invalid merely because it is a larger party." || '0a'x
  prompt ||= "Harmless off-topic questions may receive a brief helpful answer." || '0a'x
  prompt ||= "Do not ask for card numbers, passwords or authentication secrets." || '0a'x
  prompt ||= "STRUCTURED FRAME: " || frameJson || '0a'x
  prompt ||= "ORCHESTRATOR WORK: " || workJson || '0a'x
  prompt ||= "SANITISED BROWSER CONTEXT (NON-AUTHORITATIVE): " || browserJson || '0a'x
  if conversationText <> "" then prompt ||= "RECENT CONVERSATION:" || '0a'x || conversationText || '0a'x
  prompt ||= "CUSTOMER MESSAGE:" || '0a'x || questionText
  request = .FlyLoStructuredAIRequest~new(model, prompt, maxOutput, "flylo_assistant_utterance_plan", self~responsePlanSchema)
  return provider~complete(request)

::method bounded private
  use arg valueArg, limit
  text = valueArg~string
  if text~length <= limit then return text
  return text~left(limit) || '0a'x || "[truncated by FlyLo boundary]"

/* Adapter from the Grok-authored runtime module to FlyLoGrokAssistant's
   provider-neutral COMPLETE contract.  This deliberately uses the real-time
   model.complete ability; it never selects or invokes Grok Batch. */
::class FlyLoGrokRuntimeProvider public
::method init
  expose runtimeModule
  use arg moduleArg
  if moduleArg == .nil then raise syntax 88.900 array("FLYLO_GROK_RUNTIME_REQUIRED")
  runtimeModule = moduleArg

::method complete
  expose runtimeModule
  use arg request
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  body = .directory~new
  body["model"] = request~model
  body["prompt"] = request~prompt
  body["max_output_tokens"] = request~maxOutputTokens
  context = .FlyLoGrokInvocationContext~new(body)
  outcome = runtimeModule~runtimeInvokeAbility("model.complete", context)
  if \outcome~ok then return .AIProviderReply~failure(outcome~code, outcome~detail, .AIProviderUsage~new(0, 0), request~model)
  value = outcome~value
  text = value["text"]
  actualModel = value["model"]
  finishReason = value["finish_reason"]
  if actualModel == .nil then actualModel = request~model
  if finishReason == .nil then finishReason = "stop"
  return .AIProviderReply~success(text, actualModel, finishReason, .AIProviderUsage~new(0, 0))

::class FlyLoGrokInvocationResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg valueArg = .nil
  return self~new(.true, "OK", "", valueArg)
::method failure class
  use arg codeArg, detailArg = ""
  return self~new(.false, codeArg, detailArg, .nil)

::class FlyLoGrokInvocationContext public
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
  use arg valueArg = .nil
  return .FlyLoGrokInvocationResult~success(valueArg)
::method failure
  use arg codeArg, detailArg = ""
  return .FlyLoGrokInvocationResult~failure(codeArg, detailArg)

::requires "FlyLoGrokStructuredProvider.cls"
::requires "GrokProvider.cls"
::requires "AIProviderAccess.cls"

::requires "json.cls"
