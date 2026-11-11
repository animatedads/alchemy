/*
  Live NotNotes -> Wire projection port.

  This consumer-side adapter never owns NotNotes business state and never owns
  Wire transport/session authority.  It turns live MiniNotesApp objects into a
  detached semantic projection and routes already-authorised semantic actions
  back into MiniNotesApp's public API.
*/
::class NotNotesWebProjectionPort public
::method init
  expose app semanticProvider observationProvider
  use strict arg app, semanticProvider=.nil, observationProvider=.nil

::method application
  expose app
  return app

::method project
  expose app observationProvider
  use strict arg viewText = "All Documents", queryText = "", selectedKey = "", offset = 0, limit = 50
  if limit < 1 then limit = 1
  if limit > 200 then limit = 200
  if offset < 0 then offset = 0

  if queryText~string~strip <> "" then documents = app~query(queryText)
  else do
    if viewText~string~strip~upper = "ALL DOCUMENTS" then documents = app~allDocuments
    else documents = app~viewDocuments(viewText)
  end

  if selectedKey~string~strip <> "" then selected = app~select(selectedKey)
  else selected = app~selected

  out = .Directory~new
  out["view"] = viewText
  out["query"] = queryText
  out["offset"] = offset
  out["limit"] = limit
  out["totalCount"] = documents~items
  out["rows"] = self~windowRows(documents, offset, limit)
  out["selectedKey"] = ""
  out["detail"] = .nil
  if selected \== .nil then do
    out["selectedKey"] = selected~DocKey
    out["detail"] = self~documentProjection(selected)
  end
  out["formats"] = app~userFormatNames
  out["reports"] = app~reportDefinitionNames
  if observationProvider \== .nil then out["observations"] = observationProvider~snapshot
  return out

::method windowRows private
  use strict arg documents, offset, limit
  rows = .Array~new
  first = offset + 1
  last = offset + limit
  if last > documents~items then last = documents~items
  if first > last then return rows
  do i = first to last
    d = documents[i]
    row = .Directory~new
    row["key"] = d~DocKey
    row["identity"] = d~documentId
    row["type"] = d~formName
    row["title"] = d~Title
    row["status"] = d~ApprovalStatus
    row["risk"] = d~Risk
    row["dependsOn"] = d~DependsOn
    row["revision"] = d~revision
    rows~append(row)
  end
  return rows

::method documentProjection private
  expose app semanticProvider
  use strict arg d
  out = .Directory~new
  out["key"] = d~DocKey
  out["identity"] = d~documentId
  out["type"] = d~formName
  out["title"] = d~Title
  out["amount"] = d~Amount
  out["status"] = d~ApprovalStatus
  out["risk"] = d~Risk
  out["dependsOn"] = d~DependsOn
  out["workflow"] = d~Workflow
  out["revision"] = d~revision
  fields = .Array~new
  do name over d~fieldNames
    f = .Directory~new
    f["name"] = name
    value = d~field(name)
    if value == .nil then value = ""
    f["value"] = value
    if semanticProvider \== .nil then do
      semantics = semanticProvider~fieldSemantics(d, name)
      if semantics \== .nil then f["semantics"] = semantics
    end
    fields~append(f)
  end
  out["fields"] = fields
  out["dependencyState"] = app~dependencyState(d)
  return out

::method perform
  expose app
  use strict arg action, detail = .nil
  if detail == .nil then detail = .Directory~new
  action = action~string~upper
  out = .Directory~new
  out["action"] = action
  out["ok"] = .false

  key = self~detailValue(detail, "key", "")
  if key <> "" then selected = app~select(key)
  else selected = app~selected

  select
    when action = "NOTNOTES.SELECT_DOCUMENT" | action = "NOTNOTES.OPEN_DOCUMENT" then do
      out["ok"] = selected \== .nil
    end
    when action = "NOTNOTES.CREATE_DOCUMENT" then do
      form = self~detailValue(detail, "type", "")~string~strip
      title = self~detailValue(detail, "title", "")~string~strip
      amount = self~detailValue(detail, "amount", "0")~string~strip
      risk = self~detailValue(detail, "risk", "LOW")~string~strip~upper
      depends = self~detailValue(detail, "dependsOn", "")~string~strip
      if title = "" then out["status"] = "TITLE_REQUIRED"
      else if form <> "Purchase Request" & form <> "Security Review" & form <> "Release Authorization" & form <> "Approval Document" then out["status"] = "UNKNOWN_DOCUMENT_TYPE"
      else if amount <> "" & \amount~datatype("N") then out["status"] = "INVALID_AMOUNT"
      else if risk <> "LOW" & risk <> "MEDIUM" & risk <> "HIGH" then out["status"] = "INVALID_RISK"
      else do
        valid = .true
        if depends <> "" then do dependency over depends~makeArray(",")
          if app~byKey(dependency~strip) == .nil then valid = .false
        end
        if \valid then out["status"] = "UNKNOWN_DEPENDENCY"
        else do
          prefix = "DOC-"
          select
            when form = "Purchase Request" then prefix = "PR-"
            when form = "Security Review" then prefix = "SEC-"
            when form = "Release Authorization" then prefix = "REL-"
            when form = "Approval Document" then prefix = "SUP-"
          end
          if amount = "" then amount = "0"
          key = app~nextKey(prefix)
          created = app~createDocument(form, key, title, amount, risk, depends)
          app~applyWorkflow(created)
          ignore = app~autoPersist
          ignore = app~select(key)
          out["key"] = key
          out["status"] = "CREATED"
          out["ok"] = .true
        end
      end
    end
    when action = "NOTNOTES.UPDATE_DOCUMENT" then do
      if selected == .nil then out["status"] = "NO_DOCUMENT_SELECTED"
      else do
        title = self~detailValue(detail, "title", "")~string~strip
        amount = self~detailValue(detail, "amount", "")~string~strip
        risk = self~detailValue(detail, "risk", "")~string~strip~upper
        if title = "" then out["status"] = "TITLE_REQUIRED"
        else if amount <> "" & \amount~datatype("N") then out["status"] = "INVALID_AMOUNT"
        else if risk <> "LOW" & risk <> "MEDIUM" & risk <> "HIGH" then out["status"] = "INVALID_RISK"
        else do
          selected~putField("Title", title)
          if amount <> "" then selected~putField("Amount", amount)
          selected~putField("Risk", risk)
          app~node~save(selected)
          ignore = app~autoPersist
          out["status"] = "UPDATED"
          out["ok"] = .true
        end
      end
    end
    when action = "NOTNOTES.SAVE" | action = "NOTNOTES.SAVE_DOCUMENT" then do
      out["ok"] = app~persistNow
    end
    when action = "NOTNOTES.SUBMIT" then do
      status = app~submitSelected(self~detailValue(detail, "note", "submitted from Web Wire"))
      out["status"] = status
      out["ok"] = status = "PENDING APPROVAL"
    end
    when action = "NOTNOTES.APPROVE" then do
      status = app~decideSelected("APPROVE", self~detailValue(detail, "note", "approved from Web Wire"))
      out["status"] = status
      out["ok"] = status = "APPROVED"
    end
    when action = "NOTNOTES.REJECT" then do
      status = app~decideSelected("REJECT", self~detailValue(detail, "note", "rejected from Web Wire"))
      out["status"] = status
      out["ok"] = status = "REJECTED"
    end
    when action = "NOTNOTES.SET_FIELD" then do
      if selected == .nil then out["status"] = "NO_DOCUMENT_SELECTED"
      else do
        out["ok"] = app~setUserDocumentField(selected, self~detailValue(detail, "field", ""), self~detailValue(detail, "value", ""))
        if out["ok"] then out["status"] = "UPDATED"
        else out["status"] = "FIELD_UPDATE_REJECTED"
      end
    end
    when action = "NOTNOTES.LINK_DOCUMENT" then do
      if selected == .nil then out["status"] = "NO_DOCUMENT_SELECTED"
      else do
        out["ok"] = app~addDocumentReference(selected, self~detailValue(detail, "field", ""), self~detailValue(detail, "target", ""))
        if out["ok"] then out["status"] = "LINKED"
        else out["status"] = "LINK_REJECTED"
      end
    end
    when action = "NOTNOTES.UNLINK_DOCUMENT" then do
      if selected == .nil then out["status"] = "NO_DOCUMENT_SELECTED"
      else do
        out["ok"] = app~removeDocumentReference(selected, self~detailValue(detail, "field", ""), self~detailValue(detail, "target", ""))
        if out["ok"] then out["status"] = "UNLINKED"
        else out["status"] = "UNLINK_REJECTED"
      end
    end
    when action = "NOTNOTES.RUN_REPORT" then do
      report = app~runReport(self~detailValue(detail, "report", ""))
      out["result"] = report
      out["ok"] = report["STATUS"] = "REPORTED"
    end
    otherwise do
      out["status"] = "HOST_ACTION_REQUIRED"
      out["detail"] = "Action remains owned by the NotNotes/Intention host adapter."
    end
  end
  return out

::method detailValue private
  use strict arg detail, name, fallback
  if detail~hasIndex(name) then return detail[name]
  upperName = name~upper
  if detail~hasIndex(upperName) then return detail[upperName]
  return fallback
