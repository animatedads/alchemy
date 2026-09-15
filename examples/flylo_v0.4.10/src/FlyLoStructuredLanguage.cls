/* FlyLo structured-language boundary.
 *
 * The LLM may interpret passenger language into this bounded frame, but the
 * frame is never an airline command. FlyLo resolves locations/dates, verifies
 * post-booking identifiers and decides when to invoke airline or travel-rule
 * authorities. Generated language is captured as Structured Utterance v0.3
 * before delivery text is flattened.
 */

::class FlyLoStructuredLanguageBuild public
::constant VERSION "0.2.1"
::constant FRAME_SCHEMA "flylo.assistant.frame/0.2"
::constant INTERPRETATION_SCHEMA "flylo.assistant.interpretation/0.2"
::constant RESPONSE_PLAN_SCHEMA "flylo.assistant.utterance-plan/0.2"

::class FlyLoStructuredLanguageResult public
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

::class FlyLoLocationResolver public
::method airportCode class
  use arg rawValue
  text = translate(strip(rawValue~string))
  text = text~changestr("_", " ")
  text = text~changestr("-", " ")
  do while text~pos("  ") > 0; text = text~changestr("  ", " "); end
  if text~length = 3 then do
    if wordpos(text, "GLA PIK EDI MAN LHR EWR JFK LGW STN") > 0 then return text
  end
  select
    when text = "GLASGOW" then return "GLA"
    when text = "GLASGOW AIRPORT" then return "GLA"
    when text = "GLASGOW PRESTWICK" then return "PIK"
    when text = "PRESTWICK" then return "PIK"
    when text = "EDINBURGH" then return "EDI"
    when text = "MANCHESTER" then return "MAN"
    when text = "LONDON HEATHROW" then return "LHR"
    when text = "HEATHROW" then return "LHR"
    when text = "NEW YORK" then return "EWR"
    when text = "NEW YORK CITY" then return "EWR"
    when text = "NYC" then return "EWR"
    when text = "NEWARK" then return "EWR"
    when text = "NEWARK LIBERTY" then return "EWR"
    otherwise return ""
  end

::class FlyLoCountryResolver public
::method documentCountry class
  use arg rawValue
  text = translate(strip(rawValue~string))
  select
    when text = "CO" then return "COL"
    when text = "COL" then return "COL"
    when text = "COLOMBIA" then return "COL"
    when text = "COLOMBIAN" then return "COL"
    when text = "COLUMBIAN" then return "COL" /* common misspelling in customer language */
    when text = "UNITED KINGDOM" then return "GBR"
    when text = "UK" then return "GBR"
    when text = "BRITISH" then return "GBR"
    when text = "UNITED STATES" then return "USA"
    when text = "USA" then return "USA"
    when text = "US" then return "USA"
    otherwise return ""
  end

::class FlyLoDateResolver public
::method leapYear class
  use arg year
  y = year + 0
  if y // 400 = 0 then return .true
  if y // 100 = 0 then return .false
  return y // 4 = 0
::method daysInMonth class
  use arg year, month
  m = month + 0
  if wordpos(m, "1 3 5 7 8 10 12") > 0 then return 31
  if wordpos(m, "4 6 9 11") > 0 then return 30
  if m = 2 then do
    if self~leapYear(year) then return 29
    return 28
  end
  return 0
::method validDate class
  use arg year, month, day
  y = year + 0; m = month + 0; d = day + 0
  if y < 2000 | y > 2200 then return .false
  maxDay = self~daysInMonth(y, m)
  if maxDay = 0 then return .false
  return d >= 1 & d <= maxDay
::method formatDate class
  use arg year, month, day
  if \self~validDate(year, month, day) then return ""
  return right("0000" || (year + 0), 4) || "-" || right("0" || (month + 0), 2) || "-" || right("0" || (day + 0), 2)
::method applyMonthRelation class
  use arg relationArg, referenceDate
  relation = translate(strip(relationArg~string))
  if referenceDate~string~length < 10 then return .array~of(0, 0)
  yText = referenceDate~string~substr(1, 4)
  mText = referenceDate~string~substr(6, 2)
  if \datatype(yText, "W") | \datatype(mText, "W") then return .array~of(0, 0)
  y = yText + 0; m = mText + 0
  if relation = "NEXT_MONTH" then do
    m += 1
    if m > 12 then do; m = 1; y += 1; end
    return .array~of(y, m)
  end
  if relation = "THIS_MONTH" then return .array~of(y, m)
  return .array~of(0, 0)
::method inferYear class
  use arg month, day, referenceDate
  if referenceDate~string~length < 10 then return 0
  yText = referenceDate~string~substr(1, 4)
  mText = referenceDate~string~substr(6, 2)
  dText = referenceDate~string~substr(9, 2)
  if \datatype(yText, "W") | \datatype(mText, "W") | \datatype(dText, "W") then return 0
  y = yText + 0
  if month + 0 < mText + 0 then y += 1
  else if month + 0 = mText + 0 then if day + 0 < dText + 0 then y += 1
  return y

::class FlyLoLanguageFrame public
::attribute intent get
::attribute serviceRequest get
::attribute informationRequest get
::attribute origin get
::attribute destination get
::attribute outboundDay get
::attribute outboundMonth get
::attribute outboundYear get
::attribute passengers get
::attribute tripType get
::attribute returnDay get
::attribute returnMonth get
::attribute returnYear get
::attribute bookingRef get
::attribute familyName get
::attribute documentCountry get
::attribute travellerAge get
::attribute companionChildMentioned get
::attribute tobaccoForCompanion get
::method init
  expose intent serviceRequest informationRequest origin destination outboundDay outboundMonth outboundYear passengers tripType returnDay returnMonth returnYear bookingRef familyName documentCountry travellerAge companionChildMentioned tobaccoForCompanion
  intent = "UNKNOWN"
  serviceRequest = "NONE"
  informationRequest = "NONE"
  origin = ""; destination = ""
  outboundDay = 0; outboundMonth = 0; outboundYear = 0
  passengers = 0; tripType = ""
  returnDay = 0; returnMonth = 0; returnYear = 0
  bookingRef = ""; familyName = ""; documentCountry = ""; travellerAge = 0
  companionChildMentioned = .false; tobaccoForCompanion = .false
::method fromDirectory class
  use arg d
  frame = self~new
  if d == .nil | \d~isa(.Directory) then return frame
  if d~hasIndex("intent") then frame~setIntent(d["intent"])
  if d~hasIndex("serviceRequest") then frame~setServiceRequest(d["serviceRequest"])
  if d~hasIndex("informationRequest") then frame~setInformationRequest(d["informationRequest"])
  slots = d["slots"]
  if slots \== .nil then if slots~isa(.Directory) then frame~applySlots(slots, "")
  return frame
::method setIntent
  expose intent
  use arg valueArg
  value = translate(strip(valueArg~string))
  if wordpos(value, "BOOK_JOURNEY MANAGE_BOOKING TRAVEL_REQUIREMENTS CUSTOMS_HELP AIRLINE_HELP COMPARE_AIRLINE OFF_TOPIC UNKNOWN") = 0 then return .false
  if value <> "UNKNOWN" then intent = value
  return .true
::method setServiceRequest
  expose serviceRequest
  use arg valueArg
  value = translate(strip(valueArg~string))
  if value = "" then value = "NONE"
  if wordpos(value, "NONE BOOKING_LOOKUP ADD_CHECKED_BAG") = 0 then return .false
  if value <> "NONE" then serviceRequest = value
  return .true
::method setInformationRequest
  expose informationRequest
  use arg valueArg
  value = translate(strip(valueArg~string))
  if value = "" then value = "NONE"
  if wordpos(value, "NONE BAGGAGE_RULES IMMIGRATION_ENTRY CUSTOMS_TOBACCO") = 0 then return .false
  if value <> "NONE" then informationRequest = value
  return .true
::method applyInterpretation
  use arg interpretation, referenceDate
  if interpretation == .nil | \interpretation~isa(.Directory) then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_INVALID")
  if interpretation["schema"]~string <> .FlyLoStructuredLanguageBuild~INTERPRETATION_SCHEMA then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_SCHEMA_INVALID")
  if \self~setIntent(interpretation["intent"]) then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_INTENT_INVALID")
  if interpretation~hasIndex("serviceRequest") then if \self~setServiceRequest(interpretation["serviceRequest"]) then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_SERVICE_INVALID")
  if interpretation~hasIndex("informationRequest") then if \self~setInformationRequest(interpretation["informationRequest"]) then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_INFORMATION_INVALID")
  slots = interpretation["slots"]
  if slots == .nil | \slots~isa(.Directory) then return .FlyLoStructuredLanguageResult~failure("FLYLO_INTERPRETATION_SLOTS_INVALID")
  return self~applySlots(slots, referenceDate)
::method applySlots private
  expose origin destination outboundDay outboundMonth outboundYear passengers tripType returnDay returnMonth returnYear bookingRef familyName documentCountry travellerAge companionChildMentioned tobaccoForCompanion
  use arg slots, referenceDate
  if slots~hasIndex("origin") then do
    raw = slots["origin"]~string
    if strip(raw) <> "" then do
      code = .FlyLoLocationResolver~airportCode(raw)
      if code = "" then return .FlyLoStructuredLanguageResult~failure("FLYLO_ORIGIN_UNRESOLVED", raw)
      origin = code
    end
  end
  if slots~hasIndex("destination") then do
    raw = slots["destination"]~string
    if strip(raw) <> "" then do
      code = .FlyLoLocationResolver~airportCode(raw)
      if code = "" then return .FlyLoStructuredLanguageResult~failure("FLYLO_DESTINATION_UNRESOLVED", raw)
      destination = code
    end
  end
  if slots~hasIndex("outboundDay") then do
    v = slots["outboundDay"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then outboundDay = v + 0
  end
  if slots~hasIndex("outboundMonth") then do
    v = slots["outboundMonth"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then outboundMonth = v + 0
  end
  if slots~hasIndex("outboundYear") then do
    v = slots["outboundYear"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then outboundYear = v + 0
  end
  if slots~hasIndex("monthRelation") then do
    relation = translate(strip(slots["monthRelation"]~string))
    if relation <> "" & relation <> "NONE" & referenceDate~string <> "" then do
      ym = .FlyLoDateResolver~applyMonthRelation(relation, referenceDate)
      if ym[1] = 0 then return .FlyLoStructuredLanguageResult~failure("FLYLO_DATE_RELATION_INVALID", relation)
      outboundYear = ym[1]; outboundMonth = ym[2]
    end
  end
  if outboundMonth > 0 & outboundDay > 0 & outboundYear = 0 & referenceDate~string <> "" then outboundYear = .FlyLoDateResolver~inferYear(outboundMonth, outboundDay, referenceDate)
  if slots~hasIndex("passengers") then do
    v = slots["passengers"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then passengers = v + 0
  end
  if slots~hasIndex("tripType") then do
    value = translate(strip(slots["tripType"]~string))
    if value <> "" then do
      if wordpos(value, "ONE_WAY RETURN") = 0 then return .FlyLoStructuredLanguageResult~failure("FLYLO_TRIP_TYPE_INVALID", value)
      tripType = value
    end
  end
  if slots~hasIndex("returnDay") then do
    v = slots["returnDay"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then returnDay = v + 0
  end
  if slots~hasIndex("returnMonth") then do
    v = slots["returnMonth"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then returnMonth = v + 0
  end
  if slots~hasIndex("returnYear") then do
    v = slots["returnYear"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then returnYear = v + 0
  end
  if slots~hasIndex("bookingRef") then do
    value = translate(strip(slots["bookingRef"]~string))
    if value <> "" then do
      allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      if verify(value, allowed) <> 0 | value~length > 32 then return .FlyLoStructuredLanguageResult~failure("FLYLO_BOOKING_REF_INVALID")
      bookingRef = value
    end
  end
  if slots~hasIndex("familyName") then do
    value = strip(slots["familyName"]~string)
    if value <> "" then do
      if value~length > 100 then return .FlyLoStructuredLanguageResult~failure("FLYLO_FAMILY_NAME_INVALID")
      familyName = value
    end
  end
  if slots~hasIndex("documentCountry") then do
    raw = slots["documentCountry"]~string
    if strip(raw) <> "" then do
      code = .FlyLoCountryResolver~documentCountry(raw)
      if code = "" then return .FlyLoStructuredLanguageResult~failure("FLYLO_DOCUMENT_COUNTRY_UNRESOLVED", raw)
      documentCountry = code
    end
  end
  if slots~hasIndex("travellerAge") then do
    v = slots["travellerAge"]
    if v \== .nil then if datatype(v~string, "W") then if v + 0 > 0 then do
      if v + 0 > 120 then return .FlyLoStructuredLanguageResult~failure("FLYLO_TRAVELLER_AGE_INVALID")
      travellerAge = v + 0
    end
  end
  if slots~hasIndex("companionChildMentioned") then companionChildMentioned = self~truth(slots["companionChildMentioned"])
  if slots~hasIndex("tobaccoForCompanion") then tobaccoForCompanion = self~truth(slots["tobaccoForCompanion"])
  return .FlyLoStructuredLanguageResult~success(self)
::method truth private
  use arg valueArg
  /* Do not depend on the host json.cls class identity here.  The launcher
     vendors the r13196 JSON implementation, but truth conversion remains
     representation-neutral so a decoded JSON boolean cannot crash a turn. */
  if valueArg == .nil then return .false
  if valueArg == .true then return .true
  if valueArg~hasMethod("VALUE") then do
    logicalValue = valueArg~value
    if logicalValue == .true then return .true
    if logicalValue == .false then return .false
  end
  text = translate(strip(valueArg~string))
  return text = "TRUE" | text = "1" | text = "YES"
::method outboundDate
  expose outboundDay outboundMonth outboundYear
  if outboundDay = 0 | outboundMonth = 0 | outboundYear = 0 then return ""
  return .FlyLoDateResolver~formatDate(outboundYear, outboundMonth, outboundDay)
::method returnDate
  expose returnDay returnMonth returnYear
  if returnDay = 0 | returnMonth = 0 | returnYear = 0 then return ""
  return .FlyLoDateResolver~formatDate(returnYear, returnMonth, returnDay)
::method missingSearchSlots
  expose origin destination passengers tripType
  missing = .array~new
  if origin = "" then missing~append("origin")
  if destination = "" then missing~append("destination")
  if self~outboundDate = "" then missing~append("outboundDate")
  if passengers < 1 then missing~append("passengers")
  if tripType = "" then missing~append("tripType")
  if tripType = "RETURN" & self~returnDate = "" then missing~append("returnDate")
  return missing
::method searchReady
  expose intent
  return intent = "BOOK_JOURNEY" & self~missingSearchSlots~items = 0
::method missingBookingLookupSlots
  expose bookingRef familyName
  missing = .array~new
  if bookingRef = "" then missing~append("bookingRef")
  if familyName = "" then missing~append("familyName")
  return missing
::method bookingLookupReady
  expose serviceRequest
  if serviceRequest <> "BOOKING_LOOKUP" & serviceRequest <> "ADD_CHECKED_BAG" then return .false
  return self~missingBookingLookupSlots~items = 0
::method asDirectory
  expose intent serviceRequest informationRequest origin destination outboundDay outboundMonth outboundYear passengers tripType returnDay returnMonth returnYear bookingRef familyName documentCountry travellerAge companionChildMentioned tobaccoForCompanion
  d = .directory~new
  d["schema"] = .FlyLoStructuredLanguageBuild~FRAME_SCHEMA
  d["intent"] = intent
  d["serviceRequest"] = serviceRequest
  d["informationRequest"] = informationRequest
  slots = .directory~new
  slots["origin"] = origin; slots["destination"] = destination
  slots["outboundDay"] = outboundDay; slots["outboundMonth"] = outboundMonth; slots["outboundYear"] = outboundYear; slots["outboundDate"] = self~outboundDate
  slots["passengers"] = passengers; slots["tripType"] = tripType
  slots["returnDay"] = returnDay; slots["returnMonth"] = returnMonth; slots["returnYear"] = returnYear; slots["returnDate"] = self~returnDate
  slots["bookingRef"] = bookingRef; slots["familyName"] = familyName
  slots["documentCountry"] = documentCountry; slots["travellerAge"] = travellerAge
  slots["companionChildMentioned"] = companionChildMentioned; slots["tobaccoForCompanion"] = tobaccoForCompanion
  d["slots"] = slots
  return d

::class FlyLoStructuredReplyFactory public
::method build class
  use arg utteranceIdArg, plan, frame, evidenceSource = "", modelId = "GROK_REALTIME"
  if plan == .nil | \plan~isa(.Directory) then return .FlyLoStructuredLanguageResult~failure("FLYLO_RESPONSE_PLAN_INVALID")
  if plan["schema"]~string <> .FlyLoStructuredLanguageBuild~RESPONSE_PLAN_SCHEMA then return .FlyLoStructuredLanguageResult~failure("FLYLO_RESPONSE_PLAN_SCHEMA_INVALID")
  text = strip(plan["text"]~string)
  if text = "" then return .FlyLoStructuredLanguageResult~failure("FLYLO_RESPONSE_TEXT_EMPTY")
  actKind = translate(strip(plan["communicativeAct"]~string))
  if wordpos(actKind, "GENERAL INFORMATION SERVICE_RESOLUTION APOLOGY REFUSAL SALESPROP") = 0 then return .FlyLoStructuredLanguageResult~failure("FLYLO_RESPONSE_ACT_INVALID", actKind)
  intendedAct = translate(strip(plan["intendedAct"]~string))
  intendedRegister = translate(strip(plan["intendedRegister"]~string))
  intendedOutcome = translate(strip(plan["intendedOutcome"]~string))
  if intendedAct = "" then return .FlyLoStructuredLanguageResult~failure("FLYLO_RESPONSE_INTENT_EMPTY")
  if intendedRegister = "" then intendedRegister = "HELPFUL"
  if intendedOutcome = "" then intendedOutcome = "CUSTOMER_INFORMED"

  utteranceId = utteranceIdArg~string
  u = .StructuredUtterance~new(utteranceId, "AGENT", "FLYLO_CHAT")
  dataRole = "NONE"; privacy = "DERIVED_NONCUSTOMER"; abstractText = ""
  frameHasCustomerContext = .false
  if frame \== .nil then if frame~isa(.FlyLoLanguageFrame) then do
    if frame~intent = "BOOK_JOURNEY" | frame~intent = "MANAGE_BOOKING" | frame~origin <> "" | frame~destination <> "" | frame~bookingRef <> "" | frame~documentCountry <> "" then frameHasCustomerContext = .true
  end
  if frameHasCustomerContext then do
    dataRole = "CUSTDATA"; privacy = "CUSTOMER_SPECIFIC"; abstractText = "[CUSTOMER_TRAVEL_RESPONSE]"
  end
  segmentId = utteranceId || "-SEG1"
  segment = .StructuredUtteranceSegment~new(segmentId, text, actKind, dataRole, privacy, abstractText)
  lineageIds = .array~new
  if frameHasCustomerContext then do
    edgeId = utteranceId || "-LINEAGE-CUSTOMER"
    edge = .UtteranceLineageEdge~new(edgeId, "DERIVED_FROM_CUSTOMER_FACT", "ASSISTANT_SESSION_FRAME", "CUSTOMER_SPECIFIC", "CUSTOMER_SPECIFIC", "SYSTEM", "FLYLO_STRUCTURED_ORCHESTRATOR", 100)
    segment~addLineage(edge); lineageIds~append(edgeId)
  end
  if evidenceSource~string <> "" then do
    edgeId = utteranceId || "-LINEAGE-AUTHORITY"
    edge = .UtteranceLineageEdge~new(edgeId, "DERIVED_FROM_EXTERNAL_DATA", evidenceSource, "ORGANISATION", "ORGANISATION", "SYSTEM", "FLYLO_AUTHORITY", 100)
    segment~addLineage(edge); lineageIds~append(edgeId)
    if privacy = "DERIVED_NONCUSTOMER" then do
      segment = .StructuredUtteranceSegment~new(segmentId, text, actKind, dataRole, "ORGANISATION", abstractText)
      segment~addLineage(edge)
    end
  end
  sr = segment~seal
  if \sr~ok then return .FlyLoStructuredLanguageResult~failure(sr~code, sr~detail)
  u~addSegment(segment)

  actId = utteranceId || "-ACT1"
  act = .UtteranceCommunicativeAct~new(actId, actKind, "MODEL", modelId, 100)
  act~addSegmentId(segmentId)
  ar = act~seal
  if \ar~ok then return .FlyLoStructuredLanguageResult~failure(ar~code, ar~detail)
  u~addAct(act)

  useIds = .array~new
  do i = 1 to lineageIds~items
    edgeId = lineageIds[i]; role = "SERVICE_REASON"
    if edgeId~pos("AUTHORITY") > 0 then role = "EVIDENCE"
    useId = utteranceId || "-USE" || i
    ue = .UtteranceInformationUseEdge~new(useId, segmentId, edgeId, actId, role, "SERVICE_RESOLUTION", "SYSTEM", "FLYLO_STRUCTURED_ORCHESTRATOR", 100)
    ue~seal; u~addInformationUse(ue); useIds~append(useId)
  end

  intentId = utteranceId || "-INTENT1"
  gi = .UtteranceGenerationIntent~new(intentId, actId, intendedAct, intendedRegister, intendedOutcome, "MODEL", modelId, 100)
  do useId over useIds; gi~addInformationUseId(useId); end
  gi~addConstraint("AIRLINE_AUTHORITY_OUTSIDE_MODEL")
  gi~addConstraint("STRUCTURED_BEFORE_FLATTENING")
  gi~addConstraint("MODEL_OUTPUT_JSON_SCHEMA_CONSTRAINED")
  gi~seal; u~addGenerationIntent(gi)
  u~addSpeechAct(actKind); u~addContextTag("FLYLO_ASSISTANT")
  if evidenceSource~string <> "" then u~addContextTag("AUTHORITY_EVIDENCE")
  sealed = u~seal
  if \sealed~ok then return .FlyLoStructuredLanguageResult~failure(sealed~code, sealed~detail)
  delivery = .StructuredUtteranceRenderer~renderDelivery(u)
  if \delivery~ok then return .FlyLoStructuredLanguageResult~failure(delivery~code, delivery~detail)

  summary = .directory~new
  summary["schema"] = .StructuredUtteranceBuild~API_VERSION
  summary["utteranceId"] = u~utteranceId
  summary["sealed"] = u~sealed
  summary["communicativeAct"] = actKind
  summary["intendedAct"] = intendedAct
  summary["intendedRegister"] = intendedRegister
  summary["intendedOutcome"] = intendedOutcome
  summary["lineageCount"] = lineageIds~items
  summary["text"] = delivery~value
  summary["canonicalText"] = u~canonicalText
  return .FlyLoStructuredLanguageResult~success(summary)

::requires "StructuredUtterance.cls"
