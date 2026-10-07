/* SpreadsheetIntentions.cls
 * Dynamic intention surface over discovered spreadsheet relations.
 *
 * The provider does not assume that a workbook is a database.  It consumes the
 * current discovery catalog each time an environment is refreshed and proposes
 * read-only meanings with plans.  The workbook remains the data authority.
 */

::class SpreadsheetIntentEnvironment public
::method init
  expose workbook catalog service runtime
  use arg workbook
  if workbook == .nil then raise syntax 93.900 array("Spreadsheet workbook is required")
  self~refresh
::attribute workbook get
::attribute catalog get
::attribute service get
::attribute runtime get
::method refresh
  expose workbook catalog service runtime
  catalog = .SpreadsheetRelationDiscoverer~new~discover(workbook)
  service = .IntentionService~new
  service~registerBucket("SPREADSHEET", .IntentionBucketPolicy~new("FLEXIBLE", 55, 8, .false, .false))

  listReg = service~register("list spreadsheet sheets", .nil, "SPREADSHEET")
  relationListReg = service~register("list spreadsheet relations", .nil, "SPREADSHEET")
  describeReg = service~register("describe spreadsheet relation", .nil, "SPREADSHEET")
  searchReg = service~register("search spreadsheet records", .nil, "SPREADSHEET")
  countReg = service~register("count spreadsheet records", .nil, "SPREADSHEET")
  sumReg = service~register("sum spreadsheet field", .nil, "SPREADSHEET")
  formulaReg = service~register("list spreadsheet formulas", .nil, "SPREADSHEET")
  auditReg = service~register("audit spreadsheet types", .nil, "SPREADSHEET")
  relationshipReg = service~register("list spreadsheet relationships", .nil, "SPREADSHEET")
  relatedSearchReg = service~register("search related spreadsheet records", .nil, "SPREADSHEET")

  planBuilder = .SpreadsheetReadPlanBuilder~new
  listReg~planBuilder(planBuilder)
  relationListReg~planBuilder(planBuilder)
  describeReg~planBuilder(planBuilder)
  searchReg~planBuilder(planBuilder)
  countReg~planBuilder(planBuilder)
  sumReg~planBuilder(planBuilder)
  formulaReg~planBuilder(planBuilder)
  auditReg~planBuilder(planBuilder)
  relationshipReg~planBuilder(planBuilder)
  relatedSearchReg~planBuilder(planBuilder)

  listReg~alias("list sheets")
  listReg~alias("what sheets")
  relationListReg~alias("list relations")
  relationListReg~alias("what tables")
  relationListReg~alias("what can I search")
  formulaReg~alias("find formulas")
  auditReg~alias("find type hazards")
  auditReg~alias("audit workbook")
  relationshipReg~alias("list relationships")
  relationshipReg~alias("show relationships")
  relationshipReg~alias("how are sheets related")

  relations = catalog~relations
  loop i = 1 to relations~items
    relation = relations~at(i)
    relationName = relation~name
    fields = relation~fields
    fieldText = ""
    loop j = 1 to fields~items
      if j > 1 then fieldText = fieldText || ", "
      fieldText = fieldText || fields~at(j)~name || ":" || fields~at(j)~inferredType
    end
    metadata = .Directory~new
    metadata~put("SPREADSHEET", "SPHERE")
    metadata~put(relationName, "RELATION")
    service~feed("SPREADSHEET", "relation " || relationName || " fields " || fieldText, -
        "spreadsheet-discovery", metadata)
  end

  provider = .SpreadsheetIntentionProvider~new(catalog)
  service~registerProvider(provider)
  spec = .Directory~new
  spec~put("spreadsheet", "LANGUAGE")
  sphere = service~registerSphere("SPREADSHEET", spec, .SpreadsheetPurposeInterrogator~new(catalog))
  sphere~alias("SHEET")
  sphere~alias("WORKBOOK")
  runtime = .SpreadsheetIntentRuntime~new(service, catalog)
  return self
::method input
  expose runtime
  use arg text
  return runtime~input(text)

::class SpreadsheetIntentionProvider public
::method init
  expose analyzer
  use arg catalog
  analyzer = .SpreadsheetIntentAnalyzer~new(catalog)
::method name
  return "SPREADSHEET_INTERROGATOR"
::method propose
  expose analyzer
  use arg service, text
  return analyzer~propose(text)

::class SpreadsheetPurposeInterrogator public
::method init
  expose analyzer
  use arg catalog
  analyzer = .SpreadsheetIntentAnalyzer~new(catalog)
::method interrogate
  expose analyzer
  use arg situation
  proposals = analyzer~propose(situation~body)
  purpose = ""
  evidence = ""
  if proposals~items > 0 then do
    purpose = proposals~at(1)~intentionId
    evidence = proposals~at(1)~evidence
  end
  return .IntentionInterrogationResult~new(proposals, purpose, evidence)

::class SpreadsheetIntentAnalyzer public
::method init
  expose catalog
  use arg catalog
::method propose
  expose catalog
  use arg text
  normalized = translate(strip(text))
  if normalized == "" then return .Array~new
  out = .Array~new

  if self~containsAny(normalized, .Array~of("LIST SHEETS", "WHAT SHEETS", "SHEET NAMES", "WORKSHEETS")) then do
    out~append(self~proposal("LIST_SPREADSHEET_SHEETS", 99, "workbook sheet inventory"))
    return out
  end
  if self~containsAny(normalized, .Array~of("FIND FORMULAS", "LIST FORMULAS", "FORMULA CELLS", "SHOW FORMULAS")) then do
    out~append(self~proposal("LIST_SPREADSHEET_FORMULAS", 99, "formula inventory"))
    return out
  end
  if self~containsAny(normalized, .Array~of("TYPE HAZARD", "TYPE HAZARDS", "MIXED TYPES", "NUMERIC TEXT", "AUDIT WORKBOOK", "AUDIT TYPES")) then do
    out~append(self~proposal("AUDIT_SPREADSHEET_TYPES", 99, "spreadsheet type/coercion hazards"))
    return out
  end
  if self~containsAny(normalized, .Array~of("LIST RELATIONSHIPS", "SHOW RELATIONSHIPS", "HOW ARE SHEETS RELATED", "SHEET RELATIONSHIPS")) then do
    out~append(self~proposal("LIST_SPREADSHEET_RELATIONSHIPS", 99, "discovered cross-sheet relationships"))
    return out
  end
  if self~containsAny(normalized, .Array~of("LIST RELATIONS", "WHAT TABLES", "WHAT CAN I SEARCH", "DISCOVERED TABLES", "DISCOVERED RELATIONS")) then do
    out~append(self~proposal("LIST_SPREADSHEET_RELATIONS", 99, "discovered spreadsheet relations"))
    return out
  end

  relatedProposal = self~relatedProposal(text, normalized)
  if relatedProposal \== .nil then do
    out~append(relatedProposal)
    return out
  end

  relation = self~matchRelation(normalized)
  if relation == .nil then return out

  if left(normalized, 8) == "DESCRIBE" | pos("COLUMNS", normalized) > 0 | pos("SCHEMA", normalized) > 0 then do
    proposal = self~proposal("DESCRIBE_SPREADSHEET_RELATION", 98, "discovered relation=" || relation~name)
    proposal~putSlot("RELATION", relation~name, .false)
    out~append(proposal)
    return out
  end

  if left(normalized, 5) == "COUNT" then do
    proposal = self~proposal("COUNT_SPREADSHEET_RECORDS", 98, "count relation=" || relation~name)
    proposal~putSlot("RELATION", relation~name, .false)
    groupField = self~fieldAfterKeyword(relation, normalized, " BY ")
    if groupField \== .nil then proposal~putSlot("GROUP_FIELD", groupField~name, .false)
    self~attachFilter(proposal, relation, text)
    out~append(proposal)
    return out
  end

  if left(normalized, 4) == "SUM " | left(normalized, 6) == "TOTAL " | pos(" TOTAL", normalized) > 0 then do
    field = self~matchField(relation, normalized)
    if field \== .nil then do
      proposal = self~proposal("SUM_SPREADSHEET_FIELD", 97, "sum relation=" || relation~name || ";field=" || field~name)
      proposal~putSlot("RELATION", relation~name, .false)
      proposal~putSlot("FIELD", field~name, .false)
      self~attachFilter(proposal, relation, text)
      out~append(proposal)
      return out
    end
  end

  proposal = self~proposal("SEARCH_SPREADSHEET_RECORDS", 95, "search relation=" || relation~name)
  proposal~putSlot("RELATION", relation~name, .false)
  self~attachFilter(proposal, relation, text)
  out~append(proposal)
  return out
::method relatedProposal
  expose catalog
  use arg originalText, normalized
  matches = self~matchRelations(normalized)
  if matches~items < 2 then return .nil
  resultRelation = matches~at(1)
  filterRelation = matches~at(2)
  links = catalog~relationshipsBetween(resultRelation~name, filterRelation~name)
  if links~items \== 1 then return .nil
  proposal = self~proposal("SEARCH_RELATED_SPREADSHEET_RECORDS", 99, -
      "related search=" || resultRelation~name || " via " || filterRelation~name)
  proposal~putSlot("RELATION", resultRelation~name, .false)
  proposal~putSlot("FILTER_RELATION", filterRelation~name, .false)
  link = links~at(1)
  proposal~putSlot("LINK_FROM_RELATION", link~fromRelation~name, .false)
  proposal~putSlot("LINK_FROM_FIELD", link~fromField~name, .false)
  proposal~putSlot("LINK_TO_RELATION", link~toRelation~name, .false)
  proposal~putSlot("LINK_TO_FIELD", link~toField~name, .false)
  self~attachRelatedFilter(proposal, filterRelation, originalText)
  if proposal~slot("FILTER_FIELD") == .nil then return .nil
  return proposal
::method matchRelations
  expose catalog
  use arg text
  found = .Array~new
  relations = catalog~relations
  loop i = 1 to relations~items
    relation = relations~at(i)
    candidate = translate(relation~name)
    singular = candidate
    if right(singular, 1) == "S" then singular = substr(singular, 1, length(singular) - 1)
    matched = pos(candidate, text) > 0
    if \matched then do
      if length(singular) >= 3 then matched = pos(singular, text) > 0
    end
    if matched then found~append(relation)
  end
  if found~items < 2 then return found
  ordered = .Array~new
  remaining = found~copy
  cursor = 1
  loop while remaining~items > 0
    bestIndex = 0
    bestPosition = 999999
    loop i = 1 to remaining~items
      relation = remaining~at(i)
      position = pos(translate(relation~name), text)
      if position == 0 then do
        singular = translate(relation~name)
        if right(singular, 1) == "S" then singular = substr(singular, 1, length(singular) - 1)
        position = pos(singular, text)
      end
      if position > 0 then do
        if position < bestPosition then do
          bestPosition = position
          bestIndex = i
        end
      end
    end
    if bestIndex == 0 then leave
    ordered~append(remaining~at(bestIndex))
    remaining~delete(bestIndex)
  end
  return ordered
::method attachRelatedFilter
  use arg proposal, relation, originalText
  upper = translate(originalText)
  fields = relation~fields
  loop i = 1 to fields~items
    field = fields~at(i)
    parsed = self~parseFieldFilter(field, originalText)
    if parsed \== .nil then do
      proposal~putSlot("FILTER_FIELD", field~name, .false)
      proposal~putSlot("FILTER_OP", parsed~at(1), .false)
      proposal~putSlot("FILTER_VALUE", parsed~at(2), .false)
      return proposal
    end
  end
  inPosition = pos(" IN ", upper)
  if inPosition > 0 then do
    value = strip(substr(originalText, inPosition + 4))
    matches = relation~fieldsContainingValue(value)
    if matches~items == 1 then do
      proposal~putSlot("FILTER_FIELD", matches~at(1)~name, .false)
      proposal~putSlot("FILTER_OP", "EQ", .false)
      proposal~putSlot("FILTER_VALUE", value, .false)
    end
  end
  return proposal
::method proposal
  use arg intentionId, score, evidence
  return .IntentionProposal~new(intentionId, score, "SPREADSHEET_INTERROGATOR", .false, evidence)
::method containsAny
  use arg text, needles
  loop i = 1 to needles~items
    if pos(needles~at(i), text) > 0 then return .true
  end
  return .false
::method matchRelation
  expose catalog
  use arg text
  relations = catalog~relations
  best = .nil
  bestLength = 0
  loop i = 1 to relations~items
    relation = relations~at(i)
    candidate = translate(relation~name)
    singular = candidate
    if right(singular, 1) == "S" then singular = substr(singular, 1, length(singular) - 1)
    matched = pos(candidate, text) > 0
    if \matched then do
      if length(singular) >= 3 then matched = pos(singular, text) > 0
    end
    if matched then do
      if length(candidate) > bestLength then do
        best = relation
        bestLength = length(candidate)
      end
    end
  end
  return best
::method matchField
  use arg relation, text
  fields = relation~fields
  best = .nil
  bestLength = 0
  loop i = 1 to fields~items
    field = fields~at(i)
    aliases = field~aliases
    loop j = 1 to aliases~items
      candidate = translate(strip(aliases~at(j)))
      if length(candidate) < 2 then iterate
      if pos(candidate, text) > 0 then do
        if length(candidate) > bestLength then do
          best = field
          bestLength = length(candidate)
        end
      end
    end
  end
  return best
::method fieldAfterKeyword
  use arg relation, text, keyword
  position = pos(keyword, text)
  if position == 0 then return .nil
  tail = strip(substr(text, position + length(keyword)))
  return self~matchField(relation, tail)
::method attachFilter
  use arg proposal, relation, originalText
  upper = translate(originalText)
  field = self~matchField(relation, upper)
  if field \== .nil then do
    parsed = self~parseFieldFilter(field, originalText)
    if parsed \== .nil then do
      proposal~putSlot("FILTER_FIELD", field~name, .false)
      proposal~putSlot("FILTER_OP", parsed~at(1), .false)
      proposal~putSlot("FILTER_VALUE", parsed~at(2), .false)
      return proposal
    end
  end

  inPosition = pos(" IN ", upper)
  if inPosition > 0 then do
    value = strip(substr(originalText, inPosition + 4))
    matches = relation~fieldsContainingValue(value)
    if matches~items == 1 then do
      proposal~putSlot("FILTER_FIELD", matches~at(1)~name, .false)
      proposal~putSlot("FILTER_OP", "EQ", .false)
      proposal~putSlot("FILTER_VALUE", value, .false)
      return proposal
    end
  end

  namedPosition = pos(" NAMED ", upper)
  if namedPosition > 0 then do
    value = strip(substr(originalText, namedPosition + 7))
    nameField = relation~field("Name")
    if nameField \== .nil then do
      proposal~putSlot("FILTER_FIELD", nameField~name, .false)
      proposal~putSlot("FILTER_OP", "CONTAINS", .false)
      proposal~putSlot("FILTER_VALUE", value, .false)
    end
  end
  return proposal
::method parseFieldFilter
  use arg field, originalText
  upper = translate(originalText)
  fieldName = translate(field~name)
  position = pos(fieldName, upper)
  if position == 0 then return .nil
  tail = strip(substr(originalText, position + length(fieldName)))
  upperTail = translate(tail)
  if left(tail, 2) == ">=" then return .Array~of("GE", strip(substr(tail, 3)))
  if left(tail, 2) == "<=" then return .Array~of("LE", strip(substr(tail, 3)))
  if left(tail, 2) == "<>" then return .Array~of("NE", strip(substr(tail, 3)))
  if left(tail, 1) == ">" then return .Array~of("GT", strip(substr(tail, 2)))
  if left(tail, 1) == "<" then return .Array~of("LT", strip(substr(tail, 2)))
  if left(tail, 1) == "=" then return .Array~of("EQ", strip(substr(tail, 2)))
  if left(upperTail, 3) == "IS " then return .Array~of("EQ", strip(substr(tail, 4)))
  if left(upperTail, 9) == "CONTAINS " then return .Array~of("CONTAINS", strip(substr(tail, 10)))
  return .nil

::class SpreadsheetReadPlanBuilder public
::method build
  use arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Read from the current spreadsheet model")
  plan~sideEffectClass = "READ_ONLY"
  relation = self~slotValue(proposal, "RELATION")
  field = self~slotValue(proposal, "FIELD")
  filterField = self~slotValue(proposal, "FILTER_FIELD")
  filterValue = self~slotValue(proposal, "FILTER_VALUE")
  filterRelation = self~slotValue(proposal, "FILTER_RELATION")
  linkFromField = self~slotValue(proposal, "LINK_FROM_FIELD")
  linkToField = self~slotValue(proposal, "LINK_TO_FIELD")
  if relation \== "" then plan~addStep("SELECT_RELATION", "Select discovered spreadsheet relation", relation)
  if filterRelation \== "" then plan~addStep("SELECT_RELATED_RELATION", "Select related spreadsheet relation", filterRelation)
  if linkFromField \== "" then plan~addStep("TRAVERSE_RELATIONSHIP", "Traverse discovered spreadsheet relationship", linkFromField || "->" || linkToField)
  if filterField \== "" then plan~addStep("FILTER", "Filter records", filterField || "=" || filterValue)
  if field \== "" then plan~addStep("PROJECT_FIELD", "Use spreadsheet field", field)
  plan~addStep("RETURN_RESULT", "Return values without recalculating workbook formulas", registration~id)
  plan~expectOutput("SPREADSHEET_RESULT")
  return plan
::method slotValue
  use arg proposal, name
  slot = proposal~slot(name)
  if slot == .nil then return ""
  return slot~value

::class SpreadsheetIntentRuntime public
::method init
  expose service catalog
  use arg service, catalog
::attribute service get
::attribute catalog get
::method input
  expose service
  use arg text
  decision = service~input(text)
  if decision~status \== "READY" then return .SpreadsheetIntentResult~new(decision, decision~question, .nil)
  return self~execute(decision)
::method execute
  expose catalog
  use arg decision
  proposal = decision~proposal
  intentionId = decision~registration~id
  select
    when intentionId == "LIST_SPREADSHEET_SHEETS" then do
      output = .Array~new
      sheets = catalog~workbook~sheets
      loop i = 1 to sheets~items
        row = .Directory~new
        row~put(sheets~at(i)~name, "SHEET")
        row~put(sheets~at(i)~hidden, "HIDDEN")
        row~put(sheets~at(i)~nonEmptyCount, "NONEMPTY_CELLS")
        output~append(row)
      end
      return .SpreadsheetIntentResult~new(decision, "sheet inventory", output)
    end
    when intentionId == "LIST_SPREADSHEET_RELATIONS" then return self~relations(decision)
    when intentionId == "DESCRIBE_SPREADSHEET_RELATION" then return self~describe(decision, proposal)
    when intentionId == "SEARCH_SPREADSHEET_RECORDS" then return self~search(decision, proposal)
    when intentionId == "COUNT_SPREADSHEET_RECORDS" then return self~count(decision, proposal)
    when intentionId == "SUM_SPREADSHEET_FIELD" then return self~sum(decision, proposal)
    when intentionId == "LIST_SPREADSHEET_FORMULAS" then return self~formulas(decision)
    when intentionId == "AUDIT_SPREADSHEET_TYPES" then return .SpreadsheetIntentResult~new(decision, "type audit", catalog~diagnostics)
    when intentionId == "LIST_SPREADSHEET_RELATIONSHIPS" then return self~relationships(decision)
    when intentionId == "SEARCH_RELATED_SPREADSHEET_RECORDS" then return self~relatedSearch(decision, proposal)
    otherwise return .SpreadsheetIntentResult~new(decision, "No spreadsheet executor for intention", .nil)
  end
::method relations
  expose catalog
  use arg decision
  output = .Array~new
  relations = catalog~relations
  loop i = 1 to relations~items
    relation = relations~at(i)
    row = .Directory~new
    row~put(relation~name, "RELATION")
    row~put(relation~sheet~name, "SHEET")
    row~put(relation~headerRow, "HEADER_ROW")
    row~put(relation~startColumn, "START_COLUMN")
    row~put(relation~endColumn, "END_COLUMN")
    row~put(relation~dataEndRow, "DATA_END_ROW")
    row~put(relation~records~items, "RECORDS")
    row~put(relation~confidence, "CONFIDENCE")
    output~append(row)
  end
  return .SpreadsheetIntentResult~new(decision, "relations=" || output~items, output)
::method relationFor
  expose catalog
  use arg proposal
  slot = proposal~slot("RELATION")
  if slot == .nil then return .nil
  return catalog~relation(slot~value)
::method filteredRows
  use arg relation, proposal
  fieldSlot = proposal~slot("FILTER_FIELD")
  if fieldSlot == .nil then return relation~records
  opSlot = proposal~slot("FILTER_OP")
  valueSlot = proposal~slot("FILTER_VALUE")
  op = "EQ"
  value = ""
  if opSlot \== .nil then op = opSlot~value
  if valueSlot \== .nil then value = valueSlot~value
  return relation~selectRows(fieldSlot~value, op, value)
::method describe
  use arg decision, proposal
  relation = self~relationFor(proposal)
  if relation == .nil then return .SpreadsheetIntentResult~new(decision, "relation not found", .nil)
  output = .Array~new
  fields = relation~fields
  loop i = 1 to fields~items
    field = fields~at(i)
    row = .Directory~new
    row~put(field~name, "FIELD")
    row~put(field~inferredType, "TYPE")
    row~put(field~confidence, "CONFIDENCE")
    row~put(field~probableKey, "PROBABLE_KEY")
    row~put(field~numericTextCount, "NUMERIC_TEXT")
    row~put(field~formulaCount, "FORMULAS")
    output~append(row)
  end
  return .SpreadsheetIntentResult~new(decision, "discovered relation " || relation~name || -
      " sheet=" || relation~sheet~name || " rows=" || relation~headerRow || "-" || relation~dataEndRow || -
      " columns=" || relation~startColumn || "-" || relation~endColumn, output)
::method search
  use arg decision, proposal
  relation = self~relationFor(proposal)
  if relation == .nil then return .SpreadsheetIntentResult~new(decision, "relation not found", .nil)
  rows = self~filteredRows(relation, proposal)
  return .SpreadsheetIntentResult~new(decision, "records=" || rows~items, rows)
::method count
  use arg decision, proposal
  relation = self~relationFor(proposal)
  if relation == .nil then return .SpreadsheetIntentResult~new(decision, "relation not found", .nil)
  groupSlot = proposal~slot("GROUP_FIELD")
  if groupSlot \== .nil then do
    grouped = relation~groupCount(groupSlot~value)
    return .SpreadsheetIntentResult~new(decision, "grouped count", grouped)
  end
  rows = self~filteredRows(relation, proposal)
  return .SpreadsheetIntentResult~new(decision, "count=" || rows~items, rows~items)
::method sum
  use arg decision, proposal
  relation = self~relationFor(proposal)
  if relation == .nil then return .SpreadsheetIntentResult~new(decision, "relation not found", .nil)
  fieldSlot = proposal~slot("FIELD")
  if fieldSlot == .nil then return .SpreadsheetIntentResult~new(decision, "field not found", .nil)
  rows = self~filteredRows(relation, proposal)
  total = relation~sum(fieldSlot~value, rows)
  return .SpreadsheetIntentResult~new(decision, "sum " || fieldSlot~value, total)
::method relationships
  expose catalog
  use arg decision
  out = .Array~new
  relationships = catalog~relationships
  loop i = 1 to relationships~items
    relationship = relationships~at(i)
    row = .Directory~new
    row~put(relationship~fromRelation~name, "FROM_RELATION")
    row~put(relationship~fromField~name, "FROM_FIELD")
    row~put(relationship~toRelation~name, "TO_RELATION")
    row~put(relationship~toField~name, "TO_FIELD")
    row~put(relationship~confidence, "CONFIDENCE")
    row~put(relationship~coverage, "COVERAGE")
    out~append(row)
  end
  return .SpreadsheetIntentResult~new(decision, "relationships=" || out~items, out)
::method relatedSearch
  expose catalog
  use arg decision, proposal
  resultRelation = self~relationFor(proposal)
  filterRelationSlot = proposal~slot("FILTER_RELATION")
  if resultRelation == .nil | filterRelationSlot == .nil then return .SpreadsheetIntentResult~new(decision, "related relation not found", .nil)
  filterRelation = catalog~relation(filterRelationSlot~value)
  if filterRelation == .nil then return .SpreadsheetIntentResult~new(decision, "related relation not found", .nil)
  filtered = self~filteredRows(filterRelation, proposal)
  allowedKeys = .Directory~new
  fromRelation = proposal~slot("LINK_FROM_RELATION")~value
  fromField = proposal~slot("LINK_FROM_FIELD")~value
  toRelation = proposal~slot("LINK_TO_RELATION")~value
  toField = proposal~slot("LINK_TO_FIELD")~value
  if translate(filterRelation~name) == translate(fromRelation) then filterKeyField = fromField
  else filterKeyField = toField
  if translate(resultRelation~name) == translate(fromRelation) then resultKeyField = fromField
  else resultKeyField = toField
  loop i = 1 to filtered~items
    key = translate(strip(filtered~at(i)~at(filterKeyField)))
    if key \== "" then allowedKeys~put(.true, key)
  end
  out = .Array~new
  rows = resultRelation~records
  loop i = 1 to rows~items
    key = translate(strip(rows~at(i)~at(resultKeyField)))
    if allowedKeys~hasIndex(key) then out~append(rows~at(i))
  end
  return .SpreadsheetIntentResult~new(decision, "related records=" || out~items, out)
::method formulas
  expose catalog
  use arg decision
  out = .Array~new
  sheets = catalog~workbook~sheets
  loop i = 1 to sheets~items
    sheet = sheets~at(i)
    cells = sheet~cells
    loop j = 1 to cells~items
      cell = cells~at(j)
      if \cell~hasFormula then iterate
      row = .Directory~new
      row~put(sheet~name, "SHEET")
      row~put(cell~address, "CELL")
      row~put(cell~formula, "FORMULA")
      row~put(cell~cachedValue, "CACHED_VALUE")
      out~append(row)
    end
  end
  return .SpreadsheetIntentResult~new(decision, "formula cells=" || out~items, out)

::class SpreadsheetIntentResult public
::method init
  expose decision summary data
  use arg decision, summary = "", data = .nil
::attribute decision get
::attribute summary get
::attribute data get

::requires "SpreadsheetRelations.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
