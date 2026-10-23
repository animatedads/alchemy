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
