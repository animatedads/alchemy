say "FLYLO STRUCTURED GROK BOUNDARY START"
p = .CapturingStructuredProvider~new
a = .FlyLoGrokAssistant~new(p, "fixture-model", 256)

frame = .directory~new
frame["schema"] = "flylo.assistant.frame/0.2"
frame["intent"] = "MANAGE_BOOKING"
frame["serviceRequest"] = "ADD_CHECKED_BAG"
frame["informationRequest"] = "NONE"
slots = .directory~new
slots["origin"] = "GLA"; slots["destination"] = "EWR"; slots["familyName"] = "Dyer"
frame["slots"] = slots

r = a~interpretStructured("my daughter wants duty free cigarettes", frame, "2026-08-28", "CUSTOMER: I need an extra bag")
if \r~ok then do; say "FAIL interpretation request"; exit 81; end
req = p~request
prompt = req~prompt
if \req~isa(.FlyLoStructuredAIRequest) then do; say "FAIL request not schema-constrained type"; exit 82; end
if req~schemaName <> "flylo_assistant_interpretation" then do; say "FAIL interpretation schema name"; exit 83; end
schemaJson = .JSON~toJSON(req~responseSchema)
if schemaJson~pos('flylo.assistant.interpretation') = 0 | schemaJson~pos('0.2') = 0 then do; say "FAIL interpretation schema version"; exit 84; end
if schemaJson~pos('"maximum":9') > 0 then do; say "FAIL passenger schema still clamps to nine"; exit 841; end
if prompt~pos("for '10 tickets' set passengers=10 exactly") = 0 then do; say "FAIL large-party extraction instruction"; exit 842; end
if prompt~pos("semantic state, never an executable airline command") = 0 then do; say "FAIL authority boundary"; exit 85; end
if prompt~pos("serviceRequest=ADD_CHECKED_BAG") = 0 then do; say "FAIL ancillary interpretation"; exit 86; end
if prompt~pos("companionChildMentioned=true") = 0 then do; say "FAIL child customs extraction"; exit 87; end

work = .directory~new
work["operation"] = "BOOKING_SERVICE_PRECHECK+CUSTOMS_TOBACCO_INFO"
work["missing"] = .array~of("bookingRef")
evidence = .directory~new
work["evidence"] = evidence
r = a~planStructuredResponse("This can be checked bags right?", frame, work, "", .directory~new)
if \r~ok then do; say "FAIL response request"; exit 88; end
req = p~request
prompt = req~prompt
if \req~isa(.FlyLoStructuredAIRequest) then do; say "FAIL response not schema-constrained type"; exit 89; end
if req~schemaName <> "flylo_assistant_utterance_plan" then do; say "FAIL response schema name"; exit 90; end
schemaJson = .JSON~toJSON(req~responseSchema)
if schemaJson~pos('flylo.assistant.utterance-plan') = 0 | schemaJson~pos('0.2') = 0 then do; say "FAIL response schema version"; exit 91; end
if prompt~pos("ORCHESTRATOR WORK is the only authority") = 0 then do; say "FAIL orchestrator authority boundary"; exit 92; end
if prompt~pos("do not ask passenger count or one-way/return") = 0 then do; say "FAIL post-booking no-shopping boundary"; exit 93; end
if prompt~pos("ordinary cigarettes may be in checked baggage") = 0 then do; say "FAIL direct checked-bag answer policy"; exit 94; end
if prompt~pos("adults 21+") = 0 then do; say "FAIL child-age customs boundary"; exit 95; end
if prompt~pos("Never claim you changed, booked, cancelled, rebooked, refunded, charged or added baggage") = 0 then do; say "FAIL transaction claim boundary"; exit 96; end

say "FLYLO STRUCTURED GROK BOUNDARY: OK"
exit 0

::class CapturingStructuredProvider
::attribute request get
::method complete
  expose request
  use arg requestArg
  request = requestArg
  return .AIProviderReply~success('{"schema":"fixture"}', request~model, "stop", .AIProviderUsage~new(1, 1))

::requires "FlyLoGrokAssistant.cls"
