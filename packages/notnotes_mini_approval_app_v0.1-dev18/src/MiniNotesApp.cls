/* MiniNotesApp.cls
 * Small text-mode NotNotes application over ooRexx CLI UI semantic models.
 * Application/domain truth remains in NotNotes; CLI UI models only project it.
 */

::class MiniNotesApp public

::method init
  expose node reviewer selectedId currentRows trace userFormats reportDefinitions subviewDefinitions persistence restoring batchDepth batchDirty instrumentationSink timeGateway temporalEvidence
  use strict arg persistenceRoot = ""
  node = .AlchemyNotNotesNode~new("MININOTES")
  reviewer = .UserIdentity~new("codex", "Codex Reviewer")
  node~setCurrentUser(reviewer)
  selectedId = ""
  currentRows = .array~new
  trace = .CliUiSemanticTrace~new
  userFormats = .Directory~new
  reportDefinitions = .Directory~new
  subviewDefinitions = .Directory~new
  restoring = .true
  batchDepth = 0
  batchDirty = .false
  instrumentationSink = .nil
  timeGateway = .nil
  temporalEvidence = .Directory~new
  self~installDesign
  persistence = .MiniNotesPersistence~new(persistenceRoot)
  ignore = persistence~loadInto(self)
  restoring = .false

::method node
  expose node
  return node

::method trace
  expose trace
  return trace



::method instrumentation
  expose instrumentationSink
  use arg sink = .nil
  if arg() > 0 then instrumentationSink = sink
  return instrumentationSink

/* Inject the Time Service boundary used by DATE/DATETIME fields. */
::method timeService
  expose timeGateway
  use arg gateway = .nil
  if arg() > 0 then timeGateway = gateway
  return timeGateway

/* Return detached Time Service evidence for one accepted temporal field value. */
::method temporalEvidenceFor
  expose temporalEvidence
  use strict arg docKey, fieldName
  evidenceKey = docKey~string~upper || "1f"x || fieldName~string~upper
  if \\temporalEvidence~hasIndex(evidenceKey) then return .nil
  return temporalEvidence[evidenceKey]~copy

::method temporalEvidenceRecords
  expose temporalEvidence
  records = .Array~new
  do evidenceKey over temporalEvidence~allIndexes
    records~append(temporalEvidence[evidenceKey]~copy)
  end
  return records

::method recordTemporalEvidence
  expose temporalEvidence
  use strict arg docKey, fieldName, outcome
  evidenceKey = docKey~string~upper || "1f"x || fieldName~string~upper
  if outcome == .nil then do
    if temporalEvidence~hasIndex(evidenceKey) then ignore = temporalEvidence~remove(evidenceKey)
    return .true
  end
  if outcome["STATUS"] == "EMPTY" then do
    if temporalEvidence~hasIndex(evidenceKey) then ignore = temporalEvidence~remove(evidenceKey)
    return .true
  end
  evidence = .Directory~new
  evidence["DOC_KEY"] = docKey
  evidence["FIELD_NAME"] = fieldName
  do evidenceName over .Array~of("STATUS", "KIND", "VALUE", "ZONE", "INSTANT_POSIX_SECONDS", "TZDB_EDITION", "RESOLUTION")
    if outcome~hasIndex(evidenceName) then evidence[evidenceName] = outcome[evidenceName]
  end
  temporalEvidence[evidenceKey] = evidence
  return .true

::method restoreTemporalEvidence
  use strict arg record
  return self~recordTemporalEvidence(record["DOC_KEY"], record["FIELD_NAME"], record)


::method instrumentationEvent
  expose instrumentationSink
  use strict arg eventName, facts = .nil
  if instrumentationSink == .nil then return .false
  if \instrumentationSink~hasMethod("notNotesEvent") then return .false
  instrumentationSink~notNotesEvent(eventName, facts)
  return .true

::method persistence
  expose persistence
  return persistence

::method persistenceRoot
  expose persistence
  return persistence~root

::method persistNow
  expose persistence restoring batchDirty
  if restoring then return .false
  facts = .Directory~new
  facts["BATCH_DEPTH"] = self~batchDepth
  ignore = self~instrumentationEvent("PERSIST_BEGIN", facts)
  saveOk = persistence~saveFrom(self)
  if saveOk then do
    batchDirty = .false
    ignore = self~instrumentationEvent("PERSIST_COMPLETED", facts)
  end
  else ignore = self~instrumentationEvent("PERSIST_FAILED", facts)
  return saveOk

::method beginBatch
  expose batchDepth
  batchDepth = batchDepth + 1
  facts = .Directory~new
  facts["DEPTH"] = batchDepth
  ignore = self~instrumentationEvent("BATCH_BEGIN", facts)
  return batchDepth

::method endBatch
  expose batchDepth batchDirty
  if batchDepth <= 0 then raise syntax 93.900 array("endBatch without matching beginBatch")
  batchDepth = batchDepth - 1
  facts = .Directory~new
  facts["DEPTH"] = batchDepth
  ignore = self~instrumentationEvent("BATCH_END", facts)
  if batchDepth = 0 then do
    if batchDirty then return self~persistNow
  end
  return .true

::method batchDepth
  expose batchDepth
  return batchDepth

::method autoPersist
  expose restoring batchDepth batchDirty
  if restoring then return .false
  if batchDepth > 0 then do
    batchDirty = .true
    return .true
  end
  return self~persistNow

::method installDesign
  expose node
  app = .ApplicationDefinition~new("Mini Approval Notes", "1")

  generic = .DocumentDefinition~new("Approval Document", "1")
  generic~field("DocKey")~semanticType("IDENTIFIER")~intentionReadable(.true)~intentionSearchable(.true)
  generic~field("Title")~semanticType("TEXT")~alias("subject")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  generic~field("Amount")~semanticType("MONEY")~alias("value")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  generic~field("Risk")~semanticType("ENUM")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  generic~field("DependsOn")~semanticType("DOCUMENT_REFERENCE_LIST")~intentionReadable(.true)~intentionSearchable(.true)
  generic~field("Workflow")~semanticType("TEXT")~intentionReadable(.true)
  app~addDocumentDefinition(generic)

  purchase = .DocumentDefinition~new("Purchase Request", "1")
  purchase~field("DocKey")~semanticType("IDENTIFIER")~intentionReadable(.true)~intentionSearchable(.true)
  purchase~field("Title")~semanticType("TEXT")~alias("subject")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  purchase~field("Amount")~semanticType("MONEY")~alias("value")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  purchase~field("Risk")~semanticType("ENUM")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  purchase~field("DependsOn")~semanticType("DOCUMENT_REFERENCE_LIST")~intentionReadable(.true)~intentionSearchable(.true)
  purchase~field("Workflow")~semanticType("TEXT")~intentionReadable(.true)
  app~addDocumentDefinition(purchase)

  security = .DocumentDefinition~new("Security Review", "1")
  security~field("DocKey")~semanticType("IDENTIFIER")~intentionReadable(.true)~intentionSearchable(.true)
  security~field("Title")~semanticType("TEXT")~alias("subject")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  security~field("Amount")~semanticType("MONEY")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  security~field("Risk")~semanticType("ENUM")~alias("severity")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  security~field("DependsOn")~semanticType("DOCUMENT_REFERENCE_LIST")~intentionReadable(.true)~intentionSearchable(.true)
  security~field("Workflow")~semanticType("TEXT")~intentionReadable(.true)
  app~addDocumentDefinition(security)

  release = .DocumentDefinition~new("Release Authorization", "1")
  release~field("DocKey")~semanticType("IDENTIFIER")~intentionReadable(.true)~intentionSearchable(.true)
  release~field("Title")~semanticType("TEXT")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  release~field("Amount")~semanticType("MONEY")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  release~field("Risk")~semanticType("ENUM")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  release~field("DependsOn")~semanticType("DOCUMENT_REFERENCE_LIST")~intentionReadable(.true)~intentionSearchable(.true)
  release~field("Workflow")~semanticType("TEXT")~intentionReadable(.true)
  app~addDocumentDefinition(release)

  allView = .ViewDefinition~new("All Documents", "1")
  allView~column("Key", "DocKey")
  allView~column("Type", "formName")
  allView~column("Title")
  allView~column("Amount")
  allView~column("Risk")
  allView~sortBy("DocKey")
  app~addViewDefinition(allView)

  purchaseView = .ViewDefinition~new("Purchase Requests", "1", .Document~type("Purchase Request"))
  purchaseView~column("Key", "DocKey")
  purchaseView~column("Title")
  purchaseView~column("Amount")
  purchaseView~column("Risk")
  purchaseView~sortBy("DocKey")
  app~addViewDefinition(purchaseView)

  securityView = .ViewDefinition~new("Security Reviews", "1", .Document~type("Security Review"))
  securityView~column("Key", "DocKey")
  securityView~column("Title")
  securityView~column("Risk")
  securityView~sortBy("DocKey")
  app~addViewDefinition(securityView)

  releaseView = .ViewDefinition~new("Release Authorizations", "1", .Document~type("Release Authorization"))
  releaseView~column("Key", "DocKey")
  releaseView~column("Title")
  releaseView~column("Risk")
  releaseView~sortBy("DocKey")
  app~addViewDefinition(releaseView)

  approvalView = .ViewDefinition~new("Approval Documents", "1", .Document~type("Approval Document"))
  approvalView~column("Key", "DocKey")
  approvalView~column("Title")
  approvalView~sortBy("DocKey")
  app~addViewDefinition(approvalView)

  app~seal
  app~install(node)
  return self

::method seedFive
  expose node
  if node~documentIds~items > 0 then return self

  supplier = self~createDocument("Approval Document", "SUP-001", "Acme Components supplier onboarding", 0, "LOW", "")
  self~applyWorkflow(supplier)

  small = self~createDocument("Purchase Request", "PR-1001", "Developer workstation", 850, "LOW", "SUP-001")
  self~applyWorkflow(small)

  large = self~createDocument("Purchase Request", "PR-1002", "GPU build server", 4200, "MEDIUM", "SUP-001")
  self~applyWorkflow(large)

  security = self~createDocument("Security Review", "SEC-2001", "GPU build server security review", 0, "HIGH", "PR-1002")
  self~applyWorkflow(security)

  release = self~createDocument("Release Authorization", "REL-3001", "AI coding pilot release", 0, "MEDIUM", "PR-1002,SEC-2001")
  self~applyWorkflow(release)
  ignore = self~autoPersist
  return self

::method createDocument
  expose node
  use strict arg formName, docKey, title, amount=0, risk="LOW", dependsOn=""
  definitionIdentity = formName || "/1"
  document = node~compose(definitionIdentity)
  document~DocKey = docKey
  document~Title = title
  document~Amount = amount
  document~Risk = risk~string~upper
  document~DependsOn = dependsOn
  document~Workflow = "UNASSESSED"
  node~save(document)
  self~bindDependencies(document)
  return document

::method bindDependencies
  expose node
  use strict arg document
  text = document~DependsOn
  if text == .nil then return document
  text = text~string~strip
  if text = "" then return document
  ids = text~makeArray(",")
  do key over ids
    dependency = self~byKey(key~strip)
    if dependency \== .nil then document~linkDocument(dependency, "DEPENDS_ON")
  end
  node~save(document)
  return document

::method applyWorkflow
  expose node reviewer
  use strict arg document
  type = document~formName
  amount = document~Amount
  risk = document~Risk~string~upper

  if type = "Approval Document" then do
    document~Workflow = "AUTO: base evidence document"
    document~approval("base evidence", .true, "SIGN", "seed rule")
  end
  else if type = "Purchase Request" then do
    if amount <= 1000 then do
      document~Workflow = "AUTO: amount <= 1000"
      document~approval("purchase value threshold", .true, "SIGN", "amount <= 1000")
    end
    else do
      document~Workflow = "HUMAN: amount > 1000"
      document~approval("purchase value threshold", .false, "SIGN", "amount > 1000")
      document~refer(reviewer, "purchase amount exceeds automatic approval threshold")
    end
  end
  else if type = "Security Review" then do
    if risk = "LOW" then do
      document~Workflow = "AUTO: risk LOW"
      document~approval("security risk", .true, "SIGN", "risk LOW")
    end
    else do
      document~Workflow = "HUMAN: risk is " || risk
      document~approval("security risk", .false, "SIGN", "risk requires review")
      document~refer(reviewer, "security risk requires human review")
    end
  end
  else if type = "Release Authorization" then do
    document~Workflow = "HUMAN: release authorization"
    document~approval("release authorization", .false, "SIGN", "release requires reviewer")
    document~refer(reviewer, "release requires explicit approval")
  end
  node~save(document)
  return document

::method byKey
  expose node
  use arg wanted
  if wanted == .nil then return .nil
  wanted = wanted~string~strip~upper
  do document over node~documents
    if document~DocKey~string~upper = wanted then return document
  end
  return .nil

::method dependenciesSatisfied
  use strict arg document
  deps = document~DependsOn
  if deps == .nil then return .true
  deps = deps~string~strip
  if deps = "" then return .true
  keys = deps~makeArray(",")
  do key over keys
    dep = self~byKey(key~strip)
    if dep == .nil then return .false
    if dep~ApprovalStatus <> "APPROVED" then return .false
  end
  return .true

::method dependencyState
  use strict arg document
  deps = document~DependsOn
  if deps == .nil then return "-"
  deps = deps~string~strip
  if deps = "" then return "-"
  out = ""
  keys = deps~makeArray(",")
  do key over keys
    key = key~strip
    dep = self~byKey(key)
    state = "MISSING"
    if dep \== .nil then state = dep~ApprovalStatus
    if out <> "" then out = out || ", "
    out = out || key || "=" || state
  end
  return out

::method tableFor
  expose currentRows trace
  use strict arg documents
  columns = .array~of("#", "KEY", "TYPE", "TITLE", "STATUS", "DEPS")
  table = .CliUiTableModel~new(columns)
  currentRows = .array~new
  n = 0
  do document over documents
    n += 1
    currentRows~append(document~documentId)
    cells = .array~of(n, document~DocKey, document~formName, document~Title, document~ApprovalStatus, document~DependsOn)
    table~append(document~documentId, cells)
  end
  trace~record(.CliUiSemanticEvent~new("Project", "MiniNotes", "documents", "rows", n), "table")
  return table

::method allDocuments
  expose node
  docs = node~documents
  return self~sortByKey(docs)

::method viewDocuments
  expose node
  use strict arg viewText
  text = viewText~string~strip~lower
  viewIdentity = "All Documents/1"
  if text~pos("purchase") > 0 then viewIdentity = "Purchase Requests/1"
  else if text~pos("security") > 0 then viewIdentity = "Security Reviews/1"
  else if text~pos("release") > 0 then viewIdentity = "Release Authorizations/1"
  else if text~pos("approval document") > 0 | text~pos("supplier") > 0 then viewIdentity = "Approval Documents/1"

  base = .array~new
  do row over node~view(viewIdentity)
    document = row~document(node)
    if document \== .nil then base~append(document)
  end
  return self~filterDocuments(base, text)

::method query
  expose node
  use strict arg queryText
  selectedDocuments = self~filterDocuments(node~documents, queryText)
  facts = .Directory~new
  facts["RESULT_COUNT"] = selectedDocuments~items
  ignore = self~instrumentationEvent("QUERY_COMPLETED", facts)
  return selectedDocuments

::method filterDocuments
  use strict arg documents, queryText
  text = queryText~string~strip~lower
  searchTerms = self~freeTextTerms(text)
  selected = .array~new
  do document over documents
    if self~matchesStructuredQuery(document, text) then do
      if self~matchesFreeText(document, searchTerms) then selected~append(document)
    end
  end
  return self~sortByKey(selected)

::method matchesStructuredQuery
  use strict arg document, text
  if text~pos("purchase") > 0 then do
    if document~formName \= "Purchase Request" then return .false
  end
  if text~pos("security") > 0 then do
    if document~formName \= "Security Review" then return .false
  end
  if text~pos("release") > 0 then do
    if document~formName \= "Release Authorization" then return .false
  end
  if text~pos("approval document") > 0 then do
    if document~formName \= "Approval Document" then return .false
  end
  if text~pos("pending") > 0 then do
    if document~ApprovalStatus \= "PENDING APPROVAL" then return .false
  end
  if text~pos("approved") > 0 then do
    if document~ApprovalStatus \= "APPROVED" then return .false
  end
  if text~pos("rejected") > 0 then do
    if document~ApprovalStatus \= "REJECTED" then return .false
  end
  if text~pos("high risk") > 0 | text~pos("risk high") > 0 then do
    if document~Risk~string~upper \= "HIGH" then return .false
  end
  if text~pos("approvable") > 0 then do
    if document~ApprovalStatus \= "PENDING APPROVAL" then return .false
    if \self~dependenciesSatisfied(document) then return .false
  end
  threshold = self~numericThreshold(text, ">")
  if threshold \== .nil then do
    if document~Amount <= threshold then return .false
  end
  threshold = self~numericThreshold(text, "<")
  if threshold \== .nil then do
    if document~Amount >= threshold then return .false
  end
  return .true

::method freeTextTerms
  use strict arg text
  normalized = text~translate
  normalized = changestr(">", normalized, " ")
  normalized = changestr("<", normalized, " ")
  normalized = changestr("=", normalized, " ")
  normalized = changestr(",", normalized, " ")
  normalized = changestr("?", normalized, " ")
  normalized = changestr(".", normalized, " ")
  terms = .array~new
  do i = 1 to normalized~words
    word = normalized~word(i)
    if word~datatype("N") then iterate
    if self~queryGrammarWord(word) then iterate
    terms~append(word)
  end
  return terms

::method queryGrammarWord
  use strict arg word
  grammar = "QUERY VIEW SHOW FIND LIST ME DOCUMENT DOCUMENTS DOC DOCS WHERE WITH WHOSE THAT WHICH ARE IS THE A AN OF TYPE TYPES REQUEST REQUESTS REVIEW REVIEWS AUTHORIZATION AUTHORIZATIONS AND OR IN ON FOR TO FROM HAVE HAS APPROVAL PENDING APPROVED REJECTED APPROVABLE PURCHASE PURCHASES SECURITY RELEASE HIGH RISK AMOUNT VALUE OVER UNDER GREATER LESS THAN"
  return wordpos(word, grammar) > 0

::method matchesFreeText
  use strict arg document, terms
  if terms~items = 0 then return .true
  haystack = document~DocKey || " " || document~formName || " " || document~Title || " " || document~Risk || " " || document~DependsOn
  do fieldName over document~fieldNames
    fieldValue = document~field(fieldName)
    if fieldValue \== .nil then haystack = haystack || " " || fieldValue
  end
  haystack = haystack~string~upper
  do term over terms
    if haystack~pos(term) = 0 then return .false
  end
  return .true

::method numericThreshold
  use strict arg text, operator
  p = text~pos(operator)
  if p = 0 then return .nil
  tail = text~substr(p + 1)~strip
  token = tail~word(1)
  if token~datatype("N") then return token
  return .nil

::method sortByKey
  use strict arg documents
  /* Native sort of string keys: preserve duplicate-key documents without
   * quadratic comparisons or changing domain/document authority. */
  keys = .Array~new
  buckets = .Table~new
  do document over documents
    key = document~DocKey~string
    if \buckets~hasIndex(key) then do
      buckets[key] = .Array~new
      keys~append(key)
    end
    buckets[key]~append(document)
  end
  keys~sort
  out = .Array~new
  do key over keys
    do document over buckets[key]
      out~append(document)
    end
  end
  return out

::method select
  expose selectedId currentRows trace
  use strict arg selector
  selector = selector~string~strip
  document = .nil
  if selector~datatype("W") then do
    n = selector
    if n >= 1 then do
      if n <= currentRows~items then document = self~node~document(currentRows[n])
    end
  end
  if document == .nil then document = self~byKey(selector)
  if document == .nil then return .nil
  selectedId = document~documentId
  trace~record(.CliUiSemanticEvent~new("Select", "MiniNotes", document~DocKey), "document")
  return document

::method selected
  expose selectedId node
  if selectedId = "" then return .nil
  return node~document(selectedId)

::method documentModel
  use strict arg document
  text = "KEY: " || document~DocKey || "0a"x || -
         "TYPE: " || document~formName || "0a"x || -
         "TITLE: " || document~Title || "0a"x || -
         "AMOUNT: " || document~Amount || "0a"x || -
         "RISK: " || document~Risk || "0a"x || -
         "STATUS: " || document~ApprovalStatus || "0a"x || -
         "WORKFLOW: " || document~Workflow || "0a"x || -
         "DEPENDS ON: " || document~DependsOn || "0a"x || -
         "DEPENDENCY STATE: " || self~dependencyState(document) || "0a"x || -
         "REVISION: " || document~revision
  return .CliUiDocument~new(text, "plain")


/* Return the renderer-neutral application projection contract.  Consumers such
 * as CLI UI, Wire/Win32, mobile and future renderers should project these
 * semantics rather than inventing business navigation or lifecycle state. */
::method semanticApplicationProjection
  model = .Directory~new
  model["CONTRACT"] = "MININOTES.SEMANTIC_APPLICATION/1"
  model["APPLICATION_ID"] = "MININOTES"
  model["TITLE"] = "Mini NotNotes"
  model["SURFACES"] = self~semanticSurfaces
  model["REPORTS"] = self~semanticReportDescriptors
  entryPoints = .Array~new
  entry = .Directory~new
  entry["ID"] = "intentions"
  entry["KIND"] = "INTENTION_ENTRY"
  entry["LABEL"] = "Ask NotNotes"
  entry["ACTION"] = "SUBMIT_INTENTION"
  entryPoints~append(entry)
  model["ENTRY_POINTS"] = entryPoints
  return model

/* Discover application navigation from installed NotNotes definitions. */
::method semanticSurfaces
  expose node userFormats reportDefinitions
  surfaces = .Array~new

  surface = .Directory~new
  surface["ID"] = "documents"
  surface["KIND"] = "DOCUMENT_COLLECTION"
  surface["LABEL"] = "Documents"
  surfaces~append(surface)

  surface = .Directory~new
  surface["ID"] = "approvals"
  surface["KIND"] = "DOCUMENT_COLLECTION"
  surface["LABEL"] = "Approvals"
  surface["STATUS_FILTER"] = "PENDING APPROVAL"
  surfaces~append(surface)

  do definitionId over node~viewDefinitionIds
    definition = node~viewDefinition(definitionId)
    if definition == .nil then iterate
    surface = .Directory~new
    surface["ID"] = "view:" || definition~identity
    surface["KIND"] = "VIEW"
    surface["LABEL"] = definition~name
    surface["DEFINITION_ID"] = definition~identity
    surfaces~append(surface)
  end

  do formatKey over userFormats~allIndexes
    formatRecord = userFormats[formatKey]
    surface = .Directory~new
    surface["ID"] = "format:" || formatRecord["NAME"]
    surface["KIND"] = "DOCUMENT_FORMAT"
    surface["LABEL"] = formatRecord["NAME"]
    surface["FORM_NAME"] = formatRecord["NAME"]
    surfaces~append(surface)
  end

  if reportDefinitions~items > 0 then do
    surface = .Directory~new
    surface["ID"] = "reports"
    surface["KIND"] = "REPORT_COLLECTION"
    surface["LABEL"] = "Reports"
    surfaces~append(surface)
  end

  return surfaces

/* Resolve one semantic surface to the authoritative document population. */
::method semanticSurfaceDocuments
  expose node
  use strict arg surfaceId
  wanted = surfaceId~string~strip
  if wanted~lower = "documents" then return self~allDocuments
  if wanted~lower = "approvals" then do
    matches = .Array~new
    do document over self~allDocuments
      if document~ApprovalStatus = "PENDING APPROVAL" then matches~append(document)
    end
    return matches
  end
  if wanted~lower~left(7) = "format:" then do
    formName = wanted~substr(8)
    matches = .Array~new
    do document over self~allDocuments
      if document~formName~upper = formName~upper then matches~append(document)
    end
    return matches
  end
  if wanted~lower~left(5) = "view:" then do
    definitionId = wanted~substr(6)
    definition = node~viewDefinition(definitionId)
    if definition == .nil then return .Array~new
    return node~view(definitionId)
  end
  return .Array~new

/* Return a bounded, renderer-neutral window over one document collection. */
::method semanticCollectionRange
  use strict arg surfaceId, start = 0, count = 50
  if \datatype(start, "W") then raise syntax 93.900 array("collection range start must be a whole number")
  if \datatype(count, "W") then raise syntax 93.900 array("collection range count must be a whole number")
  if start < 0 then raise syntax 93.900 array("collection range start must not be negative")
  if count < 1 then raise syntax 93.900 array("collection range count must be positive")
  if count > 100 then raise syntax 93.900 array("collection range count must not exceed 100")

  documents = self~semanticSurfaceDocuments(surfaceId)
  projection = .Directory~new
  projection["CONTRACT"] = "MININOTES.SEMANTIC_COLLECTION/1"
  projection["SURFACE_ID"] = surfaceId
  projection["START"] = start
  projection["TOTAL"] = documents~items
  rows = .Array~new
  first = start + 1
  last = start + count
  if last > documents~items then last = documents~items
  if first <= last then do index = first to last
    document = documents[index]
    row = .Directory~new
    row["IDENTITY"] = document~documentId
    row["KEY"] = document~DocKey
    row["FORM"] = document~formName
    row["TITLE"] = document~Title
    row["STATUS"] = document~ApprovalStatus
    row["REVISION"] = document~revision
    rows~append(row)
  end
  projection["COUNT"] = rows~items
  projection["ROWS"] = rows
  return projection

/* Describe one live document without introducing renderer toolkit concepts. */
::method semanticDocumentProjection
  use strict arg document
  if document == .nil then return .nil
  model = .Directory~new
  model["CONTRACT"] = "MININOTES.SEMANTIC_DOCUMENT/1"
  model["IDENTITY"] = document~documentId
  model["KEY"] = document~DocKey
  model["FORM"] = document~formName
  model["TITLE"] = document~Title
  model["STATUS"] = document~ApprovalStatus
  model["REVISION"] = document~revision
  model["FIELDS"] = self~semanticFieldDescriptors(document)
  model["ACTIONS"] = self~semanticActionDescriptors(document)
  model["SUBVIEWS"] = self~semanticSubviewDescriptors(document)
  return model

/* Project document field meaning, capability and relationship metadata. */
::method semanticFieldDescriptors
  use strict arg document
  fields = .Array~new
  do fieldName over document~fieldNames
    descriptor = .Directory~new
    descriptor["NAME"] = fieldName
    descriptor["LABEL"] = self~semanticFieldLabel(document~formName, fieldName)
    fieldDefinition = document~fieldObject(fieldName)
    if fieldDefinition == .nil then do
      descriptor["SEMANTIC_TYPE"] = "TEXT"
      descriptor["CARDINALITY"] = "ONE"
      descriptor["READABLE"] = .true
      descriptor["WRITABLE"] = .true
      descriptor["SEARCHABLE"] = .true
      descriptor["COMPUTED"] = .false
      descriptor["PROCESS_OWNER"] = ""
    end
    else do
      descriptor["SEMANTIC_TYPE"] = fieldDefinition~semanticType
      descriptor["CARDINALITY"] = fieldDefinition~cardinality
      descriptor["READABLE"] = fieldDefinition~intentionReadable
      descriptor["WRITABLE"] = fieldDefinition~intentionWritable
      descriptor["SEARCHABLE"] = fieldDefinition~intentionSearchable
      descriptor["COMPUTED"] = fieldDefinition~computed
      descriptor["PROCESS_OWNER"] = fieldDefinition~processOwner
    end
    spec = self~userFormatFieldSpec(document~formName, fieldName)
    if spec \== .nil then do
      if spec~hasIndex("RESULT_TYPE") then descriptor["RESULT_TYPE"] = spec["RESULT_TYPE"]
      if spec~hasIndex("TIME_ZONE") then descriptor["TIME_ZONE"] = spec["TIME_ZONE"]
      if spec~hasIndex("AMBIGUITY_POLICY") then descriptor["AMBIGUITY_POLICY"] = spec["AMBIGUITY_POLICY"]
    end
    descriptor["VALUE"] = document~field(fieldName)
    temporal = self~temporalEvidenceFor(document~DocKey, fieldName)
    if temporal \\== .nil then descriptor["TEMPORAL_EVIDENCE"] = temporal
    target = self~relationshipTarget(document~formName, fieldName)
    descriptor["REFERENCE_TARGET"] = target
    if target <> "" then descriptor["CARDINALITY"] = self~relationshipCardinality(document~formName, fieldName)
    fields~append(descriptor)
  end
  return fields

/* Return a human-facing field label from installed user-format metadata. */
::method semanticFieldLabel
  use strict arg formName, fieldName
  spec = self~userFormatFieldSpec(formName, fieldName)
  if spec \== .nil then return spec["LABEL"]
  select
    when fieldName~upper = "DOCKEY" then return "Key"
    when fieldName~upper = "DEPENDSON" then return "Depends on"
    when fieldName~upper = "APPROVALSTATUS" then return "Status"
    otherwise return fieldName
  end

/* Describe currently feasible lifecycle operations without performing them. */
::method semanticActionDescriptors
  expose reviewer
  use strict arg document
  actions = .Array~new
  actions~append(self~semanticAction("PRINT", "Print", .true, ""))

  submitEnabled = document~ApprovalStatus = "DRAFT"
  submitReason = ""
  if \submitEnabled then submitReason = "Document is not DRAFT"
  else if \self~dependenciesSatisfied(document) then do
    submitEnabled = .false
    submitReason = "Dependencies are not approved"
  end
  actions~append(self~semanticAction("SUBMIT", "Submit for approval", submitEnabled, submitReason))

  decisionEnabled = document~ApprovalStatus = "PENDING APPROVAL"
  decisionReason = ""
  if \decisionEnabled then decisionReason = "Document is not pending approval"
  else if \self~dependenciesSatisfied(document) then do
    decisionEnabled = .false
    decisionReason = "Dependencies are not approved"
  end
  else if document~Referrals~item(reviewer~identity) == .nil then do
    decisionEnabled = .false
    decisionReason = "Current reviewer has no referral"
  end
  actions~append(self~semanticAction("APPROVE", "Approve", decisionEnabled, decisionReason))
  actions~append(self~semanticAction("REJECT", "Reject", decisionEnabled, decisionReason))
  return actions

/* Construct one renderer-neutral action descriptor. */
::method semanticAction
  use strict arg actionId, label, enabled, reason
  action = .Directory~new
  action["ID"] = actionId
  action["LABEL"] = label
  action["ENABLED"] = enabled
  action["REASON"] = reason
  return action

/* Describe subviews as semantic child collections, not rendered text. */
::method semanticSubviewDescriptors
  use strict arg document
  out = .Array~new
  do definition over self~subviewDefinitionsFor(document~formName)
    descriptor = .Directory~new
    descriptor["NAME"] = definition["NAME"]
    descriptor["SOURCE_FORM"] = definition["SOURCE_FORM"]
    descriptor["LINK_FIELD"] = definition["LINK_FIELD"]
    descriptor["ROWS"] = self~subviewRows(document, definition)
    descriptor["ROW_CALCULATIONS"] = self~copySubviewSpecs(definition["ROW_CALCS"])
    descriptor["COLUMN_CALCULATIONS"] = self~copySubviewSpecs(definition["COLUMN_CALCS"])
    out~append(descriptor)
  end
  return out

/* Describe installed saved reports for non-CLI consumers. */
::method semanticReportDescriptors
  expose reportDefinitions
  out = .Array~new
  do key over reportDefinitions~allIndexes
    definition = reportDefinitions[key]
    descriptor = .Directory~new
    descriptor["NAME"] = definition["NAME"]
    descriptor["SOURCE_FORM"] = definition["SOURCE_FORM"]
    descriptor["COLUMNS"] = self~copyReportColumns(definition["COLUMNS"])
    descriptor["TOTALS"] = definition["TOTALS"]~copy
    out~append(descriptor)
  end
  return out

::method submitSelected
  expose node reviewer trace
  use strict arg note="submitted for approval"
  document = self~selected
  if document == .nil then do
    ignore = self~instrumentationEvent("SUBMIT_REJECTED")
    return "NO_DOCUMENT_SELECTED"
  end
  if document~ApprovalStatus <> "DRAFT" then do
    ignore = self~instrumentationEvent("SUBMIT_REJECTED")
    return "NOT_DRAFT"
  end
  if \self~dependenciesSatisfied(document) then do
    ignore = self~instrumentationEvent("SUBMIT_REJECTED")
    return "DEPENDENCIES_NOT_APPROVED"
  end
  document~approval("submitted for approval", .false, "SIGN", note)
  document~refer(reviewer, note)
  node~save(document)
  trace~record(.CliUiSemanticEvent~new("Submit", "MiniNotes", document~DocKey), document~ApprovalStatus)
  ignore = self~autoPersist
  facts = .Directory~new
  facts["FORM"] = document~formName
  ignore = self~instrumentationEvent("SUBMIT_COMPLETED", facts)
  return document~ApprovalStatus

::method decideSelected
  expose node reviewer trace
  use strict arg outcome, note=""
  document = self~selected
  if document == .nil then do
    ignore = self~instrumentationEvent("DECISION_REJECTED")
    return "NO_DOCUMENT_SELECTED"
  end
  if document~ApprovalStatus <> "PENDING APPROVAL" then do
    ignore = self~instrumentationEvent("DECISION_REJECTED")
    return "NOT_PENDING"
  end
  if \self~dependenciesSatisfied(document) then do
    ignore = self~instrumentationEvent("DECISION_REJECTED")
    return "DEPENDENCIES_NOT_APPROVED"
  end
  referral = document~Referrals~item(reviewer~identity)
  if referral == .nil then do
    ignore = self~instrumentationEvent("DECISION_REJECTED")
    return "NO_REVIEW_REFERRAL"
  end
  decisionOutcome = outcome~string~upper
  if decisionOutcome = "APPROVE" then decisionOutcome = "APPROVED"
  if decisionOutcome = "REJECT" then decisionOutcome = "REJECTED"
  node~decideReferral(document, decisionOutcome, note)
  trace~record(.CliUiSemanticEvent~new("Decision", "MiniNotes", document~DocKey, "outcome", outcome), document~ApprovalStatus)
  ignore = self~autoPersist
  facts = .Directory~new
  facts["OUTCOME"] = decisionOutcome
  facts["FORM"] = document~formName
  ignore = self~instrumentationEvent("DECISION_COMPLETED", facts)
  return document~ApprovalStatus

::method createFromCommand
  use strict arg command
  parts = command~makeArray("|")
  if parts~items < 3 then return .nil
  kind = parts[1]~strip~lower
  title = parts[2]~strip
  value = parts[3]~strip
  depends = ""
  if parts~items >= 4 then depends = parts[4]~strip

  if kind = "purchase" then do
    if \value~datatype("N") then return .nil
    key = self~nextKey("PR-")
    document = self~createDocument("Purchase Request", key, title, value, "LOW", depends)
  end
  else if kind = "security" then do
    key = self~nextKey("SEC-")
    document = self~createDocument("Security Review", key, title, 0, value~upper, depends)
  end
  else if kind = "release" then do
    key = self~nextKey("REL-")
    document = self~createDocument("Release Authorization", key, title, 0, value~upper, depends)
  end
  else return .nil

  self~applyWorkflow(document)
  ignore = self~autoPersist
  return document


::method installUserFormat
  expose node userFormats
  use strict arg formatName, fieldSpecs
  definition = .DocumentDefinition~new(formatName, "1")
  definition~field("DocKey")~semanticType("IDENTIFIER")~intentionReadable(.true)~intentionSearchable(.true)
  definition~field("Title")~semanticType("TEXT")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  definition~field("Amount")~semanticType("MONEY")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  definition~field("Risk")~semanticType("ENUM")~intentionReadable(.true)~intentionWritable(.true)~intentionSearchable(.true)
  definition~field("DependsOn")~semanticType("DOCUMENT_REFERENCE_LIST")~intentionReadable(.true)~intentionSearchable(.true)
  definition~field("Workflow")~semanticType("TEXT")~intentionReadable(.true)
  do spec over fieldSpecs
    field = definition~field(spec["NAME"])
    field~semanticType(spec["TYPE"])
    field~alias(spec["LABEL"])
    field~intentionReadable(.true)
    if spec["TYPE"]~upper = "CALCULATED" then field~computed(.true)
    else field~intentionWritable(.true)
    field~intentionSearchable(.true)
    if spec~hasIndex("CARDINALITY") then field~cardinality(spec["CARDINALITY"])
  end
  node~registerDocumentDefinition(definition)

  view = .ViewDefinition~new(formatName || "s", "1", .Document~type(formatName))
  view~column("Key", "DocKey")
  view~column("Title", "Title")
  do spec over fieldSpecs
    view~column(spec["LABEL"], spec["NAME"])
  end
  view~sortBy("DocKey")
  node~registerViewDefinition(view)
  record = .Directory~new
  record~put(formatName, "NAME")
  record~put(self~copyFieldSpecs(fieldSpecs), "FIELDS")
  userFormats~put(record, formatName~upper)
  definitionObject = node~documentDefinition(formatName || "/1")
  ignore = self~autoPersist
  facts = .Directory~new
  facts["FORMAT"] = formatName
  ignore = self~instrumentationEvent("FORMAT_INSTALLED", facts)
  return definitionObject

::method copyFieldSpecs
  use strict arg fieldSpecs
  out = .Array~new
  do spec over fieldSpecs
    copy = .Directory~new
    copy~put(spec["NAME"], "NAME")
    copy~put(spec["LABEL"], "LABEL")
    copy~put(spec["TYPE"], "TYPE")
    if spec~hasIndex("REF_TARGET") then copy~put(spec["REF_TARGET"], "REF_TARGET")
    if spec~hasIndex("CARDINALITY") then copy~put(spec["CARDINALITY"], "CARDINALITY")
    if spec~hasIndex("CALC_EXPR") then copy~put(spec["CALC_EXPR"], "CALC_EXPR")
    if spec~hasIndex("RESULT_TYPE") then copy~put(spec["RESULT_TYPE"], "RESULT_TYPE")
    if spec~hasIndex("TIME_ZONE") then copy~put(spec["TIME_ZONE"], "TIME_ZONE")
    if spec~hasIndex("AMBIGUITY_POLICY") then copy~put(spec["AMBIGUITY_POLICY"], "AMBIGUITY_POLICY")
    out~append(copy)
  end
  return out

::method userFormatNames
  expose userFormats
  names = .array~new
  do key over userFormats
    names~append(userFormats[key]["NAME"])
  end
  return names

::method userFormatFields
  expose userFormats
  use strict arg formatName
  key = formatName~string~upper
  if userFormats~hasIndex(key) = 0 then return .Array~new
  return self~copyFieldSpecs(userFormats[key]["FIELDS"])

::method userFormatCanonicalName
  expose userFormats
  use strict arg formatName
  key = formatName~string~upper
  if userFormats~hasIndex(key) = 0 then return ""
  return userFormats[key]["NAME"]

::method userFormatFieldSpec
  use strict arg formatName, fieldName
  wanted = fieldName~string~upper
  do spec over self~userFormatFields(formatName)
    if spec["NAME"]~string~upper = wanted then return spec
    if spec["LABEL"]~string~upper = wanted then return spec
  end
  return .nil

::method evolveUserFormat
  expose node
  use strict arg formatName, fieldSpecs
  outcome = .Directory~new
  canonical = self~userFormatCanonicalName(formatName)
  if canonical = "" then do
    outcome["STATUS"] = "NOT_FOUND"
    outcome["DETAIL"] = "Unknown user document format: " || formatName
    return outcome
  end

  oldFields = self~userFormatFields(canonical)
  if fieldSpecs~items < oldFields~items then do
    outcome["STATUS"] = "NON_ADDITIVE_CHANGE"
    outcome["DETAIL"] = "Existing fields cannot be removed by additive evolution."
    return outcome
  end

  do i = 1 to oldFields~items
    oldSpec = oldFields[i]
    newSpec = fieldSpecs[i]
    if self~sameFieldContract(oldSpec, newSpec) = 0 then do
      outcome["STATUS"] = "NON_ADDITIVE_CHANGE"
      outcome["DETAIL"] = "Existing field contract changed: " || oldSpec["LABEL"]
      return outcome
    end
  end

  seen = .Directory~new
  do spec over fieldSpecs
    fieldKey = spec["NAME"]~string~upper
    if seen~hasIndex(fieldKey) then do
      outcome["STATUS"] = "DUPLICATE_FIELD"
      outcome["DETAIL"] = "Duplicate field: " || spec["LABEL"]
      return outcome
    end
    seen[fieldKey] = .true
  end

  ignore = self~beginBatch
  ignore = self~installUserFormat(canonical, fieldSpecs)
  migratedValues = .Array~new
  do document over self~allDocuments
    if document~formName \= canonical then iterate
    do i = oldFields~items + 1 to fieldSpecs~items
      spec = fieldSpecs[i]
      if document~hasField(spec["NAME"]) then iterate
      self~installFieldOnDocument(document, spec, "")
      migratedValues~append(document~DocKey || ":" || spec["NAME"])
    end
    node~save(document)
  end
  ignore = self~endBatch

  outcome["STATUS"] = "OK"
  outcome["DETAIL"] = "Evolved " || canonical || "."
  outcome["ADDED_FIELDS"] = fieldSpecs~items - oldFields~items
  outcome["MIGRATED_VALUES"] = migratedValues~items
  facts = .Directory~new
  facts["FORMAT"] = canonical
  facts["ADDED_FIELDS"] = outcome["ADDED_FIELDS"]
  facts["MIGRATED_VALUES"] = outcome["MIGRATED_VALUES"]
  ignore = self~instrumentationEvent("FORMAT_EVOLVED", facts)
  return outcome

::method sameFieldContract
  use strict arg leftSpec, rightSpec
  if leftSpec["NAME"]~string~upper \= rightSpec["NAME"]~string~upper then return .false
  if leftSpec["LABEL"]~string \= rightSpec["LABEL"]~string then return .false
  if leftSpec["TYPE"]~string~upper \= rightSpec["TYPE"]~string~upper then return .false
  keys = .array~of("REF_TARGET", "CARDINALITY", "CALC_EXPR", "RESULT_TYPE", "TIME_ZONE", "AMBIGUITY_POLICY")
  do key over keys
    leftValue = ""
    rightValue = ""
    if leftSpec~hasIndex(key) then leftValue = leftSpec[key]~string
    if rightSpec~hasIndex(key) then rightValue = rightSpec[key]~string
    if leftValue~upper \= rightValue~upper then return .false
  end
  return .true

::method installFieldOnDocument
  use strict arg document, spec, value = ""
  field = document~defineField(spec["NAME"])
  field~semanticType(spec["TYPE"])
  field~alias(spec["LABEL"])
  field~intentionReadable(.true)
  if spec["TYPE"]~string~upper = "CALCULATED" then field~computed(.true)
  else field~intentionWritable(.true)
  field~intentionSearchable(.true)
  if spec~hasIndex("CARDINALITY") then field~cardinality(spec["CARDINALITY"])
  document~putField(spec["NAME"], value)
  return field

::method setUserDocumentField
  expose node
  use strict arg document, fieldName, supplied
  if document == .nil then return .false
  spec = self~userFormatFieldSpec(document~formName, fieldName)
  if spec == .nil then return .false
  if spec["TYPE"]~string~upper = "CALCULATED" then return .false

  value = supplied
  semanticType = spec["TYPE"]~string~upper
  if semanticType = "MONEY" | semanticType = "NUMBER" then do
    if value~string~strip <> "" then if \value~string~datatype("N") then return .false
  end
  temporalOutcome = .nil
  if semanticType = "DATE" | semanticType = "DATETIME" then do
    temporalOutcome = self~normalizeTemporalField(spec, value)
    if temporalOutcome == .nil then return .false
    value = temporalOutcome["VALUE"]
  end
  if semanticType = "DOCUMENT_REFERENCE" then do
    targetForm = ""
    if spec~hasIndex("REF_TARGET") then targetForm = spec["REF_TARGET"]
    cardinality = "ONE"
    if spec~hasIndex("CARDINALITY") then cardinality = spec["CARDINALITY"]~string~upper
    if cardinality = "MANY" then do
      resolvedKeys = .Array~new
      do requested over self~parseReferenceInputs(value)
        target = self~resolveDocumentReference(targetForm, requested)
        if target == .nil then return .false
        if self~arrayContainsCaseless(resolvedKeys, target~DocKey) = 0 then resolvedKeys~append(target~DocKey)
      end
      value = self~encodeReferenceKeys(resolvedKeys)
    end
    else do
      if value~string~strip <> "" then do
        target = self~resolveDocumentReference(targetForm, value)
        if target == .nil then return .false
        value = target~DocKey
      end
      else value = ""
    end
  end

  document~putField(spec["NAME"], value)
  if temporalOutcome \\== .nil then ignore = self~recordTemporalEvidence(document~DocKey, spec["NAME"], temporalOutcome)
  node~save(document)
  ignore = self~autoPersist
  return .true

/* Validate temporal values through the injected Single Time Service boundary.
 * DATE remains a civil date. DATETIME remains floating unless TIME_ZONE is declared.
 * Zoned folds/gaps fail closed unless the format declares an ambiguity policy. */
::method normalizeTemporalField
  expose timeGateway
  use strict arg spec, supplied
  if timeGateway == .nil then return .nil
  semanticType = spec["TYPE"]~string~upper
  if semanticType == "DATE" then outcome = timeGateway~normalizeDate(supplied)
  else do
    zone = ""
    policy = ""
    if spec~hasIndex("TIME_ZONE") then zone = spec["TIME_ZONE"]
    if spec~hasIndex("AMBIGUITY_POLICY") then policy = spec["AMBIGUITY_POLICY"]
    outcome = timeGateway~normalizeDateTime(supplied, zone, policy)
  end
  if outcome["STATUS"] == "VALID" then return outcome
  if outcome["STATUS"] == "EMPTY" then return outcome
  return .nil

::method normalizeTemporalFieldValue
  use strict arg spec, supplied
  outcome = self~normalizeTemporalField(spec, supplied)
  if outcome == .nil then return .nil
  return outcome["VALUE"]

::method createUserDocument
  expose node
  use strict arg formatName, fieldSpecs, values
  definitionIdentity = formatName || "/1"
  if node~documentDefinition(definitionIdentity) == .nil then return .nil
  document = node~compose(definitionIdentity)
  key = self~nextKey(self~formatPrefix(formatName))
  document~DocKey = key
  title = formatName || " " || key
  if fieldSpecs~items > 0 then do
    firstName = fieldSpecs[1]["NAME"]
    if values~hasIndex(firstName) then title = formatName || " " || values[firstName]
  end
  document~Title = title
  document~Amount = 0
  document~Risk = "LOW"
  document~DependsOn = ""
  document~Workflow = "USER FORMAT"
  pendingTemporal = .Array~new
  do spec over fieldSpecs
    name = spec["NAME"]
    if spec["TYPE"]~upper = "CALCULATED" then iterate
    value = ""
    if values~hasIndex(name) then value = values[name]
    if spec["TYPE"]~upper = "DATE" | spec["TYPE"]~upper = "DATETIME" then do
      temporalOutcome = self~normalizeTemporalField(spec, value)
      if temporalOutcome == .nil then return .nil
      value = temporalOutcome["VALUE"]
      pending = .Directory~new
      pending["FIELD_NAME"] = name
      pending["OUTCOME"] = temporalOutcome
      pendingTemporal~append(pending)
    end
    if spec["TYPE"]~upper = "DOCUMENT_REFERENCE" then do
      targetForm = ""
      if spec~hasIndex("REF_TARGET") then targetForm = spec["REF_TARGET"]
      cardinality = "ONE"
      if spec~hasIndex("CARDINALITY") then cardinality = spec["CARDINALITY"]~string~upper
      if cardinality = "MANY" then do
        suppliedReferences = self~parseReferenceInputs(value)
        resolvedKeys = .Array~new
        do suppliedReference over suppliedReferences
          resolved = self~resolveDocumentReference(targetForm, suppliedReference)
          if resolved == .nil then return .nil
          if self~arrayContainsCaseless(resolvedKeys, resolved~DocKey) = 0 then resolvedKeys~append(resolved~DocKey)
        end
        value = self~encodeReferenceKeys(resolvedKeys)
      end
      else do
        resolved = self~resolveDocumentReference(targetForm, value)
        if resolved == .nil then return .nil
        value = resolved~DocKey
      end
    end
    document~send(name || "=", value)
  end
  do pending over pendingTemporal
    ignore = self~recordTemporalEvidence(document~DocKey, pending["FIELD_NAME"], pending["OUTCOME"])
  end
  node~save(document)
  ignore = self~autoPersist
  return document

::method documentFormatCanonicalName
  use strict arg requested
  value = requested~string~strip
  canonical = self~userFormatCanonicalName(value)
  if canonical <> "" then return canonical
  identity = value || "/1"
  definition = self~node~documentDefinition(identity)
  if definition \== .nil then return value
  return ""

::method resolveDocumentReference
  use strict arg targetForm, supplied
  wanted = supplied~string~strip
  if wanted = "" then return .nil
  do document over self~allDocuments
    if targetForm <> "" then if document~formName \= targetForm then iterate
    if document~DocKey~string~caselessCompareTo(wanted) = 0 then return document
    do fieldName over document~fieldNames
      value = document~field(fieldName)
      if value == .nil then iterate
      if value~string~caselessCompareTo(wanted) = 0 then return document
    end
  end
  return .nil

::method parseReferenceInputs
  use strict arg supplied
  out = .Array~new
  if supplied == .nil then return out
  if supplied~isA(.Array) then do item over supplied
    value = item~string~strip
    if value <> "" then out~append(value)
  end
  else do
    text = supplied~string
    text = text~changestr("0d0a"x, "0a"x)
    text = text~changestr("0d"x, "0a"x)
    text = text~changestr("0a"x, ",")
    text = text~changestr(";", ",")
    rest = text
    do while rest <> ""
      parse var rest item "," rest
      item = item~strip
      if item <> "" then out~append(item)
    end
  end
  return out

::method arrayContainsCaseless
  use strict arg values, wanted
  do item over values
    if item~string~caselessCompareTo(wanted~string) = 0 then return 1
  end
  return 0

::method encodeReferenceKeys
  use strict arg keys
  out = ""
  do key over keys
    if out <> "" then out = out || "1f"x
    out = out || key~string
  end
  return out

::method decodeReferenceKeys
  use strict arg encoded
  out = .Array~new
  if encoded == .nil then return out
  rest = encoded~string
  if rest = "" then return out
  do while rest <> ""
    separator = rest~pos("1f"x)
    if separator = 0 then do
      key = rest~strip
      rest = ""
    end
    else do
      key = rest~left(separator - 1)~strip
      rest = rest~substr(separator + 1)
    end
    if key <> "" then out~append(key)
  end
  return out

::method referencedDocuments
  use strict arg document, fieldName
  out = .Array~new
  fieldValue = document~field(fieldName)
  if fieldValue == .nil then return out
  cardinality = self~relationshipCardinality(document~formName, fieldName)
  if cardinality = "MANY" then keys = self~decodeReferenceKeys(fieldValue)
  else keys = .Array~of(fieldValue~string)
  do key over keys
    target = self~byKey(key)
    if target \== .nil then out~append(target)
  end
  return out

::method referencedDocument
  use strict arg document, fieldName
  targets = self~referencedDocuments(document, fieldName)
  if targets~items = 0 then return .nil
  return targets[1]

::method addDocumentReference
  expose node
  use strict arg document, fieldName, supplied
  targetForm = self~relationshipTarget(document~formName, fieldName)
  if targetForm = "" then return .false
  target = self~resolveDocumentReference(targetForm, supplied)
  if target == .nil then return .false
  cardinality = self~relationshipCardinality(document~formName, fieldName)
  if cardinality = "MANY" then do
    keys = self~decodeReferenceKeys(document~field(fieldName))
    if self~arrayContainsCaseless(keys, target~DocKey) = 0 then keys~append(target~DocKey)
    value = self~encodeReferenceKeys(keys)
  end
  else value = target~DocKey
  document~send(fieldName || "=", value)
  node~save(document)
  ignore = self~autoPersist
  return .true

::method removeDocumentReference
  expose node
  use strict arg document, fieldName, supplied
  targetForm = self~relationshipTarget(document~formName, fieldName)
  if targetForm = "" then return .false
  target = self~resolveDocumentReference(targetForm, supplied)
  wantedKey = supplied~string~strip
  if target \== .nil then wantedKey = target~DocKey
  cardinality = self~relationshipCardinality(document~formName, fieldName)
  if cardinality = "MANY" then do
    oldKeys = self~decodeReferenceKeys(document~field(fieldName))
    keys = .Array~new
    removed = .false
    do key over oldKeys
      if key~string~caselessCompareTo(wantedKey) = 0 then removed = .true
      else keys~append(key)
    end
    if \removed then return .false
    value = self~encodeReferenceKeys(keys)
  end
  else do
    current = document~field(fieldName)
    if current == .nil then return .false
    if current~string~caselessCompareTo(wantedKey) \= 0 then return .false
    value = ""
  end
  document~send(fieldName || "=", value)
  node~save(document)
  ignore = self~autoPersist
  return .true

::method relationshipCardinality
  use strict arg formName, fieldName
  fields = self~userFormatFields(formName)
  wanted = fieldName~string~upper
  do spec over fields
    if spec["NAME"]~upper \= wanted then iterate
    if spec["TYPE"]~upper \= "DOCUMENT_REFERENCE" then return ""
    if spec~hasIndex("CARDINALITY") then return spec["CARDINALITY"]~string~upper
    return "ONE"
  end
  return ""

::method relationshipTarget
  use strict arg formName, fieldName
  fields = self~userFormatFields(formName)
  wanted = fieldName~string~upper
  do spec over fields
    if spec["NAME"]~upper \= wanted then iterate
    if spec["TYPE"]~upper \= "DOCUMENT_REFERENCE" then return ""
    if spec~hasIndex("REF_TARGET") then return spec["REF_TARGET"]
    return ""
  end
  return ""

::method installSubviewDefinition
  expose subviewDefinitions
  use strict arg parentForm, subviewName, sourceForm, linkField, columns, rowCalculations=.nil, columnCalculations=.nil
  if rowCalculations == .nil then rowCalculations = .Array~new
  if columnCalculations == .nil then columnCalculations = .Array~new
  record = .Directory~new
  record["PARENT_FORM"] = parentForm
  record["NAME"] = subviewName
  record["SOURCE_FORM"] = sourceForm
  record["LINK_FIELD"] = linkField
  record["COLUMNS"] = self~copySubviewSpecs(columns)
  record["ROW_CALCS"] = self~copySubviewSpecs(rowCalculations)
  record["COLUMN_CALCS"] = self~copySubviewSpecs(columnCalculations)
  subviewDefinitions[parentForm~upper || ":" || subviewName~upper] = record
  ignore = self~autoPersist
  return record

::method copySubviewSpecs
  use strict arg specs
  out = .Array~new
  do spec over specs
    copy = .Directory~new
    do key over spec
      copy[key] = spec[key]
    end
    out~append(copy)
  end
  return out

::method subviewDefinitionsFor
  expose subviewDefinitions
  use strict arg parentForm
  out = .Array~new
  prefix = parentForm~upper || ":"
  do key over subviewDefinitions
    if key~left(prefix~length) = prefix then out~append(subviewDefinitions[key])
  end
  return out

::method subviewDefinitionNames
  expose subviewDefinitions
  out = .Array~new
  do key over subviewDefinitions
    record = subviewDefinitions[key]
    out~append(record["PARENT_FORM"] || ":" || record["NAME"])
  end
  return out

::method subviewDefinitionByIdentity
  expose subviewDefinitions
  use strict arg identity
  key = identity~string~upper
  if subviewDefinitions~hasIndex(key) = 0 then return .nil
  return subviewDefinitions[key]

::method subviewRows
  use strict arg parentDocument, subviewDefinition
  rows = .Array~new
  sourceForm = subviewDefinition["SOURCE_FORM"]
  linkField = subviewDefinition["LINK_FIELD"]
  do child over self~allDocuments
    if child~formName \= sourceForm then iterate
    linkValue = child~field(linkField)
    if linkValue == .nil then iterate
    if self~relationshipCardinality(sourceForm, linkField) = "MANY" then do
      linkedKeys = self~decodeReferenceKeys(linkValue)
      if self~arrayContainsCaseless(linkedKeys, parentDocument~DocKey) = 0 then iterate
    end
    else if linkValue~string~upper \= parentDocument~DocKey~string~upper then iterate
    rows~append(self~subviewRow(child, subviewDefinition))
  end
  return rows

::method subviewRow
  use strict arg child, subviewDefinition
  row = .Directory~new
  do column over subviewDefinition["COLUMNS"]
    row[column["NAME"]] = self~resolveValuePath(child, column["BINDING"])
  end
  do calc over subviewDefinition["ROW_CALCS"]
    row[calc["NAME"]] = self~evaluateRowExpression(child, calc["EXPR"])
  end
  row["__DOCUMENT_KEY"] = child~DocKey
  return row

::method resolveValuePath
  use strict arg document, path
  current = document
  rest = path~string~strip
  do while rest <> ""
    parse var rest part "." rest
    part = part~strip
    if part = "" then iterate
    if current == .nil then return ""
    if current~isA(.Document) then do
      fieldName = part
      wantedField = self~normalizeSemanticLabel(part)
      do spec over self~userFormatFields(current~formName)
        if self~normalizeSemanticLabel(spec["LABEL"]) = wantedField | self~normalizeSemanticLabel(spec["NAME"]) = wantedField then do
          fieldName = spec["NAME"]
          leave
        end
      end
      target = self~relationshipTarget(current~formName, fieldName)
      if target <> "" then do
        if self~relationshipCardinality(current~formName, fieldName) = "MANY" then do
          targets = self~referencedDocuments(current, fieldName)
          values = .Array~new
          do targetDocument over targets
            if rest = "" then values~append(targetDocument~DocKey)
            else values~append(self~resolveValuePath(targetDocument, rest))
          end
          return self~joinValues(values, ", ")
        end
        current = self~referencedDocument(current, fieldName)
      end
      else current = current~field(fieldName)
    end
    else return ""
  end
  if current == .nil then return ""
  if current~isA(.Document) then return current~DocKey
  return current

::method evaluateRowExpression
  use strict arg document, expression
  text = expression~string~strip
  multiplyPos = text~pos("*")
  if multiplyPos > 0 then do
    leftPath = text~left(multiplyPos - 1)~strip
    rightPath = text~substr(multiplyPos + 1)~strip
    leftValue = self~resolveValuePath(document, leftPath)
    rightValue = self~resolveValuePath(document, rightPath)
    if \leftValue~string~datatype("N") then return ""
    if \rightValue~string~datatype("N") then return ""
    return leftValue * rightValue
  end
  return self~resolveValuePath(document, text)

::method subviewColumnValue
  use strict arg rows, subviewDefinition, calculationName
  wanted = calculationName~string~upper
  do calc over subviewDefinition["COLUMN_CALCS"]
    if calc["NAME"]~upper \= wanted then iterate
    operation = calc["OP"]~upper
    source = calc["SOURCE"]
    if operation = "SUM" then do
      total = 0
      do row over rows
        if row~hasIndex(source) then do
          value = row[source]
          if value~string~datatype("N") then total = total + value
        end
      end
      return total
    end
    if operation = "COUNT" then return rows~items
  end
  return ""

::method joinValues
  use strict arg values, separator
  out = ""
  do value over values
    if value~string = "" then iterate
    if out <> "" then out = out || separator
    out = out || value~string
  end
  return out

::method renderReferencesFor
  use strict arg document
  out = ""
  fields = self~userFormatFields(document~formName)
  do spec over fields
    if spec["TYPE"]~upper \= "DOCUMENT_REFERENCE" then iterate
    targets = self~referencedDocuments(document, spec["NAME"])
    if targets~items = 0 then iterate
    out = out || "--- from " || spec["LABEL"] || " ---" || "0a"x
    do target over targets
      out = out || target~DocKey || " | " || target~Title || "0a"x
      targetFields = self~userFormatFields(target~formName)
      do targetSpec over targetFields
        value = target~field(targetSpec["NAME"])
        if value == .nil then value = ""
        out = out || targetSpec["LABEL"] || ": " || value || "0a"x
      end
    end
  end
  return out

::method renderSubviewsFor
  use strict arg parentDocument
  out = ""
  do definition over self~subviewDefinitionsFor(parentDocument~formName)
    rows = self~subviewRows(parentDocument, definition)
    out = out || "--- " || definition["NAME"] || " ---" || "0a"x
    headers = .Array~new
    do column over definition["COLUMNS"]
      headers~append(column["LABEL"])
    end
    do calc over definition["ROW_CALCS"]
      headers~append(calc["LABEL"])
    end
    headerLine = ""
    do header over headers
      if headerLine <> "" then headerLine = headerLine || " | "
      headerLine = headerLine || header
    end
    out = out || headerLine || "0a"x
    do row over rows
      line = ""
      do column over definition["COLUMNS"]
        if line <> "" then line = line || " | "
        line = line || row[column["NAME"]]
      end
      do calc over definition["ROW_CALCS"]
        if line <> "" then line = line || " | "
        line = line || row[calc["NAME"]]
      end
      out = out || line || "0a"x
    end
    do calc over definition["COLUMN_CALCS"]
      out = out || calc["LABEL"] || ": " || self~subviewColumnValue(rows, definition, calc["NAME"]) || "0a"x
    end
  end
  return out

::method formatPrefix
  use strict arg formatName
  prefix = ""
  do i = 1 to formatName~words
    word = formatName~word(i)
    if word <> "" then prefix = prefix || word~left(1)~upper
  end
  if prefix = "" then prefix = "DOC"
  if prefix~length < 2 then prefix = prefix || "D"
  return prefix || "-"

::method nextKey
  use strict arg prefix
  max = 0
  do document over self~node~documents
    key = document~DocKey~string~upper
    if key~left(prefix~length) <> prefix then iterate
    n = key~substr(prefix~length + 1)
    if n~datatype("W") then if n > max then max = n
  end
  return prefix || (max + 1)~right(4, "0")


::method restoreDocumentRecord
  expose node
  use strict arg record
  definitionIdentity = record["FORM_NAME"] || "/1"
  if node~documentDefinition(definitionIdentity) == .nil then return .nil
  document = node~compose(definitionIdentity)
  document~DocKey = record["DOC_KEY"]
  document~Title = record["TITLE"]
  document~Amount = record["AMOUNT"]
  document~Risk = record["RISK"]
  document~DependsOn = record["DEPENDS_ON"]
  document~Workflow = record["WORKFLOW"]
  fields = record["FIELDS"]
  if fields \== .nil then do fieldName over fields
    document~send(fieldName || "=", fields[fieldName])
  end
  node~save(document)
  return document

::method restoreDocumentState
  expose node reviewer
  use strict arg record, document = .nil
  if document == .nil then document = self~byKey(record["DOC_KEY"])
  if document == .nil then return .false
  ignore = self~bindDependencies(document)
  formName = document~formName
  wantedStatus = record["STATUS"]~string~upper
  if formName = "Approval Document" | formName = "Purchase Request" | formName = "Security Review" | formName = "Release Authorization" then do
    ignore = self~applyWorkflow(document)
    if document~ApprovalStatus = "PENDING APPROVAL" then do
      if wantedStatus = "APPROVED" | wantedStatus = "REJECTED" then do
        outcome = wantedStatus
        ignore = node~decideReferral(document, outcome, "restored durable decision")
      end
    end
  end
  else do
    if wantedStatus = "PENDING APPROVAL" | wantedStatus = "APPROVED" | wantedStatus = "REJECTED" then do
      document~approval("submitted for approval", .false, "SIGN", "restored durable submission")
      document~refer(reviewer, "restored durable submission")
      node~save(document)
      if wantedStatus = "APPROVED" | wantedStatus = "REJECTED" then do
        ignore = node~decideReferral(document, wantedStatus, "restored durable decision")
      end
    end
  end
  return .true


::method installReportDefinition
  expose reportDefinitions
  use strict arg reportName, sourceForm, columns, totals=.nil
  if totals == .nil then totals = .Array~new
  record = .Directory~new
  record["NAME"] = reportName
  record["SOURCE_FORM"] = sourceForm
  record["COLUMNS"] = self~copyReportColumns(columns)
  record["TOTALS"] = totals~copy
  reportDefinitions[reportName~upper] = record
  ignore = self~autoPersist
  return record

::method copyReportColumns
  use strict arg columns
  out = .Array~new
  do column over columns
    copy = .Directory~new
    copy["LABEL"] = column["LABEL"]
    copy["BINDING"] = column["BINDING"]
    out~append(copy)
  end
  return out

::method reportDefinitionNames
  expose reportDefinitions
  out = .Array~new
  do key over reportDefinitions
    out~append(reportDefinitions[key]["NAME"])
  end
  return out

::method reportDefinition
  expose reportDefinitions
  use strict arg reportName
  key = reportName~string~strip~upper
  if reportDefinitions~hasIndex(key) = 0 then return .nil
  return reportDefinitions[key]

::method reportDefinitionCanonicalName
  report = self~reportDefinition(arg(1))
  if report == .nil then return ""
  return report["NAME"]

::method normalizeSemanticLabel
  use strict arg label
  value = label~string~strip~upper
  value = value~changestr("'", "")
  value = value~changestr('"', "")
  value = value~changestr("_", " ")
  value = value~changestr("-", " ")
  do while value~pos("  ") > 0
    value = value~changestr("  ", " ")
  end
  if value~left(4) = "THE " then value = value~substr(5)
  return value~strip

::method resolveReportColumn
  use strict arg sourceForm, requestedLabel
  requestedText = requestedLabel~string~strip
  if requestedText~pos(".") > 0 then return self~resolveReportPath(sourceForm, requestedText)
  wanted = self~normalizeSemanticLabel(requestedText)
  if wanted = "NAME" | wanted = "TITLE" | wanted = "DOCUMENT NAME" then return "TITLE"
  if wanted = "STATUS" | wanted = "STATE" | wanted = "APPROVAL STATUS" then return "STATUS"
  if wanted = "KEY" | wanted = "DOCUMENT KEY" then return "KEY"
  if wanted = "TYPE" | wanted = "DOCUMENT TYPE" then return "TYPE"
  if wanted = "AMOUNT" | wanted = "VALUE" then return "AMOUNT"
  if wanted = "RISK" then return "RISK"

  fields = self~userFormatFields(sourceForm)
  do spec over fields
    label = self~normalizeSemanticLabel(spec["LABEL"])
    name = self~normalizeSemanticLabel(spec["NAME"])
    if wanted = label | wanted = name then return spec["NAME"]
    if wanted = "COST" then do
      if label~pos("COST") > 0 | name~pos("COST") > 0 then return spec["NAME"]
    end
    if wanted = "TPS NUMBER" then do
      if label~pos("TPS") > 0 then if label~pos("NUMBER") > 0 then return spec["NAME"]
    end
  end
  if wanted = "COST" then return "AMOUNT"
  return ""

::method resolveReportPath
  use strict arg sourceForm, requestedPath
  currentForm = sourceForm
  remaining = requestedPath~string~strip
  binding = ""
  do while remaining <> ""
    parse var remaining part "." remaining
    part = part~strip
    if part = "" then return ""
    fieldName = self~resolveReportFieldName(currentForm, part)
    if fieldName = "" then return ""
    if binding <> "" then binding = binding || "."
    binding = binding || fieldName
    if remaining <> "" then do
      targetForm = self~relationshipTarget(currentForm, fieldName)
      if targetForm = "" then return ""
      currentForm = targetForm
    end
  end
  return binding

::method resolveReportFieldName
  use strict arg sourceForm, requestedLabel
  wanted = self~normalizeSemanticLabel(requestedLabel)
  select
    when wanted = "NAME" | wanted = "TITLE" | wanted = "DOCUMENT NAME" then return "TITLE"
    when wanted = "STATUS" | wanted = "STATE" | wanted = "APPROVAL STATUS" then return "STATUS"
    when wanted = "KEY" | wanted = "DOCUMENT KEY" then return "KEY"
    when wanted = "TYPE" | wanted = "DOCUMENT TYPE" then return "TYPE"
    when wanted = "AMOUNT" | wanted = "VALUE" then return "AMOUNT"
    when wanted = "RISK" then return "RISK"
    otherwise nop
  end
  do spec over self~userFormatFields(sourceForm)
    label = self~normalizeSemanticLabel(spec["LABEL"])
    name = self~normalizeSemanticLabel(spec["NAME"])
    if wanted = label | wanted = name then return spec["NAME"]
    if wanted = "COST" then do
      if label~pos("COST") > 0 | name~pos("COST") > 0 then return spec["NAME"]
    end
    if wanted = "TPS NUMBER" then do
      if label~pos("TPS") > 0 then if label~pos("NUMBER") > 0 then return spec["NAME"]
    end
  end
  if wanted = "COST" then return "AMOUNT"
  return ""

::method reportDocuments
  use strict arg reportDefinition
  out = .Array~new
  sourceForm = reportDefinition["SOURCE_FORM"]
  do document over self~allDocuments
    if document~formName = sourceForm then out~append(document)
  end
  return out

::method reportValue
  use strict arg document, binding
  if binding~string~pos(".") > 0 then return self~resolveReportValuePath(document, binding)
  key = binding~upper
  select
    when key = "TITLE" then return document~Title
    when key = "STATUS" then return document~ApprovalStatus
    when key = "KEY" then return document~DocKey
    when key = "TYPE" then return document~formName
    when key = "AMOUNT" then return document~Amount
    when key = "RISK" then return document~Risk
    otherwise do
      value = document~field(binding)
      if value == .nil then return ""
      return value~string
    end
  end

::method resolveReportValuePath
  use strict arg document, path
  current = document
  remaining = path~string~strip
  do while remaining <> ""
    parse var remaining part "." remaining
    part = part~strip
    if part = "" then return ""
    if current == .nil then return ""
    if \current~isA(.Document) then return ""
    if remaining <> "" then do
      targetForm = self~relationshipTarget(current~formName, part)
      if targetForm = "" then return ""
      if self~relationshipCardinality(current~formName, part) = "MANY" then do
        values = .Array~new
        do targetDocument over self~referencedDocuments(current, part)
          values~append(self~resolveReportValuePath(targetDocument, remaining))
        end
        return self~joinValues(values, ", ")
      end
      current = self~referencedDocument(current, part)
    end
    else return self~reportValue(current, part)
  end
  return ""


::method reportSpreadsheetData
  use strict arg reportName
  definition = self~reportDefinition(reportName)
  if definition == .nil then return .nil
  columns = .Array~new
  rows = .Array~new
  types = .Directory~new
  provenance = .Directory~new
  do column over definition["COLUMNS"]
    label = column["LABEL"]
    columns~append(label)
    types~put(self~reportBindingType(definition["SOURCE_FORM"], column["BINDING"]), label)
  end
  do document over self~reportDocuments(definition)
    row = .Directory~new
    do column over definition["COLUMNS"]
      row~put(self~reportValue(document, column["BINDING"]), column["LABEL"])
    end
    rows~append(row)
  end
  provenance~put(self, "SOURCE_APP")
  provenance~put(definition, "SOURCE_REPORT_DEFINITION")
  provenance~put(definition["SOURCE_FORM"], "SOURCE_DOCUMENT_FORM")
  return .SpreadsheetTableData~new(definition["NAME"], columns, rows, types, provenance)

::method reportBindingType
  use strict arg sourceForm, binding
  currentForm = sourceForm
  remaining = binding~string~strip
  do while remaining <> ""
    parse var remaining part "." remaining
    part = part~strip
    if part = "" then return "TEXT"
    if remaining <> "" then do
      targetForm = self~relationshipTarget(currentForm, part)
      if targetForm = "" then return "TEXT"
      currentForm = targetForm
    end
    else do
      key = part~upper
      select
        when key = "AMOUNT" then return "MONEY"
        when key = "STATUS" | key = "TITLE" | key = "KEY" | key = "TYPE" | key = "RISK" then return "TEXT"
        otherwise nop
      end
      do spec over self~userFormatFields(currentForm)
        if spec["NAME"]~upper \= key then iterate
        if spec["TYPE"]~upper = "CALCULATED" then do
          if spec~hasIndex("RESULT_TYPE") then return spec["RESULT_TYPE"]
          return "NUMBER"
        end
        if spec["TYPE"]~upper = "DOCUMENT_REFERENCE" then return "TEXT"
        return spec["TYPE"]
      end
      return "TEXT"
    end
  end
  return "TEXT"

::method exportReportSpreadsheet
  use strict arg reportName, target
  resultObject = .Directory~new
  definition = self~reportDefinition(reportName)
  if definition == .nil then do
    resultObject["STATUS"] = "REPORT_NOT_FOUND"
    return resultObject
  end
  target = target~string~strip
  if target = "" then do
    resultObject["STATUS"] = "EXPORT_TARGET_REQUIRED"
    return resultObject
  end
  data = self~reportSpreadsheetData(reportName)
  lowerTarget = target~lower
  signal on syntax name SpreadsheetExportFailed
  if lowerTarget~right(5) = ".xlsx" then ignore = .SpreadsheetInterchange~writeXlsx(data, target, definition["NAME"])
  else if lowerTarget~right(4) = ".ods" then ignore = .SpreadsheetInterchange~writeOds(data, target, definition["NAME"])
  else if lowerTarget~right(4) = ".csv" then ignore = .SpreadsheetInterchange~writeCsv(data, target)
  else if lowerTarget~right(4) = ".tsv" then ignore = .SpreadsheetInterchange~writeTsv(data, target)
  else do
    resultObject["STATUS"] = "EXPORT_FORMAT_NOT_SUPPORTED"
    resultObject["TARGET"] = target
    return resultObject
  end
  signal off syntax
  resultObject["STATUS"] = "EXPORTED"
  resultObject["COUNT"] = data~rowCount
  resultObject["TARGET"] = target
  resultObject["FORMAT"] = target~substr(target~lastPos(".") + 1)~upper
  resultObject["DATA"] = data
  return resultObject
SpreadsheetExportFailed:
  say "Spreadsheet export failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "EXPORT_FAILED"
  resultObject["ERROR"] = condition("C")
  resultObject["DESCRIPTION"] = condition("D")
  return resultObject

::method reportPreview
  use strict arg reportDefinition
  docs = self~reportDocuments(reportDefinition)
  columns = reportDefinition["COLUMNS"]
  out = reportDefinition["NAME"]~upper || "0a"x
  out = out || "Rows: " || docs~items || " | Source: " || reportDefinition["SOURCE_FORM"] || "0a"x
  labels = ""
  do column over columns
    if labels <> "" then labels = labels || " | "
    labels = labels || column["LABEL"]
  end
  out = out || labels || "0a"x || copies("-", 72) || "0a"x
  do document over docs
    line = ""
    do column over columns
      if line <> "" then line = line || " | "
      line = line || self~reportValue(document, column["BINDING"])
    end
    out = out || line || "0a"x
  end
  totals = reportDefinition["TOTALS"]
  do binding over totals
    total = 0
    valid = .true
    do document over docs
      value = self~reportValue(document, binding)
      if \value~datatype("N") then do
        valid = .false
        leave
      end
      total = total + value
    end
    if valid then out = out || "TOTAL " || binding || ": " || total || "0a"x
  end
  return out

::method runReport
  use strict arg reportName, target=""
  definition = self~reportDefinition(reportName)
  resultObject = .Directory~new
  if definition == .nil then do
    resultObject["STATUS"] = "REPORT_NOT_FOUND"
    return resultObject
  end
  docs = self~reportDocuments(definition)
  resultObject["STATUS"] = "REPORTED"
  resultObject["COUNT"] = docs~items
  resultObject["TEXT"] = self~reportPreview(definition)
  target = target~strip
  if target = "" then return resultObject
  if translate(right(target, 4)) <> ".PDF" then target = target || ".pdf"

  report = .PdfFlowReport~new~landscape
  report~title = definition["NAME"]
  report~subtitle = "Mini NotNotes saved report definition"
  report~addParagraph("Rows: " || docs~items || ". Source document format: " || definition["SOURCE_FORM"] || ".")

  columns = definition["COLUMNS"]
  headers = .Array~new
  widths = .Array~new
  do column over columns
    headers~append(column["LABEL"])
    widths~append(680 / columns~items)
  end
  table = .PdfTable~new(headers, widths)
  table~title = definition["NAME"]
  do document over docs
    row = .Array~new
    do column over columns
      row~append(self~reportValue(document, column["BINDING"]))
    end
    table~addRow(row)
  end
  report~addTable(table)

  totals = definition["TOTALS"]
  if totals~items > 0 then do
    totalTable = .PdfTable~new(.Array~of("Total", "Value"), .Array~of(220, 140))
    totalTable~title = "Totals"
    do binding over totals
      total = 0
      valid = .true
      do document over docs
        value = self~reportValue(document, binding)
        if \value~datatype("N") then do
          valid = .false
          leave
        end
        total = total + value
      end
      if valid then totalTable~addRow(.Array~of(binding, total))
    end
    report~addTable(totalTable)
  end

  signal on syntax name GenericReportFailed
  bytes = report~render(target)
  signal off syntax
  resultObject["TARGET"] = target
  resultObject["BYTES"] = bytes
  return resultObject

GenericReportFailed:
  say "Generic report failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "REPORT_FAILED"
  resultObject["ERROR"] = condition("C")
  return resultObject

::method tpsDocuments
  selected = .Array~new
  do document over self~allDocuments
    if document~formName = "TPS Report" then selected~append(document)
  end
  return selected

::method tpsField
  use strict arg document, semanticName
  wanted = semanticName~upper
  do fieldName over document~fieldNames
    upperName = fieldName~upper
    select
      when wanted = "TPS_NUMBER" then do
        if upperName~pos("TPS") > 0 then do
          if upperName~pos("NUMBER") > 0 then return self~fieldText(document, fieldName)
        end
      end
      when wanted = "USER" then do
        if upperName = "USER" | upperName~pos("OWNER") > 0 then return self~fieldText(document, fieldName)
      end
      when wanted = "SUMMARY" then do
        if upperName~pos("SUMMARY") > 0 then return self~fieldText(document, fieldName)
      end
      when wanted = "FINDINGS" then do
        if upperName~pos("FINDINGS") > 0 then return self~fieldText(document, fieldName)
      end
      when wanted = "NEXT_STEPS" then do
        if upperName~pos("NEXT") > 0 then do
          if upperName~pos("STEP") > 0 then return self~fieldText(document, fieldName)
        end
      end
      otherwise nop
    end
  end
  return ""

::method tpsStatusCounts
  use strict arg docs
  counts = .Directory~new
  counts["APPROVED"] = 0
  counts["PENDING APPROVAL"] = 0
  counts["REJECTED"] = 0
  counts["DRAFT"] = 0
  do document over docs
    status = document~ApprovalStatus
    if counts~hasIndex(status) then counts[status] = counts[status] + 1
    else counts["DRAFT"] = counts["DRAFT"] + 1
  end
  return counts

::method tpsReportPreview
  docs = self~tpsDocuments
  counts = self~tpsStatusCounts(docs)
  out = "TPS REPORT REGISTER" || "0a"x
  out = out || "Reports: " || docs~items || " | Draft: " || counts["DRAFT"] || " | Pending: " || counts["PENDING APPROVAL"] || " | Approved: " || counts["APPROVED"] || " | Rejected: " || counts["REJECTED"] || "0a"x
  out = out || copies("-", 72) || "0a"x
  do document over docs
    tpsNumber = self~tpsField(document, "TPS_NUMBER")
    owner = self~tpsField(document, "USER")
    summary = self~tpsField(document, "SUMMARY")
    out = out || document~DocKey || " | " || tpsNumber || " | " || owner || " | " || document~ApprovalStatus || " | " || summary || "0a"x
  end
  return out

::method fieldText
  use strict arg document, fieldName
  value = document~field(fieldName)
  if value == .nil then return ""
  return value~string

::method reportTps
  use strict arg target = ""
  docs = self~tpsDocuments
  resultObject = .Directory~new
  resultObject["STATUS"] = "REPORTED"
  resultObject["COUNT"] = docs~items
  resultObject["TEXT"] = self~tpsReportPreview
  target = target~strip
  if target = "" then return resultObject
  if translate(right(target, 4)) <> ".PDF" then target = target || ".pdf"

  report = .PdfFlowReport~new~landscape
  report~title = "TPS Report Register"
  report~subtitle = "Mini NotNotes persistent TPS document report"

  counts = self~tpsStatusCounts(docs)
  report~addParagraph("Persisted TPS documents: " || docs~items || ". This report is generated from the current durable Mini NotNotes store.")

  statusTable = .PdfTable~new(.Array~of("State", "Count"), .Array~of(180, 90))
  statusTable~title = "Status Summary"
  statusTable~setColumnTypes(.Array~of("text", "integer"))
  statusTable~addRow(.Array~of("Draft", counts["DRAFT"]))
  statusTable~addRow(.Array~of("Pending approval", counts["PENDING APPROVAL"]))
  statusTable~addRow(.Array~of("Approved", counts["APPROVED"]))
  statusTable~addRow(.Array~of("Rejected", counts["REJECTED"]))
  report~addTable(statusTable)

  table = .PdfTable~new(.Array~of("Key", "TPS Number", "User", "Summary", "Status"), .Array~of(70, 105, 95, 330, 105))
  table~title = "TPS Reports"
  table~setAlignments(.Array~of("left", "left", "left", "left", "center"))
  detailRows = .Array~new
  hasNarrative = .false
  do document over docs
    tpsNumber = self~tpsField(document, "TPS_NUMBER")
    owner = self~tpsField(document, "USER")
    summary = self~tpsField(document, "SUMMARY")
    findings = self~tpsField(document, "FINDINGS")
    nextSteps = self~tpsField(document, "NEXT_STEPS")
    table~addRow(.Array~of(document~DocKey, tpsNumber, owner, summary, document~ApprovalStatus))
    if findings <> "" | nextSteps <> "" then do
      detailRows~append(.Array~of(tpsNumber, findings, nextSteps))
      hasNarrative = .true
    end
  end
  report~addTable(table)

  if hasNarrative then do
    narrative = .PdfTable~new(.Array~of("TPS Number", "Findings", "Next Steps"), .Array~of(105, 300, 300))
    narrative~title = "Findings and Next Steps"
    narrative~addRows(detailRows)
    report~addTable(narrative)
  end

  signal on syntax name TpsReportFailed
  bytes = report~render(target)
  signal off syntax
  resultObject["TARGET"] = target
  resultObject["BYTES"] = bytes
  return resultObject

TpsReportFailed:
  say "TPS report failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "REPORT_FAILED"
  resultObject["ERROR"] = condition("C")
  return resultObject

::method printableDocument
  use strict arg document
  if document == .nil then return ""
  line = copies("=", 72)
  out = line || "0a"x
  out = out || document~formName || "0a"x
  out = out || document~DocKey || " - " || document~Title || "0a"x
  out = out || line || "0a"x
  out = out || "Status: " || document~ApprovalStatus || "0a"x
  out = out || "Workflow: " || document~Workflow || "0a"x
  if document~DependsOn~string~strip <> "" then out = out || "Depends on: " || document~DependsOn || "0a"x
  standardFields = "DOCKEY TITLE AMOUNT RISK DEPENDSON WORKFLOW APPROVALS REFERRALS"
  do fieldName over document~fieldNames
    if wordpos(fieldName~upper, standardFields) > 0 then iterate
    fieldValue = document~field(fieldName)
    if fieldValue == .nil then fieldValue = ""
    out = out || fieldName || ": " || fieldValue || "0a"x
  end
  out = out || line || "0a"x
  return out

::method printSelected
  use strict arg target = ""
  document = self~selected
  if document == .nil then return .Directory~new~put("NO_DOCUMENT_SELECTED", "STATUS")
  text = self~printableDocument(document)
  resultObject = .Directory~new
  resultObject["STATUS"] = "PRINTED"
  resultObject["KEY"] = document~DocKey
  resultObject["TEXT"] = text
  target = target~strip
  if target <> "" then do
    if translate(right(target, 4)) <> ".PDF" then target = target || ".pdf"
    signal on syntax name PdfPrintFailed
    bytes = .PdfNotNotesRenderer~new~write(document, target)
    signal off syntax
    resultObject["TARGET"] = target
    resultObject["BYTES"] = bytes
  end
  return resultObject

PdfPrintFailed:
  say "PDF print failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "PRINT_FAILED"
  resultObject["ERROR"] = condition("C")
  return resultObject

::requires 'src/MiniNotesPersistence.cls'
::requires 'src/MiniNotesTime.cls'
::requires 'vendor/spreadsheet/SpreadsheetInterchange.cls'
::requires 'vendor/pdf/src/PdfNotNotes.cls'
::requires 'vendor/notnotes/AlchemyNotNotes.cls'
::requires 'vendor/cliui/rexx/CliUiTable.cls'
::requires 'vendor/cliui/rexx/CliUiDocument.cls'
::requires 'vendor/cliui/rexx/CliUiSemantic.cls'
