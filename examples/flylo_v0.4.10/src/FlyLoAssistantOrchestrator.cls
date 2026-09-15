/* Deterministic FlyLo assistant orchestration over structured language frames.
 * Model output proposes meaning only. Airline engines and versioned external
 * travel-information snapshots remain separate authorities.
 */

::class FlyLoAssistantJourneyAdapter public
::method init
  expose runtime
  use arg runtimeArg
  if runtimeArg == .nil then raise syntax 88.900 array("FLYLO_ASSISTANT_RUNTIME_REQUIRED")
  runtime = runtimeArg
::method payload private
  use arg queueResult
  if queueResult == .nil then raise syntax 88.900 array("FLYLO_ASSISTANT_ENGINE_NO_RESULT")
  if \queueResult~ok then raise syntax 88.900 array("FLYLO_ASSISTANT_ENGINE_QUEUE_FAILED", queueResult~code, queueResult~detail)
  package = queueResult~value
  if package == .nil then raise syntax 88.900 array("FLYLO_ASSISTANT_ENGINE_PACKAGE_MISSING")
  p = package~payload
  if p == .nil | \p~isa(.Directory) then raise syntax 88.900 array("FLYLO_ASSISTANT_ENGINE_RESULT_INVALID")
  if \p~hasIndex("ok") then raise syntax 88.900 array("FLYLO_ASSISTANT_ENGINE_OUTCOME_MISSING")
  /* A domain rejection such as NO_ITINERARY_AVAILABLE is passenger-facing
     airline evidence, not an internal bridge failure.  Infrastructure/queue
     failures above still raise. */
  return p
::method searchFlights
  expose runtime
  use arg origin, destination, travelDate, passengers = 1
  d = .directory~new
  d["origin"] = origin; d["destination"] = destination; d["travelDate"] = travelDate; d["passengers"] = passengers
  commandId = runtime~nextCommandId
  idem = "ASSISTANT-SEARCH:" || origin || ":" || destination || ":" || travelDate || ":" || passengers || ":" || commandId
  c = .FlyLoEngineCommand~new(commandId, "SEARCH", idem, d)
  return self~payload(runtime~requestJourney(c))

::class FlyLoAssistantBookingAdapter public
::method init
  expose runtime
  use arg runtimeArg
  if runtimeArg == .nil then raise syntax 88.900 array("FLYLO_ASSISTANT_RUNTIME_REQUIRED")
  runtime = runtimeArg
::method lookup
  expose runtime
  use arg bookingRef, familyName
  d = .directory~new
  d["bookingRef"] = bookingRef; d["familyName"] = familyName
  commandId = runtime~nextCommandId
  c = .FlyLoEngineCommand~new(commandId, "BOOKING_LOOKUP", "ASSISTANT-BOOKING-LOOKUP:" || bookingRef || ":" || commandId, d)
  queueResult = runtime~requestBooking(c)
  outcome = .directory~new
  if queueResult == .nil | \queueResult~ok then do
    outcome["ok"] = .false; outcome["code"] = "BOOKING_LOOKUP_QUEUE_FAILED"; return outcome
  end
  package = queueResult~value
  if package == .nil then do; outcome["ok"] = .false; outcome["code"] = "BOOKING_LOOKUP_RESULT_MISSING"; return outcome; end
  p = package~payload
  if p == .nil | \p~isa(.Directory) then do; outcome["ok"] = .false; outcome["code"] = "BOOKING_LOOKUP_RESULT_INVALID"; return outcome; end
  outcome["ok"] = p["ok"]
  outcome["code"] = p["code"]
  outcome["detail"] = p["detail"]
  if p["ok"] then outcome["booking"] = p["value"]
  return outcome

::class FlyLoAssistantOrchestrator public
::method init
  expose journey booking travelInfo
  use arg journeyArg, bookingArg = .nil, travelInfoArg = .nil
  if journeyArg == .nil then raise syntax 88.900 array("FLYLO_ASSISTANT_JOURNEY_REQUIRED")
  journey = journeyArg
  booking = bookingArg
  if travelInfoArg == .nil then travelInfo = .FlyLoTravelInformationAuthority~new
  else travelInfo = travelInfoArg
::method evaluate
  expose journey booking travelInfo
  use arg frame
  work = .directory~new
  work["operation"] = "NONE"
  work["evidenceSource"] = ""
  work["evidence"] = .directory~new
  work["missing"] = .array~new

  /* Read-only journey search becomes automatic once the booking-shopping frame
     is complete. The model never decides to execute SEARCH. */
  if frame~searchReady then do
    searchOutcome = journey~searchFlights(frame~origin, frame~destination, frame~outboundDate, frame~passengers)
    work["evidenceSource"] = "FLYLO_JOURNEY_ENGINE_SEARCH"
    if searchOutcome["ok"] then do
      work["operation"] = "SEARCH"
      work["evidence"]["journey"] = searchOutcome
    end
    else do
      unavailable = .directory~new
      unavailable["ok"] = .false
      unavailable["code"] = searchOutcome["code"]
      unavailable["detail"] = searchOutcome["detail"]
      unavailable["origin"] = frame~origin
      unavailable["destination"] = frame~destination
      unavailable["travelDate"] = frame~outboundDate
      unavailable["passengers"] = frame~passengers
      work["operation"] = "SEARCH_UNAVAILABLE"
      work["evidence"]["journeySearch"] = unavailable
    end
    return work
  end
  if frame~intent = "BOOK_JOURNEY" then work["missing"] = frame~missingSearchSlots

  /* Post-booking bag service: do not ask shopping questions such as passenger
     count or trip type. A booking reference + family name identifies the
     servicing lookup boundary. */
  if frame~serviceRequest = "ADD_CHECKED_BAG" | frame~serviceRequest = "BOOKING_LOOKUP" then do
    work["evidence"]["checkedBagProduct"] = travelInfo~checkedBagProductEvidence
    if frame~bookingLookupReady & booking \== .nil then do
      lookup = booking~lookup(frame~bookingRef, frame~familyName)
      work["operation"] = "BOOKING_LOOKUP"
      work["evidenceSource"] = "FLYLO_BOOKING_ENGINE_LOOKUP"
      work["evidence"]["bookingLookup"] = lookup
      work["missing"] = .array~new
    end
    else do
      work["operation"] = "BOOKING_SERVICE_PRECHECK"
      work["evidenceSource"] = "FLYLO_ANCILLARY_POLICY"
      work["missing"] = frame~missingBookingLookupSlots
    end
  end

  /* Information requests may coexist with a pending bag-service request. */
  if frame~informationRequest = "IMMIGRATION_ENTRY" then do
    work["evidence"]["entry"] = travelInfo~usEntryEvidence(frame~documentCountry)
    if work["operation"] = "NONE" then work["operation"] = "TRAVEL_REQUIREMENTS_INFO"
    else work["operation"] = work["operation"] || "+TRAVEL_REQUIREMENTS_INFO"
    work["evidenceSource"] = self~appendSource(work["evidenceSource"], "US_STATE_DEPARTMENT_ENTRY_SNAPSHOT")
  end
  if frame~informationRequest = "CUSTOMS_TOBACCO" then do
    work["evidence"]["customsTobacco"] = travelInfo~usTobaccoEvidence(frame~companionChildMentioned, frame~travellerAge, frame~tobaccoForCompanion)
    work["evidence"]["cigaretteBaggage"] = travelInfo~cigaretteBaggageEvidence
    if work["operation"] = "NONE" then work["operation"] = "CUSTOMS_TOBACCO_INFO"
    else work["operation"] = work["operation"] || "+CUSTOMS_TOBACCO_INFO"
    work["evidenceSource"] = self~appendSource(work["evidenceSource"], "US_CBP_TOBACCO_AND_TSA_BAGGAGE_SNAPSHOT")
  end
  if frame~informationRequest = "BAGGAGE_RULES" then do
    work["evidence"]["cigaretteBaggage"] = travelInfo~cigaretteBaggageEvidence
    if work["operation"] = "NONE" then work["operation"] = "BAGGAGE_INFO"
    work["evidenceSource"] = self~appendSource(work["evidenceSource"], "FLYLO_AND_GOVERNMENT_BAGGAGE_SNAPSHOT")
  end
  return work
::method appendSource private
  use arg current, addition
  if current~string = "" then return addition~string
  return current~string || "+" || addition~string

::requires "FlyLoStructuredLanguage.cls"
::requires "FlyLoTravelInformation.cls"
::requires "FlyLoServices.cls"
