/* InitechHelpDesk.cls
 * Two-tier Initech help desk:
 *   chat/help-desk intention -> live NotNotes application semantics -> domain action
 *
 * Discovery is dynamic on every turn. No permanent TPS action catalogue is kept.
 * The current NotNotes definitions, reports and documents are authoritative.
 */

::class InitechHelpDeskSession public

::method init
  expose app inner actor llm sessionId turnCount successCount failureCount transcript closed discoveryGeneration instrumentationProvider instrumentationPublisher instrumentationRef
  use strict arg dataRoot, actorArg="codex", llmArg=.nil
  actor = actorArg~string~strip
  if actor = "" then actor = "codex"
  llm = llmArg
  app = .MiniNotesApp~new(dataRoot)
  self~ensureBusinessLogFormat

  /* dev5: instrument the live NotNotes application through the estate-wide
   * Instrumentation Mesh, then expose that evidence through the read-only
   * Instrumentation Intentions specialist.  The Help Desk gains no telemetry
   * mutation/control authority. */
  identity = .InstrumentationCodec~identity("initech", "notnotes", "helpdesk", "local", "", "APPLICATION")
  instrumentationRef = identity["semantic_ref"]
  source = .MiniNotesInstrumentationSource~new(app, identity)
  registry = .InstrumentationRegistry~new
  registry~register("notnotes", source)
  service = .InstrumentationService~new(registry)
  collector = .InstrumentationCollector~new(32)
  collectorService = .InstrumentationCollectorService~new(collector)
  transport = .InstrumentationLocalCollectorTransport~new(collectorService, "initech-helpdesk")
  instrumentationPublisher = .InstrumentationPublisher~new("initech-helpdesk-notnotes", service, transport, "collector")
  bindings = .InstrumentationSemanticBindingRegistry~new
  bindings~register(app, instrumentationRef, .Array~of("NOTNOTES", "TPS", "INITECH NOTNOTES"))
  instrumentationProvider = .InstrumentationIntentionProvider~new(collector, bindings)
  ignore = instrumentationPublisher~publish(self~instrumentationTimestamp)
  authorities = .Directory~new
  authorities["NOTNOTES_FIELD_WRITE"] = 1
  authorities["NOTNOTES_REFERRAL_CREATE"] = 1
  users = .Directory~new
  inner = .AlchemyNotNotesIntentionRuntime~new(app~node, users, authorities)
  sessionId = "TPS-HD-" || date("S") || "-" || changestr(":", time("N"), "")
  turnCount = 0
  successCount = 0
  failureCount = 0
  transcript = .Array~new
  closed = .false
  discoveryGeneration = 0

::attribute app get
::attribute inner get
::attribute sessionId get
::attribute discoveryGeneration get
::attribute successCount get
::attribute failureCount get
::attribute instrumentationProvider get
::attribute instrumentationRef get

::method discover
  expose app discoveryGeneration instrumentationProvider
  discoveryGeneration += 1
  self~refreshInstrumentation

  /* dev4 deliberately discovers through NotNotes' renderer-neutral semantic
   * application contract.  The Help Desk no longer reconstructs the installed
   * application from internal definition collections. */
  application = app~semanticApplicationProjection
  d = .Directory~new
  d["CONTRACT"] = application["CONTRACT"]
  d["REPORTS"] = application["REPORTS"]
  d["SURFACES"] = application["SURFACES"]
  d["ENTRY_POINTS"] = application["ENTRY_POINTS"]

  formats = .Array~new
  do surface over application["SURFACES"]
    if surface["KIND"] \= "DOCUMENT_FORMAT" then iterate
    one = .Directory~new
    one["IDENTITY"] = surface["ID"]
    one["NAME"] = surface["FORM_NAME"]
    formats~append(one)
  end
  d["FORMATS"] = formats

  /* Specialist discovery is live as well.  Keep the provider-owned surface
   * intact so later specialists can evolve without a Help Desk vocabulary copy. */
  specialists = .Array~new
  instrumentationSurface = instrumentationProvider~discover(.Directory~new)
  specialists~append(instrumentationSurface)
  d["SPECIALISTS"] = specialists
  d["GENERATION"] = discoveryGeneration
  return d

::method handle
  expose app inner actor llm turnCount successCount failureCount transcript closed instrumentationProvider
  use strict arg text
  if closed then return self~reply("CLOSED", "Session is already closed.", "SESSION_CLOSED")
  turnCount += 1
  text = text~string~strip
  transcript~append("USER: " || text)
  if text = "" then do
    failureCount += 1
    r = self~reply("CLARIFY", "What would you like me to do with the TPS material?", "CLARIFY")
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  discovery = self~discover
  upper = translate(text)

  if wordpos(upper, "BYE QUIT EXIT DONE") > 0 | upper = "END SESSION" then do
    closeResult = self~close
    r = self~reply("CLOSED", "TPS help-desk session recorded as " || closeResult["RATING"] || ". Report " || closeResult["TPS_KEY"] || ", review " || closeResult["REVIEW_KEY"] || ".", "END_SESSION")
    return r
  end

  /* Tier 1 chooses a broad support purpose from live application evidence. */
  if pos("LOG BUSINESS", upper) > 0 | pos("LOG THIS BUSINESS", upper) > 0 | pos("BUSINESS LOG", upper) > 0 then do
    r = self~logBusiness(text)
    if r["STATUS"] = "SUCCESS" then successCount += 1
    else failureCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  /* A specific TPS reference wins over a broad report-name match.  The
   * relationship traversal is still discovered from live NotNotes metadata. */
  if pos("CONSULT", upper) > 0 | pos("FINDING", upper) > 0 | pos("RECOMMEND", upper) > 0 then do
    tps = self~resolveTpsFromText(text)
    if tps \== .nil then do
      r = self~linkedTpsEvidence(tps)
      if r["STATUS"] = "SUCCESS" then successCount += 1
      else failureCount += 1
      transcript~append("HELPDESK: " || r["TEXT"])
      return r
    end
  end

  /* Ask the live semantic document projection what can currently be done.
   * Meaning and feasibility stay separate: disabled actions remain understood
   * and carry the reason supplied by NotNotes. */
  if pos("WHAT CAN I DO", upper) > 0 | pos("WHAT CAN BE DONE", upper) > 0 | pos("CAN I APPROVE", upper) > 0 | pos("CAN I SUBMIT", upper) > 0 | pos("CAN I REJECT", upper) > 0 then do
    document = self~resolveDocumentFromText(text)
    if document \== .nil then do
      r = self~semanticDocumentHelp(document, upper)
      if r["STATUS"] = "SUCCESS" then successCount += 1
      else failureCount += 1
      transcript~append("HELPDESK: " || r["TEXT"])
      return r
    end
  end

  if pos("WHAT REPORT", upper) > 0 & (pos("AVAILABLE", upper) > 0 | pos("HAVE", upper) > 0) then do
    r = self~availableReports(discovery["REPORTS"])
    successCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  /* Help Desk TPS process reports are ordinary live NotNotes TPS documents.
   * A later session can therefore review earlier support-process success/failure
   * without a separate audit database or frozen chatbot catalogue. */
  if pos("TPS-HD-", upper) > 0 | (pos("HELP DESK", upper) > 0 & pos("TPS", upper) > 0 & (pos("PROCESS", upper) > 0 | pos("SESSION", upper) > 0)) then do
    r = self~helpDeskProcessHistory(text, upper)
    if r["STATUS"] = "SUCCESS" then successCount += 1
    else failureCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  reportName = self~matchReport(discovery["REPORTS"], upper)
  if reportName <> "" then do
    personal = pos(" MY ", " " || upper || " ") > 0
    r = self~runSavedReport(reportName, personal)
    if r["STATUS"] = "SUCCESS" then successCount += 1
    else failureCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  /* Read-only operational specialist.  Relevance and evidence belong to the
   * Instrumentation Intentions provider, not to a Help Desk metric vocabulary.
   * Business/report/document intents get first refusal; specialist discovery
   * then handles operational questions over the same live application. */
  instrumentationSurface = discovery["SPECIALISTS"][1]
  instrumentationAssessment = instrumentationProvider~assessRelevance(text, instrumentationSurface, .Directory~new)
  if instrumentationAssessment~relevant then do
    r = self~formatInstrumentation(instrumentationAssessment)
    successCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  /* Tier 2: hand document meaning to the live NotNotes intention runtime. */
  innerText = text
  if pos("REVIEW", upper) > 0 & pos("TPS", upper) > 0 then innerText = "show TPS Report Review"
  else if pos("TPS", upper) > 0 & (pos("SHOW", upper) > 0 | pos("LIST", upper) > 0 | pos("FIND", upper) > 0) then innerText = "show TPS Report"
  decision = inner~input(innerText)
  if decision~status = "READY" then do
    payload = inner~dispatch(decision)
    r = self~formatInnerResult(decision, payload)
    successCount += 1
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end
  if decision~status = "CLARIFY" | decision~status = "CONFIRM" | decision~status = "INFEASIBLE" then do
    failureCount += 1
    r = self~reply(decision~status, self~decisionMessage(decision), "NOTNOTES_" || decision~status)
    transcript~append("HELPDESK: " || r["TEXT"])
    return r
  end

  if llm \== .nil then do
    llmText = self~llmClassify(text, discovery)
    if llmText <> "" then do
      decision = inner~input(llmText)
      if decision~status = "READY" then do
        payload = inner~dispatch(decision)
        r = self~formatInnerResult(decision, payload)
        successCount += 1
        transcript~append("HELPDESK: " || r["TEXT"])
        return r
      end
    end
  end

  failureCount += 1
  r = self~reply("UNKNOWN", "I could not bind that request to the current NotNotes TPS application. The live reports and document definitions were re-discovered for this turn.", "UNKNOWN")
  transcript~append("HELPDESK: " || r["TEXT"])
  return r

::method matchReport private
  use strict arg reports, upperText
  bestName = ""
  bestScore = 0
  do report over reports
    score = 0
    name = translate(report["NAME"])
    source = translate(report["SOURCE_FORM"])
    do i = 1 to name~words
      token = name~word(i)
      if token~length > 2 then if pos(token, upperText) > 0 then score += 3
    end
    do i = 1 to source~words
      token = source~word(i)
      if token~length > 2 then if pos(token, upperText) > 0 then score += 2
    end
    if pos("REPORT", upperText) > 0 then score += 1
    if pos("REVIEW", upperText) > 0 & pos("REVIEW", source) > 0 then score += 7
    if pos("REVIEW", upperText) = 0 & (pos("REVIEW", source) > 0 | pos("REVIEW", name) > 0) then score -= 8
    if pos("SUMMARY", upperText) > 0 & pos("SUMMARY", name) > 0 then score += 5
    if pos("MY", upperText) > 0 & source = "TPS REPORT" then score += 5
    if score > bestScore then do
      bestScore = score
      bestName = report["NAME"]
    end
  end
  if bestScore < 4 then return ""
  return bestName

::method runSavedReport private
  expose app actor
  use strict arg reportName, personal=.false
  definition = app~reportDefinition(reportName)
  if definition == .nil then return self~reply("FAILURE", "The report disappeared after discovery; please retry.", "REPORT_CAPABILITY_CHANGED")
  docs = app~reportDocuments(definition)
  selected = .Array~new
  do document over docs
    include = .true
    if personal then include = self~ownedByActor(document, definition["SOURCE_FORM"])
    if include then selected~append(document)
  end
  text = reportName~upper || "0a"x || "Rows: " || selected~items || "0a"x
  columns = definition["COLUMNS"]
  do document over selected
    line = ""
    do column over columns
      if line <> "" then line = line || " | "
      line = line || app~reportValue(document, column["BINDING"])
    end
    text = text || line || "0a"x
  end
  totals = definition["TOTALS"]
  do binding over totals
    total = 0
    valid = .true
    do document over selected
      value = app~reportValue(document, binding)
      if \value~datatype("N") then do; valid = .false; leave; end
      total += value
    end
    if valid then text = text || "TOTAL " || binding || ": " || total || "0a"x
  end
  r = self~reply("SUCCESS", text, "RUN_REPORT")
  r["REPORT_NAME"] = reportName
  r["COUNT"] = selected~items
  return r

::method ownedByActor private
  expose app actor
  use strict arg document, sourceForm
  if sourceForm = "TPS Report" then return translate(app~reportValue(document, "User")) = translate(actor)
  if sourceForm = "TPS Report Review" then do
    ref = document~field("TheTPSReport")
    if ref == .nil then return .false
    target = app~byKey(ref~string)
    if target == .nil then return .false
    return translate(app~reportValue(target, "User")) = translate(actor)
  end
  return .true

::method ensureBusinessLogFormat private
  expose app
  if app~userFormatCanonicalName("Business Log") <> "" then return .true
  specs = .Array~new
  specs~append(self~fieldSpec("Summary", "Summary", "TEXT"))
  specs~append(self~fieldSpec("Details", "Details", "TEXT"))
  specs~append(self~fieldSpec("User", "User", "USER_REFERENCE"))
  specs~append(self~fieldSpec("Outcome", "Outcome", "TEXT"))
  ignore = app~installUserFormat("Business Log", specs)
  return .true

::method fieldSpec private
  use strict arg name,label,type
  d=.Directory~new; d["NAME"]=name; d["LABEL"]=label; d["TYPE"]=type; return d

::method logBusiness private
  expose app actor
  use strict arg text
  specs = app~userFormatFields("Business Log")
  if specs~items = 0 then return self~reply("FAILURE", "Business Log is not currently installed in NotNotes.", "BUSINESS_LOG_UNAVAILABLE")
  details = text
  marker = translate(text)
  p = pos("LOG BUSINESS", marker)
  if p > 0 then details = strip(substr(text, p + length("LOG BUSINESS")))
  if details = "" then details = text
  values = .Directory~new
  values["Summary"] = details
  values["Details"] = text
  values["User"] = actor
  values["Outcome"] = "LOGGED"
  document = app~createUserDocument("Business Log", specs, values)
  if document == .nil then return self~reply("FAILURE", "NotNotes could not create the Business Log document.", "BUSINESS_LOG_FAILED")
  r = self~reply("SUCCESS", "Business logged as " || document~DocKey || ": " || details, "LOG_BUSINESS")
  r["DOCUMENT_KEY"] = document~DocKey
  return r

::method resolveTpsFromText private
  expose app
  use strict arg text
  upper = translate(text)
  do document over app~allDocuments
    if document~formName \= "TPS Report" then iterate
    if pos(translate(document~DocKey~string), upper) > 0 then return document
    number = app~reportValue(document, "TPSNumber")
    if number \== .nil then if number~string \= "" then if pos(translate(number~string), upper) > 0 then return document
  end
  return .nil

::method helpDeskProcessHistory private
  expose app actor
  use strict arg text, upperText
  ratingFilter = ""
  if pos("FAIL", upperText) > 0 then ratingFilter = "FAILURE"
  else if pos("SUCCESS", upperText) > 0 then ratingFilter = "SUCCESS"
  personal = pos(" MY ", " " || upperText || " ") > 0
  dateFilter = ""
  if pos("YESTERDAY", upperText) > 0 then dateFilter = date("S", date("B") - 1, "B")
  else if pos("TODAY", upperText) > 0 then dateFilter = date("S")

  targetNumber = ""
  do document over app~allDocuments
    if document~formName \= "TPS Report" then iterate
    number = app~reportValue(document, "TPSNumber")
    if number == .nil then iterate
    number = number~string
    if left(translate(number), 7) \= "TPS-HD-" then iterate
    if pos(translate(number), upperText) > 0 then do
      targetNumber = number
      leave
    end
  end

  rows = .Array~new
  do document over app~allDocuments
    if document~formName \= "TPS Report" then iterate
    number = app~reportValue(document, "TPSNumber")
    if number == .nil then iterate
    number = number~string
    if left(translate(number), 7) \= "TPS-HD-" then iterate
    if targetNumber <> "" & translate(number) \= translate(targetNumber) then iterate
    if dateFilter <> "" then if pos("TPS-HD-" || dateFilter || "-", translate(number)) \= 1 then iterate
    if personal then do
      owner = app~reportValue(document, "User")
      if owner == .nil then iterate
      if translate(owner~string) \= translate(actor) then iterate
    end

    related = self~relatedDocumentsTo(document, "TPS Report Review")
    if related~items = 0 then iterate
    do relation over related
      review = relation["DOCUMENT"]
      ratingField = self~semanticFieldName(review~formName, "RATING")
      reviewField = self~semanticFieldName(review~formName, "REVIEW")
      rating = ""
      reviewText = ""
      if ratingField <> "" then do
        value = review~field(ratingField)
        if value \== .nil then rating = value~string
      end
      if reviewField <> "" then do
        value = review~field(reviewField)
        if value \== .nil then reviewText = value~string
      end
      if ratingFilter <> "" & translate(rating) \= ratingFilter then iterate
      row = .Directory~new
      row["TPS"] = document
      row["REVIEW"] = review
      row["TPS_NUMBER"] = number
      row["RATING"] = rating
      row["REVIEW_TEXT"] = reviewText
      rows~append(row)
    end
  end

  if rows~items = 0 then do
    if targetNumber <> "" then return self~reply("INFEASIBLE", "The Help Desk TPS process " || targetNumber || " exists or was referenced, but no matching live linked review is currently available under the requested filters.", "HELPDESK_TPS_PROCESS_HISTORY")
    return self~reply("INFEASIBLE", "I understood the Help Desk TPS process request, but no live session TPS reports match the requested filters.", "HELPDESK_TPS_PROCESS_HISTORY")
  end

  out = "HELP DESK TPS PROCESS HISTORY" || "0a"x
  do row over rows
    tps = row["TPS"]
    owner = app~reportValue(tps, "User")
    out = out || row["TPS_NUMBER"] || " | user=" || owner || " | rating=" || row["RATING"] || " | review=" || row["REVIEW"]~DocKey || "0a"x
    if targetNumber <> "" then out = out || row["REVIEW_TEXT"] || "0a"x
  end
  r = self~reply("SUCCESS", out, "HELPDESK_TPS_PROCESS_HISTORY")
  r["COUNT"] = rows~items
  if targetNumber <> "" then r["TPS_NUMBER"] = targetNumber
  return r

::method relatedDocumentsTo private
  expose app
  use strict arg target, wantedFormat=""
  relatedDocs = .Array~new
  do formatName over app~userFormatNames
    if wantedFormat <> "" & translate(formatName) \= translate(wantedFormat) then iterate
    specs = app~userFormatFields(formatName)
    do spec over specs
      if translate(spec["TYPE"]) \= "DOCUMENT_REFERENCE" then iterate
      targetFormat = ""
      if spec~hasIndex("REF_TARGET") then targetFormat = spec["REF_TARGET"]
      if targetFormat <> "" then if translate(targetFormat) \= translate(target~formName) then iterate
      refField = spec["NAME"]
      do document over app~allDocuments
        if document~formName \= formatName then iterate
        ref = document~field(refField)
        if \self~referenceContains(ref, target~DocKey) then iterate
        one = .Directory~new
        one["DOCUMENT"] = document
        one["FORMAT"] = formatName
        one["REF_FIELD"] = refField
        relatedDocs~append(one)
      end
    end
  end
  return relatedDocs

::method referenceContains private
  use strict arg reference, wantedKey
  if reference == .nil then return .false
  if reference~isA(.Array) then do
    do item over reference
      if translate(item~string) = translate(wantedKey~string) then return .true
    end
    return .false
  end
  return translate(reference~string) = translate(wantedKey~string)

::method semanticFieldName private
  expose app
  use strict arg formatName, semanticWord
  semanticWord = translate(semanticWord)
  do spec over app~userFormatFields(formatName)
    label = ""
    name = ""
    if spec~hasIndex("LABEL") then label = spec["LABEL"]
    if spec~hasIndex("NAME") then name = spec["NAME"]
    if pos(semanticWord, translate(label || " " || name)) > 0 then return name
  end
  return ""

::method linkedTpsEvidence private
  expose app
  use strict arg tps
  lines = .Array~new
  relations = self~relatedDocumentsTo(tps)
  do relation over relations
    document = relation["DOCUMENT"]
    formatName = relation["FORMAT"]
    specs = app~userFormatFields(formatName)
    textFields = .Array~new
    do spec over specs
      type = translate(spec["TYPE"])
      label = translate(spec["LABEL"] || " " || spec["NAME"])
      if type = "TEXT" then if pos("FINDING", label) > 0 | pos("RECOMMEND", label) > 0 then textFields~append(spec["NAME"])
    end
    if textFields~items = 0 then iterate
    line = document~DocKey || " | " || formatName
    do fieldName over textFields
      value = document~field(fieldName)
      if value \== .nil then if value~string \= "" then line = line || "0a"x || fieldName || ": " || value~string
    end
    lines~append(line)
  end
  if lines~items = 0 then return self~reply("INFEASIBLE", "I understood the TPS reference, but the live NotNotes application currently has no linked consultant finding evidence for " || app~reportValue(tps, "TPSNumber") || ".", "LINKED_TPS_EVIDENCE")
  text = "Linked management evidence for " || app~reportValue(tps, "TPSNumber") || " (" || tps~DocKey || ")" || "0a"x
  do line over lines; text = text || line || "0a"x; end
  r = self~reply("SUCCESS", text, "LINKED_TPS_EVIDENCE")
  r["COUNT"] = lines~items
  r["TPS_KEY"] = tps~DocKey
  return r

::method resolveDocumentFromText private
  expose app
  use strict arg text
  upper = translate(text)
  do document over app~allDocuments
    if pos(translate(document~DocKey~string), upper) > 0 then return document
    projection = app~semanticDocumentProjection(document)
    do field over projection["FIELDS"]
      value = field["VALUE"]
      if value == .nil then iterate
      valueText = value~string
      if valueText = "" then iterate
      if field["SEMANTIC_TYPE"] = "IDENTIFIER" then if pos(translate(valueText), upper) > 0 then return document
    end
  end
  return .nil
