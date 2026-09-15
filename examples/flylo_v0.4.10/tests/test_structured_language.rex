say "FLYLO STRUCTURED LANGUAGE START"
frame = .FlyLoLanguageFrame~new

i1 = interpretation("BOOK_JOURNEY", "NONE", "NONE", "", "", 0, 0, 0, "NONE", 0, "", "", "", "", 0, .false, .false)
r = frame~applyInterpretation(i1, "2026-08-28")
call yes r~ok, "booking intent accepted"
call eq "BOOK_JOURNEY", frame~intent, "intent"

i2 = interpretation("BOOK_JOURNEY", "NONE", "NONE", "Glasgow", "New York", 0, 0, 0, "NONE", 0, "", "", "", "", 0, .false, .false)
r = frame~applyInterpretation(i2, "2026-08-28")
call yes r~ok, "route accepted"
call eq "GLA", frame~origin, "Glasgow resolves deterministically"
call eq "EWR", frame~destination, "New York resolves to fixture EWR"

i3 = interpretation("BOOK_JOURNEY", "NONE", "NONE", "", "", 29, 0, 0, "NONE", 2, "", "", "", "", 0, .false, .false)
r = frame~applyInterpretation(i3, "2026-08-28")
call yes r~ok, "day/passengers accepted"
call eq 29, frame~outboundDay, "day"
call eq 2, frame~passengers, "passengers"

/* A larger party remains valid semantic state; inventory/business authority
   decides whether a route can actually carry it. */
large = .FlyLoLanguageFrame~new
largeI = interpretation("BOOK_JOURNEY", "NONE", "NONE", "", "New York", 0, 0, 0, "NONE", 10, "", "", "", "", 0, .false, .false)
r = large~applyInterpretation(largeI, "2026-08-28")
call yes r~ok, "ten-passenger language frame accepted"
call eq 10, large~passengers, "ten-passenger count preserved"
call eq "EWR", large~destination, "ten-passenger destination preserved"

i4 = interpretation("BOOK_JOURNEY", "NONE", "NONE", "", "", 0, 0, 0, "NEXT_MONTH", 0, "", "", "", "", 0, .false, .false)
r = frame~applyInterpretation(i4, "2026-08-28")
call yes r~ok, "relative month accepted"
call eq "2026-09-29", frame~outboundDate, "next month resolves using server date"

i5 = interpretation("BOOK_JOURNEY", "NONE", "NONE", "", "", 0, 0, 0, "NONE", 0, "ONE_WAY", "", "", "", 0, .false, .false)
r = frame~applyInterpretation(i5, "2026-08-28")
call yes r~ok, "trip type accepted"
call yes frame~searchReady, "complete booking frame is search-ready"
call eq 0, frame~missingSearchSlots~items, "no redundant questions remain"

/* Post-booking state is independent from shopping slots. */
post = .FlyLoLanguageFrame~new
p1 = interpretation("MANAGE_BOOKING", "ADD_CHECKED_BAG", "NONE", "Glasgow", "Newark", 29, 8, 0, "NONE", 0, "", "", "Dyer", "", 0, .false, .false)
r = post~applyInterpretation(p1, "2026-08-28")
call yes r~ok, "post-booking bag request accepted"
call eq "2026-08-29", post~outboundDate, "bare 29-08 resolves next non-past occurrence"
call eq "ADD_CHECKED_BAG", post~serviceRequest, "bag service retained"
call eq 1, post~missingBookingLookupSlots~items, "bag servicing asks only missing booking identifier"
call eq "bookingRef", post~missingBookingLookupSlots[1], "booking reference is only missing lookup slot"

p2 = interpretation("TRAVEL_REQUIREMENTS", "NONE", "IMMIGRATION_ENTRY", "", "", 0, 0, 0, "NONE", 2, "ONE_WAY", "", "", "Columbian", 0, .true, .false)
r = post~applyInterpretation(p2, "2026-08-28")
call yes r~ok, "entry question accepted"
call eq "ADD_CHECKED_BAG", post~serviceRequest, "information question does not destroy pending bag service"
call eq "IMMIGRATION_ENTRY", post~informationRequest, "entry info request tracked separately"
call eq "COL", post~documentCountry, "common Columbian misspelling normalizes to Colombia"
call eq 2, post~passengers, "passenger fact retained without becoming bag lookup requirement"

p3 = interpretation("CUSTOMS_HELP", "NONE", "CUSTOMS_TOBACCO", "", "", 0, 0, 0, "NONE", 0, "", "", "", "", 0, .true, .true)
r = post~applyInterpretation(p3, "2026-08-28")
call yes r~ok, "customs question accepted"
call eq "ADD_CHECKED_BAG", post~serviceRequest, "customs topic does not destroy pending service"
call eq "CUSTOMS_TOBACCO", post~informationRequest, "customs info replaces previous info subtask"
call yes post~companionChildMentioned, "child context retained"
call yes post~tobaccoForCompanion, "tobacco ownership context retained"

plan = .directory~new
plan["schema"] = .FlyLoStructuredLanguageBuild~RESPONSE_PLAN_SCHEMA
plan["text"] = "I found a FlyLo itinerary from Glasgow to New York on 29 September 2026."
plan["communicativeAct"] = "SERVICE_RESOLUTION"
plan["intendedAct"] = "PRESENT_FLIGHT_OPTIONS"
plan["intendedRegister"] = "HELPFUL"
plan["intendedOutcome"] = "CUSTOMER_CAN_SELECT"
built = .FlyLoStructuredReplyFactory~build("TEST-UTTERANCE-1", plan, frame, "FLYLO_JOURNEY_ENGINE_SEARCH", "fixture-model")
call yes built~ok, "structured reply builds"
summary = built~value
call yes summary["sealed"], "StructuredUtterance sealed before flattening"
call eq "structured.utterance/0.3", summary["schema"], "structured utterance schema"
call eq "SERVICE_RESOLUTION", summary["communicativeAct"], "communicative act retained"
call eq "PRESENT_FLIGHT_OPTIONS", summary["intendedAct"], "generation intent retained"
call eq 2, summary["lineageCount"], "customer-frame and engine lineage retained"
call contains summary["canonicalText"], "MODEL_OUTPUT_JSON_SCHEMA_CONSTRAINED", "strict structured model constraint retained"
call contains summary["canonicalText"], "FLYLO_JOURNEY_ENGINE_SEARCH", "engine evidence lineage retained"

say "FLYLO STRUCTURED LANGUAGE: OK"
exit 0

interpretation: procedure
  use arg intent, serviceRequest, informationRequest, origin, destination, day, month, year, relation, passengers, tripType, bookingRef, familyName, documentCountry, travellerAge, childMentioned, tobaccoForCompanion
  d = .directory~new
  d["schema"] = "flylo.assistant.interpretation/0.2"
  d["intent"] = intent
  d["serviceRequest"] = serviceRequest
  d["informationRequest"] = informationRequest
  d["requestAction"] = "NONE"
  s = .directory~new
  s["origin"] = origin; s["destination"] = destination
  s["outboundDay"] = day; s["outboundMonth"] = month; s["outboundYear"] = year
  s["monthRelation"] = relation; s["passengers"] = passengers; s["tripType"] = tripType
  s["returnDay"] = 0; s["returnMonth"] = 0; s["returnYear"] = 0
  s["bookingRef"] = bookingRef; s["familyName"] = familyName
  s["documentCountry"] = documentCountry; s["travellerAge"] = travellerAge
  s["companionChildMentioned"] = childMentioned; s["tobaccoForCompanion"] = tobaccoForCompanion
  d["slots"] = s
  return d

yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 51; end; return
eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 52; end; return
contains: procedure; use arg text, needle, label; if text~pos(needle) = 0 then do; say "FAIL" label; exit 53; end; return

::requires "FlyLoStructuredLanguage.cls"
