say "FLYLO ASSISTANT LARGE PARTY START"
runtime = .FlyLoBackendFactory~fixture
journeyOps = .FlyLoAssistantJourneyAdapter~new(runtime)
orchestrator = .FlyLoAssistantOrchestrator~new(journeyOps)

frame = .FlyLoLanguageFrame~new
i = .directory~new
i["schema"] = .FlyLoStructuredLanguageBuild~INTERPRETATION_SCHEMA
i["intent"] = "BOOK_JOURNEY"
i["serviceRequest"] = "NONE"
i["informationRequest"] = "NONE"
i["requestAction"] = "NONE"
s = .directory~new
s["origin"] = "Glasgow"; s["destination"] = "New York"
s["outboundDay"] = 29; s["outboundMonth"] = 9; s["outboundYear"] = 2026
s["monthRelation"] = "NONE"; s["passengers"] = 10; s["tripType"] = "ONE_WAY"
s["returnDay"] = 0; s["returnMonth"] = 0; s["returnYear"] = 0
s["bookingRef"] = ""; s["familyName"] = ""; s["documentCountry"] = ""; s["travellerAge"] = 0
s["companionChildMentioned"] = .false; s["tobaccoForCompanion"] = .false
i["slots"] = s
merged = frame~applyInterpretation(i, "2026-08-28")
call yes merged~ok, "ten-passenger frame accepted"
call yes frame~searchReady, "ten-passenger frame search-ready"
work = orchestrator~evaluate(frame)
call eq "SEARCH_UNAVAILABLE", work["operation"], "insufficient inventory is a search outcome"
call eq "FLYLO_JOURNEY_ENGINE_SEARCH", work["evidenceSource"], "journey engine remains authority"
e = work["evidence"]["journeySearch"]
call eq "NO_ITINERARY_AVAILABLE", e["code"], "no itinerary domain code retained"
call eq 10, e["passengers"], "party size retained in unavailable evidence"

say "FLYLO ASSISTANT LARGE PARTY: OK"
exit 0

yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 61; end; return
eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 62; end; return

::requires "FlyLoAssistantOrchestrator.cls"
