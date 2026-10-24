/* MiniNotesCliUi.cls
 * Renderer-neutral CLI UI controller for Mini NotNotes Approval Desk.
 * Domain truth remains in MiniNotesApp / NotNotes.
 */
::class MiniNotesCliUi public

::method init
  expose app screen table detail prompt status mode running actions designName designFields designSubviews activeSubview designEditing composeName composeFields composeValues composeIndex reportDesignName reportSource reportColumns reportTotals
  use strict arg app
  screen = .CliUiScreenModel~new("Mini NotNotes Approval Desk")
  prompt = .CliUiPromptModel~new("Command: ")
  screen~prompt = prompt
  screen~navigation = .array~of("UP/DOWN select", "ENTER open", "S submit", "A approve", "R reject", "ESC back", "type command")
  actions = .CliUiActionMap~new
  actions~bind("UP", "TABLE_PREVIOUS")
  actions~bind("DOWN", "TABLE_NEXT")
  actions~bind("ENTER", "ENTER")
  actions~bind("ESCAPE", "RETURN")
  actions~bind("S", "SUBMIT")
  actions~bind("A", "APPROVE")
  actions~bind("R", "REJECT")
  actions~bind("P", "PRINT")
  mode = "LIST"
  running = .true
  designName = ""
  designFields = .Array~new
  designSubviews = .Array~new
  activeSubview = .nil
  designEditing = .false
  composeName = ""
  composeFields = .Array~new
  composeValues = .Directory~new
  composeIndex = 0
  reportDesignName = ""
  reportSource = ""
  reportColumns = .Array~new
  reportTotals = .Array~new
  status = "Five documents loaded. Select a document or type a command."
  self~showDocuments

::method app
  expose app
  return app

::method running
  expose running
  return running

::method screen
  expose screen
  return screen

::method mode
  expose mode
  return mode

::method status
  expose status
  return status

::method render
  expose screen status
  use strict arg renderer, rows=24, cols=100
  screen~status = status
  .CliUiScreenProjection~new(renderer)~render(screen, rows, cols)
  return self

::method handleKey
  expose prompt actions mode running status
  use strict arg keyEvent
  if keyEvent == .nil then return self
  kind = keyEvent[1]
  codepoint = keyEvent[3]

  if kind = "TEXT" then do
    if codepoint >= 32 then do
      if codepoint <= 126 then do
        character = d2c(codepoint)
        if mode = "DETAIL" then do
          if prompt~buffer = "" then do
            if character~upper = "S" then do
              self~semanticCommand("SUBMIT")
              return self
            end
            if character~upper = "A" then do
              self~semanticCommand("APPROVE")
              return self
            end
            if character~upper = "R" then do
              self~semanticCommand("REJECT")
              return self
            end
          end
        end
        prompt~insert(character)
      end
    end
    return self
  end
  if kind = "BACKSPACE" then do
    prompt~backspace
    return self
  end
  if kind = "ENTER" then do
    if prompt~buffer <> "" then do
      line = prompt~submit
      self~executeCommand(line)
      return self
    end
    self~semanticCommand("ENTER")
    return self
  end

  command = actions~resolve(kind)
  if command \== .nil then self~semanticCommand(command)
  return self

::method semanticCommand
  expose app table detail mode running status screen
  use strict arg command
  select
    when command = "TABLE_PREVIOUS" then do
      if mode = "LIST" then do
        table~move(-1)
        self~selectTableIdentity
        status = self~selectionStatus
      end
    end
    when command = "TABLE_NEXT" then do
      if mode = "LIST" then do
        table~move(1)
        self~selectTableIdentity
        status = self~selectionStatus
      end
    end
    when command = "ENTER" then do
      if mode = "LIST" then self~openSelected
      else if mode = "DETAIL" then self~returnToList
    end
    when command = "RETURN" then self~returnToList
    when command = "SUBMIT" then do
      if mode = "DETAIL" then self~submit("UI submission")
      else status = "Open a draft document before submitting it."
    end
    when command = "APPROVE" then do
      if mode = "DETAIL" then self~decide("APPROVE")
      else status = "Open a document before approving it."
    end
    when command = "REJECT" then do
      if mode = "DETAIL" then self~decide("REJECT")
      else status = "Open a document before rejecting it."
    end
    when command = "PRINT" then self~printSelected("")
    when command = "QUIT" then running = .false
    otherwise status = "Unknown semantic command: " || command
  end
  return self

::method executeCommand
  expose app status running mode table screen
  use strict arg line
  line = line~strip
  if line = "" then return self
  if mode = "DESIGN" then return self~handleDesignInput(line)
  if mode = "COMPOSE" then return self~handleComposeInput(line)
  if mode = "REPORT_DESIGN" then return self~handleReportDesignInput(line)

  upperLine = line~upper
  createCue = "CREATE A NEW DOCUMENT FORMAT CALLED "
  if upperLine~left(createCue~length) = createCue then do
    formatName = line~substr(createCue~length + 1)~strip
    return self~startDesign(formatName)
  end
  completeCue = "COMPLETE A "
  if upperLine~left(completeCue~length) = completeCue then do
    formatName = line~substr(completeCue~length + 1)~strip
    return self~startCompose(formatName)
  end
  if upperLine~left(9) = "I NEED A " then do
    if upperLine~right(6) = "REPORT" then do
      reportName = line~substr(10)~strip
      return self~startReportDesign(reportName)
    end
  end

  if upperLine = "SUBMIT THIS TPS REPORT" | upperLine = "SUBMIT THIS DOCUMENT" | upperLine = "SEND FOR APPROVAL" | upperLine = "SEND THIS FOR APPROVAL" then do
    return self~submit("submitted from natural command")
  end

  command = line~word(1)~upper
  rest = ""
  if line~words >= 2 then rest = line~substr(line~wordIndex(2))

  select
    when command = "DOCUMENTS" | command = "LIST" then self~showDocuments
    when command = "QUERY" then self~showQuery(rest)
    when command = "VIEW" then self~showView(rest)
    when command = "SELECT" then do
      document = app~select(rest)
      if document == .nil then status = "NOT FOUND: " || rest
      else do
        status = "Selected " || document~DocKey || " - " || document~Title
        self~showDocuments
        self~selectByKey(document~DocKey)
      end
    end
    when command = "READ" | command = "OPEN" then do
      if rest <> "" then app~select(rest)
      self~openSelected
    end
    when command = "LINK" then do
      document = app~selected
      if document == .nil then status = "Select a document before linking it."
      else do
        toPos = rest~upper~pos(" TO ")
        if toPos = 0 then status = "Use LINK <reference field> TO <document key or identifier>."
        else do
          fieldText = rest~left(toPos - 1)~strip
          referenceText = rest~substr(toPos + 4)~strip
          fieldName = app~resolveReportFieldName(document~formName, fieldText)
          if fieldName = "" | app~relationshipTarget(document~formName, fieldName) = "" then status = "Not a document-reference field: " || fieldText
          else if app~addDocumentReference(document, fieldName, referenceText) then do
            status = "Linked " || referenceText || " to " || fieldText || "."
            if mode = "DETAIL" then self~openSelected
            else self~refreshSelectedTableRow
          end
          else status = "Could not link " || referenceText || " to " || fieldText || "."
        end
      end
    end
    when command = "UNLINK" then do
      document = app~selected
      if document == .nil then status = "Select a document before unlinking it."
      else do
        fromPos = rest~upper~pos(" FROM ")
        if fromPos = 0 then status = "Use UNLINK <reference field> FROM <document key or identifier>."
        else do
          fieldText = rest~left(fromPos - 1)~strip
          referenceText = rest~substr(fromPos + 6)~strip
          fieldName = app~resolveReportFieldName(document~formName, fieldText)
          if fieldName = "" | app~relationshipTarget(document~formName, fieldName) = "" then status = "Not a document-reference field: " || fieldText
          else if app~removeDocumentReference(document, fieldName, referenceText) then do
            status = "Unlinked " || referenceText || " from " || fieldText || "."
            if mode = "DETAIL" then self~openSelected
            else self~refreshSelectedTableRow
          end
          else status = "Could not unlink " || referenceText || " from " || fieldText || "."
        end
      end
    end
    when command = "SUBMIT" then self~submit(rest)
    when command = "APPROVE" then self~decide("APPROVE", rest)
    when command = "REJECT" then self~decide("REJECT", rest)
    when command = "CREATE" then do
      document = app~createFromCommand(rest)
      if document == .nil then status = "CREATE FAILED - use CREATE purchase|title|amount|depends"
      else do
        status = "Created " || document~DocKey || " - " || document~ApprovalStatus
        self~showDocuments
        self~selectByKey(document~DocKey)
      end
    end
    when command = "ALTER" | command = "IMPROVE" then self~startAlter(rest)
    when command = "SET" then do
      document = app~selected
      if document == .nil then status = "Select a user document before setting a field."
      else do
        eqPos = rest~pos("=")
        if eqPos = 0 then status = "Use SET <field> = <value>."
        else do
          fieldText = rest~left(eqPos - 1)~strip
          fieldValue = rest~substr(eqPos + 1)~strip
          if app~setUserDocumentField(document, fieldText, fieldValue) then do
            status = "Set " || fieldText || "."
            if mode = "DETAIL" then self~openSelected
            else self~refreshSelectedTableRow
          end
          else status = "Could not set " || fieldText || "."
        end
      end
    end
    when command = "DESIGN" then do
      upperRest = rest~upper~strip
      if upperRest~left(7) = "REPORT " then self~startReportDesign(rest~substr(8)~strip)
      else self~startDesign(rest)
    end
    when command = "COMPLETE" then self~startCompose(rest)
    when command = "RUN" then self~runSavedReport(rest)
    when command = "REPORTS" then self~showReportDefinitions
    when command = "EXPORT" then self~exportSavedReport(rest)
    when command = "SAVE" then do
      saved = app~persistNow
      if saved then status = "Saved " || app~allDocuments~items || " document(s) to " || app~persistenceRoot
      else status = "Save skipped while restoring."
    end
    when command = "PRINT" then self~printCommand(rest)
    when command = "REPORT" then do
      if rest~strip = "" then self~showReportDefinitions
      else self~runSavedReport(rest)
    end
    when command = "HELP" then status = "Commands: documents, query, view, select, read, set <field> = <value>, link <field> to <document>, unlink <field> from <document>, submit [note], approve, reject, save, print [key] [to file], design <format>, alter <format>, complete <format>, design report <name>, reports, report <saved report> [to file.pdf], export <saved report> to <file.xlsx|ods|csv|tsv>, run <saved report>, quit"
    when command = "QUIT" | command = "EXIT" then running = .false
    otherwise self~showQuery(line)
  end
  return self

::method showDocuments
  expose app screen table detail mode status
  docs = app~allDocuments
  table = self~tableFromDocuments(docs)
  screen~table = table
  screen~detail = .nil
  screen~form = .nil
  detail = .nil
  mode = "LIST"
  if table~count > 0 then do
    table~select(1)
    self~selectTableIdentity
  end
  status = "Documents: " || docs~items
  return self

::method showQuery
  expose app screen table detail mode status
  use strict arg text
  docs = app~query(text)
  table = self~tableFromDocuments(docs)
  screen~table = table
  screen~detail = .nil
  screen~form = .nil
  detail = .nil
  mode = "LIST"
  if table~count > 0 then do
    table~select(1)
    self~selectTableIdentity
  end
  status = "Query '" || text || "': " || docs~items || " match(es)"
  return self

::method showView
  expose app screen table detail mode status
  use strict arg text
  docs = app~viewDocuments(text)
  table = self~tableFromDocuments(docs)
  screen~table = table
  screen~detail = .nil
  screen~form = .nil
  detail = .nil
  mode = "LIST"
  if table~count > 0 then do
    table~select(1)
    self~selectTableIdentity
  end
  status = "View '" || text || "': " || docs~items || " row(s)"
  return self

::method tableFromDocuments
  use strict arg documents
  columns = .array~of("KEY", "TYPE", "TITLE", "STATUS", "DEPS")
  model = .CliUiTableModel~new(columns)
  do document over documents
    cells = .array~of(document~DocKey, document~formName, document~Title, document~ApprovalStatus, document~DependsOn)
    model~append(document~documentId, cells)
  end
  return model

::method selectTableIdentity
  expose app table
  identity = table~selectedIdentity
  if identity == .nil then return .nil
  document = app~node~document(identity)
  if document \== .nil then app~select(document~DocKey)
  return document

::method selectByKey
  expose app table
  use strict arg key
  wanted = key~string~upper
  do i = 1 to table~count
    rowKey = table~row(i)[2][1]~string~upper
    if rowKey = wanted then do
      table~select(i)
      return app~select(rowKey)
    end
  end
  return .nil

::method selectionStatus
  expose app
  document = app~selected
  if document == .nil then return "No document selected."
  return document~DocKey || " | " || document~ApprovalStatus || " | " || document~Title

::method openSelected
  expose app screen detail mode status
  document = app~selected
  if document == .nil then do
    status = "No document selected."
    return self
  end
  detail = self~detailFor(document)
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  status = "S submit | A approve | R reject | ESC return"
  return self

::method detailFor
  expose app
  use strict arg document
  model = .CliUiDetailModel~new(document~DocKey || " - " || document~Title)
  model~addField("Type", document~formName)
  model~addField("Amount", document~Amount)
  model~addField("Risk", document~Risk)
  model~addField("Status", document~ApprovalStatus)
  model~addField("Workflow", document~Workflow)
  model~addField("Depends on", document~DependsOn)
  model~addField("Dependency state", app~dependencyState(document))
  model~addField("Revision", document~revision)
  standardFields = "DOCKEY TITLE AMOUNT RISK DEPENDSON WORKFLOW"
  do fieldName over document~fieldNames
    if wordpos(fieldName~upper, standardFields) = 0 then do
      fieldValue = document~field(fieldName)
      if fieldValue == .nil then fieldValue = ""
      model~addField(fieldName, fieldValue)
    end
  end
  references = app~renderReferencesFor(document)
  if references <> "" then model~addSection("REFERENCES", references)
  subviews = app~renderSubviewsFor(document)
  if subviews <> "" then model~addSection("SUBVIEWS", subviews)
  model~addAction("SUBMIT", "Submit for approval")
  model~addAction("APPROVE", "Approve")
  model~addAction("REJECT", "Reject")
  model~addAction("PRINT", "Print")
  return model

::method returnToList
  expose app screen table detail mode status
  screen~detail = .nil
  screen~form = .nil
  screen~table = table
  detail = .nil
  mode = "LIST"
  status = self~selectionStatus
  return self

::method submit
  expose app mode status
  use strict arg note="submitted for approval"
  if note~strip = "" then note = "submitted for approval"
  submitStatus = app~submitSelected(note)
  if mode = "DETAIL" then self~openSelected
  else self~refreshSelectedTableRow
  status = "SUBMIT: " || submitStatus
  return self

::method decide
  expose app mode status
  use strict arg outcome, note="UI decision"
  decisionStatus = app~decideSelected(outcome, note)
  if mode = "DETAIL" then self~openSelected
  else self~refreshSelectedTableRow
  status = outcome || ": " || decisionStatus
  return self

::method refreshSelectedTableRow
  expose app table
  if table == .nil then return self
  selectedRow = table~selected
  if selectedRow < 1 then return self
  document = app~selected
  if document == .nil then return self
  row = table~row(selectedRow)
  if row == .nil then return self
  cells = row[2]
  cells~put(document~DocKey, 1)
  cells~put(document~formName, 2)
  cells~put(document~Title, 3)
  cells~put(document~ApprovalStatus, 4)
  cells~put(document~DependsOn, 5)
  return self

::method printCommand
  expose app status
  use strict arg rest
  text = rest~strip
  target = ""
  key = ""
  upperText = text~upper
  toPos = upperText~pos(" TO ")
  if toPos > 0 then do
    key = text~left(toPos - 1)~strip
    target = text~substr(toPos + 4)~strip
  end
  else if upperText~left(3) = "TO " then target = text~substr(4)~strip
  else key = text
  if key <> "" then do
    document = app~select(key)
    if document == .nil then do
      status = "PRINT: document not found: " || key
      return self
    end
  end
  return self~printSelected(target)

::method printSelected
  expose app screen detail mode status
  use strict arg target = ""
  resultObject = app~printSelected(target)
  if resultObject["STATUS"] \= "PRINTED" then do
    status = "PRINT: " || resultObject["STATUS"]
    return self
  end
  if target <> "" then do
    status = "Printed " || resultObject["KEY"] || " to " || target
    return self
  end
  detail = .CliUiDetailModel~new("Print Preview - " || resultObject["KEY"])
  detail~addSection("REPORT", resultObject["TEXT"])
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  status = "Print preview for " || resultObject["KEY"] || ". Use PRINT TO <file.pdf> to write a PDF."
  return self

::method reportTps
  expose app screen detail mode status
  use strict arg target = ""
  resultObject = app~reportTps(target)
  if resultObject["STATUS"] \= "REPORTED" then do
    status = "REPORT: " || resultObject["STATUS"]
    return self
  end
  if target~strip <> "" then do
    status = "TPS report: " || resultObject["COUNT"] || " document(s) -> " || resultObject["TARGET"]
    return self
  end
  detail = .CliUiDetailModel~new("TPS Report Register")
  detail~addSection("REPORT", resultObject["TEXT"])
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  status = "TPS report: " || resultObject["COUNT"] || " document(s). Use REPORT TPS TO <file.pdf> for PDF."
  return self

::method startReportDesign
  expose screen mode status reportDesignName reportSource reportColumns reportTotals
  use strict arg reportName
  reportName = reportName~strip
  if reportName = "" then do
    status = "Name the report, for example: DESIGN REPORT TPS Summary Report"
    return self
  end
  reportDesignName = reportName
  reportSource = ""
  reportColumns = .Array~new
  reportTotals = .Array~new
  mode = "REPORT_DESIGN"
  self~refreshReportDesignForm
  status = "Designing report " || reportDesignName || ". Describe its row source and columns, then SAVE."
  return self

::method handleReportDesignInput
  expose app mode status reportDesignName reportSource reportColumns reportTotals
  use strict arg line
  text = line~strip
  upperText = text~upper
  if upperText = "CANCEL" then do
    mode = "LIST"
    self~showDocuments
    status = "Report design cancelled."
    return self
  end
  if upperText = "SAVE" | upperText = "SAVE REPORT" then do
    if reportSource = "" then do
      status = "Tell me which document format supplies the rows before saving."
      return self
    end
    if reportColumns~items = 0 then do
      status = "Add at least one report column before saving."
      return self
    end
    app~installReportDefinition(reportDesignName, reportSource, reportColumns, reportTotals)
    savedName = reportDesignName
    reportDesignName = ""
    reportSource = ""
    reportColumns = .Array~new
    reportTotals = .Array~new
    mode = "LIST"
    self~showDocuments
    status = "Saved report " || savedName || ". Type REPORT " || savedName || " or REPORT " || savedName || " TO file.pdf"
    return self
  end

  source = self~extractReportSource(text)
  if source <> "" then do
    canonical = app~userFormatCanonicalName(source)
    if canonical = "" then do
      status = "Unknown row document format: " || source
      return self
    end
    reportSource = canonical
    self~refreshReportDesignForm
    status = "Rows will come from " || reportSource || ". Now describe columns."
    return self
  end

  if upperText~pos("TOTAL") > 0 then do
    if reportSource = "" then do
      status = "Choose the row document format before adding totals."
      return self
    end
    totalLabel = self~extractTotalLabel(text)
    binding = app~resolveReportColumn(reportSource, totalLabel)
    if binding = "" then do
      status = "Cannot total '" || totalLabel || "' because that field is not available on " || reportSource || "."
      return self
    end
    reportTotals~append(binding)
    self~refreshReportDesignForm
    status = "Added total for " || totalLabel || "."
    return self
  end

  columnLabel = self~extractReportColumnLabel(text)
  if columnLabel <> "" then do
    if reportSource = "" then do
      status = "Choose the row document format before adding columns."
      return self
    end
    binding = app~resolveReportColumn(reportSource, columnLabel)
    if binding = "" then do
      status = "No field matching '" || columnLabel || "' exists on " || reportSource || ". Add that field to the document format or choose another column."
      return self
    end
    column = .Directory~new
    column["LABEL"] = self~prettyReportLabel(columnLabel)
    column["BINDING"] = binding
    reportColumns~append(column)
    self~refreshReportDesignForm
    status = "Added column " || reportColumns~items || ": " || column["LABEL"] || "."
    return self
  end

  status = "Report wizard: say 'rows are TPS Report', 'name in column 1', 'status in column 2', 'total cost', SAVE, or CANCEL."
  return self

::method extractReportSource
  use strict arg line
  upperLine = line~upper
  marker = "ROWS FOR EACH "
  p = upperLine~pos(marker)
  if p > 0 then return line~substr(p + marker~length)~strip
  marker = "ROWS ARE "
  p = upperLine~pos(marker)
  if p > 0 then return line~substr(p + marker~length)~strip
  marker = "ROWS COME FROM "
  p = upperLine~pos(marker)
  if p > 0 then return line~substr(p + marker~length)~strip
  return ""

::method extractReportColumnLabel
  use strict arg line
  upperLine = line~upper
  marker = " IN COLUMN "
  p = upperLine~pos(marker)
  if p > 0 then return line~left(p - 1)~strip
  if upperLine~left(7) = "COLUMN " then do
    isPos = upperLine~pos(" IS ")
    if isPos > 0 then return line~substr(isPos + 4)~strip
  end
  return ""

::method extractTotalLabel
  use strict arg line
  upperLine = line~upper~strip
  marker = "TOTAL FOR "
  p = upperLine~pos(marker)
  if p > 0 then return line~substr(p + marker~length)~strip
  marker = "TOTAL "
  p = upperLine~pos(marker)
  if p > 0 then return line~substr(p + marker~length)~strip
  return ""

::method prettyReportLabel
  use strict arg label
  value = label~strip
  if value~upper~left(4) = "THE " then value = value~substr(5)
  return value

::method refreshReportDesignForm
  expose screen reportDesignName reportSource reportColumns reportTotals
  form = .CliUiFormModel~new("Report Designer")
  form~addField(.CliUiField~new("REPORT", "Report", reportDesignName, .false))
  form~addField(.CliUiField~new("SOURCE", "Rows", reportSource, .false))
  n = 0
  do column over reportColumns
    n = n + 1
    form~addField(.CliUiField~new("COLUMN" || n, "Column " || n, column["LABEL"] || " -> " || column["BINDING"], .false))
  end
  n = 0
  do total over reportTotals
    n = n + 1
    form~addField(.CliUiField~new("TOTAL" || n, "Total " || n, total, .false))
  end
  screen~table = .nil
  screen~detail = .nil
  screen~form = form
  screen~navigation = .array~of("Describe row source and columns", "SAVE finish", "CANCEL abort")
  return self

::method showReportDefinitions
  expose app screen detail table mode status
  names = app~reportDefinitionNames
  detail = .CliUiDetailModel~new("Saved Reports")
  if names~items = 0 then detail~addSection("REPORTS", "No saved reports.")
  else do
    out = ""
    do name over names
      definition = app~reportDefinition(name)
      if out <> "" then out = out || "0a"x
      out = out || definition["NAME"] || " <- " || definition["SOURCE_FORM"]
    end
    detail~addSection("REPORTS", out)
  end
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  status = "Saved reports: " || names~items
  return self

::method runSavedReport
  expose app screen detail mode status
  use strict arg request
  text = request~strip
  target = ""
  upperText = text~upper
  toPos = upperText~pos(" TO ")
  if toPos > 0 then do
    target = text~substr(toPos + 4)~strip
    text = text~left(toPos - 1)~strip
  end
  canonical = app~reportDefinitionCanonicalName(text)
  if canonical = "" then do
    status = "Unknown saved report: " || text
    return self
  end
  resultObject = app~runReport(canonical, target)
  if resultObject["STATUS"] \= "REPORTED" then do
    status = "REPORT: " || resultObject["STATUS"]
    return self
  end
  detail = .CliUiDetailModel~new(canonical)
  detail~addSection("REPORT", resultObject["TEXT"])
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  if target = "" then status = canonical || ": " || resultObject["COUNT"] || " row(s)."
  else status = canonical || ": " || resultObject["COUNT"] || " row(s) -> " || resultObject["TARGET"]
  return self

::method exportSavedReport
  expose app screen detail mode status
  use strict arg request
  text = request~strip
  upperText = text~upper
  toPos = upperText~pos(" TO ")
  if toPos = 0 then do
    status = "EXPORT: use EXPORT <saved report> TO <file.xlsx|ods|csv|tsv>"
    return self
  end
  target = text~substr(toPos + 4)~strip
  reportName = text~left(toPos - 1)~strip
  if reportName~upper~left(7) = "REPORT " then reportName = reportName~substr(8)~strip
  canonical = app~reportDefinitionCanonicalName(reportName)
  if canonical = "" then do
    status = "EXPORT: unknown saved report: " || reportName
    return self
  end
  resultObject = app~exportReportSpreadsheet(canonical, target)
  if resultObject["STATUS"] \= "EXPORTED" then do
    status = "EXPORT: " || resultObject["STATUS"]
    return self
  end
  detail = .CliUiDetailModel~new(canonical || " export")
  detail~addSection("EXPORT", resultObject["COUNT"] || " row(s) -> " || resultObject["TARGET"])
  screen~table = .nil
  screen~form = .nil
  screen~detail = detail
  mode = "DETAIL"
  status = "EXPORT: " || canonical || " -> " || resultObject["TARGET"]
  return self

::method startDesign
  expose screen mode status designName designFields designSubviews activeSubview
  use strict arg formatName
  formatName = formatName~strip
  if formatName = "" then do
    status = "Name the document format, for example: DESIGN TPS Report"
    return self
  end
  designName = formatName
  designEditing = .false
  designFields = .Array~new
  designSubviews = .Array~new
  activeSubview = .nil
  mode = "DESIGN"
  self~refreshDesignForm
  status = "Designing " || designName || ". Say: I need a field for the 'TPS Number'; I need a user; SAVE."
  return self

::method startAlter
  expose app status designName designFields designSubviews activeSubview designEditing mode screen
  use strict arg formatName
  canonical = app~userFormatCanonicalName(formatName~strip)
  if canonical = "" then do
    status = "Unknown user document format: " || formatName
    return self
  end
  designName = canonical
  designEditing = .true
  designFields = app~userFormatFields(canonical)
  designSubviews = .Array~new
  do sourceSubview over app~subviewDefinitionsFor(canonical)
    subview = .Directory~new
    subview["NAME"] = sourceSubview["NAME"]
    subview["SOURCE_FORM"] = sourceSubview["SOURCE_FORM"]
    subview["LINK_FIELD"] = sourceSubview["LINK_FIELD"]
    subview["COLUMNS"] = app~copySubviewSpecs(sourceSubview["COLUMNS"])
    subview["ROW_CALCS"] = app~copySubviewSpecs(sourceSubview["ROW_CALCS"])
    subview["COLUMN_CALCS"] = app~copySubviewSpecs(sourceSubview["COLUMN_CALCS"])
    designSubviews~append(subview)
  end
  activeSubview = .nil
  mode = "DESIGN"
  screen~table = .nil
  screen~detail = .nil
  self~refreshDesignForm
  status = "Improving " || designName || ". Existing fields are protected; add fields/subviews, then SAVE."
  return self

::method handleDesignInput
  expose app status designName designFields designSubviews activeSubview designEditing mode
  use strict arg line
  upperLine = line~upper~strip
  if upperLine = "SAVE" | upperLine = "SAVE FORMAT" | upperLine = "SAVE DOCUMENT FORMAT" then do
    if designFields~items = 0 then do
      status = "Add at least one field before saving."
      return self
    end
    if designEditing then do
      evolution = app~evolveUserFormat(designName, designFields)
      if evolution["STATUS"] \= "OK" then do
        status = "FORMAT EVOLUTION REFUSED: " || evolution["DETAIL"]
        return self
      end
    end
    else self~app~installUserFormat(designName, designFields)
    do subview over designSubviews
      app~installSubviewDefinition(designName, subview["NAME"], subview["SOURCE_FORM"], subview["LINK_FIELD"], subview["COLUMNS"], subview["ROW_CALCS"], subview["COLUMN_CALCS"])
    end
    savedName = designName
    designName = ""
    designFields = .Array~new
    designSubviews = .Array~new
    activeSubview = .nil
    designEditing = .false
    mode = "LIST"
    self~showDocuments
    status = "Saved document format " || savedName || ". Type: complete a " || savedName
    return self
  end
  if upperLine = "CANCEL" then do
    designName = ""
    designFields = .Array~new
    designSubviews = .Array~new
    activeSubview = .nil
    designEditing = .false
    mode = "LIST"
    self~showDocuments
    status = "Document-format design cancelled."
    return self
  end
  if upperLine~pos("INSERT SUBVIEW ") = 1 then do
    prefix = line~upper~pos("INSERT SUBVIEW ") + 15
    fromPos = line~upper~pos(" FROM ")
    if fromPos = 0 then do
      status = "Say: insert subview Sales Lines from Sales Line linked by Order"
      return self
    end
    subviewName = line~substr(prefix, fromPos - prefix)~strip
    afterFrom = line~substr(fromPos + 6)
    linkedPos = afterFrom~upper~pos(" LINKED BY ")
    if linkedPos = 0 then do
      status = "Say: insert subview Sales Lines from Sales Line linked by Order"
      return self
    end
    sourceForm = afterFrom~left(linkedPos - 1)~strip
    linkField = afterFrom~substr(linkedPos + 11)~strip
    sourceCanonical = app~documentFormatCanonicalName(sourceForm)
    if sourceCanonical = "" then do
      status = "Unknown subview row format: " || sourceForm
      return self
    end
    subview = .Directory~new
    subview["NAME"] = subviewName
    subview["SOURCE_FORM"] = sourceCanonical
    subview["LINK_FIELD"] = self~canonicalFieldName(linkField)
    subview["COLUMNS"] = .Array~new
    subview["ROW_CALCS"] = .Array~new
    subview["COLUMN_CALCS"] = .Array~new
    designSubviews~append(subview)
    activeSubview = subview
    self~refreshDesignForm
    status = "Inserted subview " || subviewName || ". Add SUBVIEW COLUMN, ROW CALCULATED, or COLUMN CALCULATED definitions."
    return self
  end
  if upperLine~pos("SUBVIEW COLUMN ") = 1 then do
    if activeSubview == .nil then do
      status = "Insert a subview first."
      return self
    end
    specText = line~substr(16)~strip
    asPos = specText~upper~pos(" AS ")
    binding = specText
    label = specText
    if asPos > 0 then do
      binding = specText~left(asPos - 1)~strip
      label = specText~substr(asPos + 4)~strip
    end
    column = .Directory~new
    column["NAME"] = self~canonicalFieldName(label)
    column["LABEL"] = label
    column["BINDING"] = binding
    activeSubview["COLUMNS"]~append(column)
    self~refreshDesignForm
    status = "Added subview column " || label || "."
    return self
  end
  if upperLine~pos("ROW CALCULATED ") = 1 then do
    if activeSubview == .nil then do
      status = "Insert a subview first."
      return self
    end
    calcText = line~substr(16)~strip
    eqPos = calcText~pos("=")
    if eqPos = 0 then do
      status = "Say: row calculated Total = Product.Price * Quantity"
      return self
    end
    label = calcText~left(eqPos - 1)~strip
    expression = calcText~substr(eqPos + 1)~strip
    calc = .Directory~new
    calc["NAME"] = self~canonicalFieldName(label)
    calc["LABEL"] = label
    calc["EXPR"] = expression
    calc["RESULT_TYPE"] = "NUMBER"
    activeSubview["ROW_CALCS"]~append(calc)
    self~refreshDesignForm
    status = "Added row calculated field " || label || "."
    return self
  end
  if upperLine~pos("COLUMN CALCULATED ") = 1 then do
    if activeSubview == .nil then do
      status = "Insert a subview first."
      return self
    end
    calcText = line~substr(19)~strip
    eqPos = calcText~pos("=")
    if eqPos = 0 then do
      status = "Say: column calculated Order Total = SUM(Total)"
      return self
    end
    label = calcText~left(eqPos - 1)~strip
    expression = calcText~substr(eqPos + 1)~strip
    openPos = expression~pos("(")
    closePos = expression~lastPos(")")
    if openPos = 0 | closePos <= openPos then do
      status = "Column calculation must be an aggregate such as SUM(Total)."
      return self
    end
    calc = .Directory~new
    calc["NAME"] = self~canonicalFieldName(label)
    calc["LABEL"] = label
    calc["OP"] = expression~left(openPos - 1)~strip~upper
    calc["SOURCE"] = self~canonicalFieldName(expression~substr(openPos + 1, closePos - openPos - 1)~strip)
    calc["RESULT_TYPE"] = "NUMBER"
    activeSubview["COLUMN_CALCS"]~append(calc)
    self~refreshDesignForm
    status = "Added column calculated field " || label || "."
    return self
  end
  if upperLine~pos("THAT FIELD IS IN ") = 1 then do
    if designFields~items = 0 then do
      status = "There is no previous field to give a timezone."
      return self
    end
    spec = designFields[designFields~items]
    if spec["TYPE"]~upper \== "DATETIME" then do
      status = "Timezone metadata is only valid for a DATETIME field."
      return self
    end
    zone = line~substr(18)~strip
    if zone == "" then do
      status = "Name an IANA timezone, for example Europe/London."
      return self
    end
    spec["TIME_ZONE"] = zone
    self~refreshDesignForm
    status = "Field " || spec["LABEL"] || " now uses timezone " || zone || "."
    return self
  end
  if upperLine == "USE EARLIER" | upperLine == "USE LATER" then do
    if designFields~items = 0 then do
      status = "There is no previous field to give an ambiguity policy."
      return self
    end
    spec = designFields[designFields~items]
    if spec["TYPE"]~upper \== "DATETIME" then do
      status = "An ambiguity policy is only valid for a DATETIME field."
      return self
    end
    if upperLine == "USE EARLIER" then spec["AMBIGUITY_POLICY"] = "EARLIER"
    else spec["AMBIGUITY_POLICY"] = "LATER"
    self~refreshDesignForm
    status = "Field " || spec["LABEL"] || " ambiguity policy is " || spec["AMBIGUITY_POLICY"] || "."
    return self
  end
  if upperLine~pos("THAT FIELD REFERS TO MANY ") = 1 then do
    if designFields~items = 0 then do
      status = "There is no previous field to turn into a multi-reference."
      return self
    end
    targetText = line~substr(26)~strip
    target = app~documentFormatCanonicalName(targetText)
    if target = "" then do
      singular = targetText
      if singular~right(1)~upper = "S" then singular = singular~left(singular~length - 1)
      target = app~documentFormatCanonicalName(singular)
    end
    if target = "" then target = targetText
    spec = designFields[designFields~items]
    spec["TYPE"] = "DOCUMENT_REFERENCE"
    spec["REF_TARGET"] = target
    spec["CARDINALITY"] = "MANY"
    self~refreshDesignForm
    status = "Field " || spec["LABEL"] || " now refers to many " || target || " documents."
    return self
  end
  if upperLine~pos("THAT FIELD REFERS TO ") = 1 then do
    if designFields~items = 0 then do
      status = "There is no previous field to turn into a reference."
      return self
    end
    targetText = line~substr(22)~strip
    target = app~documentFormatCanonicalName(targetText)
    if target = "" then do
      status = "Unknown target document format: " || targetText
      return self
    end
    spec = designFields[designFields~items]
    spec["TYPE"] = "DOCUMENT_REFERENCE"
    spec["REF_TARGET"] = target
    self~refreshDesignForm
    status = "Field " || spec["LABEL"] || " now refers to " || target || "."
    return self
  end
  if upperLine~pos("I NEED A USER") = 1 then do
    self~addDesignField("User", "USER_REFERENCE")
    status = "Added User (USER_REFERENCE). Add another field or SAVE."
    return self
  end
  if upperLine~pos("I NEED A FIELD FOR") = 1 then do
    label = self~extractFieldLabel(line)
    if label = "" then do
      status = "Say for example: I need a field for the 'TPS Number'"
      return self
    end
    semanticType = self~inferFieldType(label)
    self~addDesignField(label, semanticType)
    status = "Added " || label || " (" || semanticType || "). Add another field or SAVE."
    return self
  end
  if upperLine~pos("I NEED MANY ") = 1 then do
    candidate = line~substr(13)~strip
    target = app~documentFormatCanonicalName(candidate)
    if target = "" then do
      singular = candidate
      if singular~right(1)~upper = "S" then singular = singular~left(singular~length - 1)
      target = app~documentFormatCanonicalName(singular)
    end
    if target = "" then target = candidate
    self~addDesignReferenceField(candidate, target, "MANY")
    status = "Added " || candidate || " (DOCUMENT_REFERENCE MANY -> " || target || ")."
    return self
  end
  if upperLine~pos("I NEED AN ") = 1 then do
    candidate = line~substr(11)~strip
    target = app~documentFormatCanonicalName(candidate)
    if target = "" then target = candidate
    self~addDesignReferenceField(candidate, target)
    status = "Added " || candidate || " (DOCUMENT_REFERENCE -> " || target || ")."
    return self
  end
  if upperLine~pos("I NEED A ") = 1 then do
    candidate = line~substr(10)~strip
    target = app~documentFormatCanonicalName(candidate)
    if target = "" then target = candidate
    self~addDesignReferenceField(candidate, target)
    status = "Added " || candidate || " (DOCUMENT_REFERENCE -> " || target || ")."
    return self
  end
  status = "Design wizard: use 'I need a field for ...', 'I need a user', SAVE, or CANCEL."
  return self

::method addDesignField
  expose designFields
  use strict arg label, semanticType
  spec = .Directory~new
  spec~put(self~canonicalFieldName(label), "NAME")
  spec~put(label, "LABEL")
  spec~put(semanticType, "TYPE")
  designFields~append(spec)
  self~refreshDesignForm
  return spec

::method addDesignReferenceField
  expose designFields
  use strict arg label, targetForm, cardinality = "ONE"
  spec = .Directory~new
  spec["NAME"] = self~canonicalFieldName(label)
  spec["LABEL"] = label
  spec["TYPE"] = "DOCUMENT_REFERENCE"
  spec["REF_TARGET"] = targetForm
  spec["CARDINALITY"] = cardinality~string~upper
  designFields~append(spec)
  self~refreshDesignForm
  return spec

::method refreshDesignForm
  expose screen designName designFields designSubviews
  form = .CliUiFormModel~new("Document Format Wizard")
  form~addField(.CliUiField~new("FORMAT", "Format", designName, .false))
  n = 0
  do spec over designFields
    n = n + 1
    fieldSummary = spec["LABEL"] || " [" || spec["TYPE"]
    if spec["TYPE"]~upper = "DOCUMENT_REFERENCE" then do
      cardinality = "ONE"
      if spec~hasIndex("CARDINALITY") then cardinality = spec["CARDINALITY"]
      fieldSummary = fieldSummary || " " || cardinality
      if spec~hasIndex("REF_TARGET") then fieldSummary = fieldSummary || " -> " || spec["REF_TARGET"]
    end
    if spec["TYPE"]~upper = "DATETIME" then do
      if spec~hasIndex("TIME_ZONE") then fieldSummary = fieldSummary || " @ " || spec["TIME_ZONE"]
      if spec~hasIndex("AMBIGUITY_POLICY") then fieldSummary = fieldSummary || " " || spec["AMBIGUITY_POLICY"]
    end
    fieldSummary = fieldSummary || "]"
    form~addField(.CliUiField~new("FIELD" || n, "Field " || n, fieldSummary, .false))
  end
  do subview over designSubviews
    n = n + 1
    summary = subview["NAME"] || " <- " || subview["SOURCE_FORM"] || " by " || subview["LINK_FIELD"]
    form~addField(.CliUiField~new("SUBVIEW" || n, "Subview", summary, .false))
  end
  screen~table = .nil
  screen~detail = .nil
  screen~form = form
  screen~navigation = .array~of("Describe fields in the command line", "SAVE finish", "CANCEL abort")
  return self

::method startCompose
  expose app screen mode status composeName composeFields composeValues composeIndex
  use strict arg formatName
  formatName = formatName~strip
  if formatName = "" then do
    status = "Name the document format to complete."
    return self
  end
  canonicalName = app~userFormatCanonicalName(formatName)
  if canonicalName = "" then do
    status = "Unknown user document format: " || formatName
    return self
  end
  fields = app~userFormatFields(canonicalName)
  composeName = canonicalName
  composeFields = fields
  composeValues = .Directory~new
  composeIndex = 1
  mode = "COMPOSE"
  self~refreshComposeForm
  status = self~composePrompt
  return self

::method handleComposeInput
  expose app mode status composeName composeFields composeValues composeIndex
  use strict arg line
  if line~upper~strip = "CANCEL" then do
    mode = "LIST"
    self~showDocuments
    status = "Document completion cancelled."
    return self
  end
  if composeIndex < 1 | composeIndex > composeFields~items then return self
  spec = composeFields[composeIndex]
  value = self~extractComposeValue(line, spec["LABEL"])
  composeValues~put(value, spec["NAME"])
  composeIndex = composeIndex + 1
  if composeIndex > composeFields~items then do
    document = app~createUserDocument(composeName, composeFields, composeValues)
    mode = "LIST"
    self~showDocuments
    if document == .nil then do
      status = "Could not create " || composeName
      return self
    end
    app~select(document~DocKey)
    self~selectByKey(document~DocKey)
    self~openSelected
    status = "Completed " || document~DocKey || " from " || composeName || ". SAVED to " || app~persistenceRoot || "."
    return self
  end
  self~refreshComposeForm
  status = self~composePrompt
  return self

::method refreshComposeForm
  expose screen composeName composeFields composeValues composeIndex
  form = .CliUiFormModel~new("Complete " || composeName)
  n = 0
  do spec over composeFields
    n = n + 1
    value = ""
    if composeValues~hasIndex(spec["NAME"]) then value = composeValues[spec["NAME"]]
    form~addField(.CliUiField~new(spec["NAME"], spec["LABEL"], value, .false))
  end
  screen~table = .nil
  screen~detail = .nil
  screen~form = form
  screen~navigation = .array~of("Enter requested value", "CANCEL abort")
  return self

::method composePrompt
  expose composeFields composeIndex
  if composeIndex < 1 | composeIndex > composeFields~items then return ""
  spec = composeFields[composeIndex]
  promptText = "Enter " || spec["LABEL"] || " (" || spec["TYPE"]
  if spec["TYPE"]~upper = "DOCUMENT_REFERENCE" then do
    if spec~hasIndex("CARDINALITY") then if spec["CARDINALITY"]~upper = "MANY" then promptText = promptText || " MANY; comma-separate references"
  end
  return promptText || ")"

::method extractFieldLabel
  use strict arg line
  singleStart = pos("'", line)
  if singleStart > 0 then do
    singleEnd = pos("'", line, singleStart + 1)
    if singleEnd > singleStart then return line~substr(singleStart + 1, singleEnd - singleStart - 1)~strip
  end
  doubleStart = pos('"', line)
  if doubleStart > 0 then do
    doubleEnd = pos('"', line, doubleStart + 1)
    if doubleEnd > doubleStart then return line~substr(doubleStart + 1, doubleEnd - doubleStart - 1)~strip
  end
  cue = "FOR "
  cuePos = line~upper~pos(cue)
  if cuePos > 0 then return line~substr(cuePos + cue~length)~strip
  return ""

::method canonicalFieldName
  use strict arg label
  normalized = label~changestr("'", " ")
  normalized = normalized~changestr('"', " ")
  normalized = normalized~changestr("-", " ")
  normalized = normalized~changestr("_", " ")
  normalized = normalized~changestr("/", " ")~strip
  if normalized~upper~left(4) = "THE " then normalized = normalized~substr(5)~strip
  name = self~canonicalWords(normalized, 1, "")
  if name = "" then name = "Field"
  return name

::method canonicalWords
  use strict arg normalized, index, result
  if index > normalized~words then return result
  word = normalized~word(index)
  nextResult = result || word~left(1)~upper || word~substr(2)
  return self~canonicalWords(normalized, index + 1, nextResult)

::method inferFieldType
  use strict arg label
  upperLabel = label~upper
  if upperLabel~pos("USER") > 0 then return "USER_REFERENCE"
  if upperLabel~pos("OWNER") > 0 then return "USER_REFERENCE"
  if upperLabel~pos("ASSIGNEE") > 0 then return "USER_REFERENCE"
  if upperLabel~pos("NUMBER") > 0 then return "IDENTIFIER"
  if upperLabel~pos("ID") > 0 then return "IDENTIFIER"
  if upperLabel~pos("DATETIME") > 0 then return "DATETIME"
  if upperLabel~pos("DATE AND TIME") > 0 then return "DATETIME"
  if upperLabel~pos("TIME") > 0 then return "DATETIME"
  if upperLabel~pos("DATE") > 0 then return "DATE"
  if upperLabel~pos("AMOUNT") > 0 then return "MONEY"
  if upperLabel~pos("VALUE") > 0 then return "MONEY"
  if upperLabel~pos("COST") > 0 then return "MONEY"
  return "TEXT"

::method extractComposeValue
  use strict arg line, label
  text = line~strip
  upperText = text~upper
  marker = " IS "
  markerPos = upperText~pos(marker)
  if markerPos > 0 then return text~substr(markerPos + marker~length)~strip
  eqPos = text~pos("=")
  if eqPos > 0 then return text~substr(eqPos + 1)~strip
  return text

::requires 'src/MiniNotesApp.cls'
::requires 'vendor/cliui/rexx/CliUiModels.cls'
::requires 'vendor/cliui/rexx/CliUiForm.cls'
::requires 'vendor/cliui/rexx/CliUiProjection.cls'
::requires 'vendor/cliui/rexx/CliUiScreen.cls'
::requires 'vendor/cliui/rexx/CliUiSemantic.cls'
