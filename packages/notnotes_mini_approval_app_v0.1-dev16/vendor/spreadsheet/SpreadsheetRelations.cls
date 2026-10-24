/* SpreadsheetRelations.cls
 * Conservative relational discovery over spreadsheet sheets.
 *
 * Discovery is evidence, not schema authority.  The catalog retains confidence
 * and type hazards instead of coercing visually plausible values into a clean
 * database model.
 */

::class SpreadsheetCatalog public
::method init
  expose workbook relations diagnostics relationships
  use arg workbook
  relations = .Array~new
  diagnostics = .Array~new
  relationships = .Array~new
::attribute workbook get
::method addRelation
  expose relations
  use arg relation
  if relation \== .nil then relations~append(relation)
  return self
::method relations
  expose relations
  return relations~copy
::method relation
  expose relations
  use arg name
  wanted = translate(strip(name))
  loop i = 1 to relations~items
    candidate = relations~at(i)
    if translate(candidate~name) == wanted then return candidate
    if translate(candidate~sheet~name) == wanted then return candidate
  end
  return .nil
::method addDiagnostic
  expose diagnostics
  use arg diagnostic
  if diagnostic \== .nil then diagnostics~append(diagnostic)
  return self
::method diagnostics
  expose diagnostics
  return diagnostics~copy
::method addRelationship
  expose relationships
  use arg relationship
  if relationship \== .nil then relationships~append(relationship)
  return self
::method relationships
  expose relationships
  return relationships~copy
::method relationshipsBetween
  expose relationships
  use arg firstName, secondName
  out = .Array~new
  first = translate(strip(firstName))
  second = translate(strip(secondName))
  loop i = 1 to relationships~items
    relationship = relationships~at(i)
    fromName = translate(relationship~fromRelation~name)
    toName = translate(relationship~toRelation~name)
    if fromName == first then do
      if toName == second then out~append(relationship)
    end
    else if fromName == second then do
      if toName == first then out~append(relationship)
    end
  end
  return out

::class SpreadsheetRelationship public
::method init
  expose fromRelation fromField toRelation toField confidence coverage evidence
  use arg fromRelation, fromField, toRelation, toField, confidence, coverage, evidence = ""
::attribute fromRelation get
::attribute fromField get
::attribute toRelation get
::attribute toField get
::attribute confidence get
::attribute coverage get
::attribute evidence get
::method describe
  expose fromRelation fromField toRelation toField confidence coverage
  return fromRelation~name || "." || fromField~name || " -> " || -
      toRelation~name || "." || toField~name || -
      " confidence=" || confidence || " coverage=" || coverage

::class SpreadsheetRelation public
::method init
  expose name sheet headerRow startColumn endColumn dataEndRow fields confidence evidence
  use arg name, sheet, headerRow, confidence = 0, evidence = "", startColumn = 1, endColumn = 0, dataEndRow = 0
  fields = .Array~new
  if endColumn == 0 then endColumn = sheet~maxColumn
  if dataEndRow == 0 then dataEndRow = sheet~maxRow
::attribute name get
::attribute sheet get
::attribute headerRow get
::attribute startColumn get
::attribute endColumn get
::attribute dataEndRow get
::attribute confidence get
::attribute evidence get
::method addField
  expose fields
  use arg field
  if field \== .nil then fields~append(field)
  return self
::method fields
  expose fields
  return fields~copy
::method field
  expose fields
  use arg name
  wanted = translate(strip(name))
  loop i = 1 to fields~items
    candidate = fields~at(i)
    if translate(candidate~name) == wanted then return candidate
    aliases = candidate~aliases
    loop j = 1 to aliases~items
      if translate(aliases~at(j)) == wanted then return candidate
    end
  end
  return .nil
::method fieldNames
  expose fields
  out = .Array~new
  loop i = 1 to fields~items
    out~append(fields~at(i)~name)
  end
  return out
::method records
  expose sheet headerRow dataEndRow fields
  out = .Array~new
  loop row = headerRow + 1 to dataEndRow
    record = .Directory~new
    populated = .false
    firstText = ""
    formulaCount = 0
    loop i = 1 to fields~items
      field = fields~at(i)
      cell = sheet~cellAt(row, field~column)
      value = ""
      if cell \== .nil then do
        value = cell~semanticValue
        if \cell~isBlank then do
          populated = .true
          if firstText == "" then firstText = translate(strip(value))
          if cell~hasFormula then formulaCount = formulaCount + 1
        end
      end
      record~put(value, field~name)
    end
    if \populated then iterate
    if self~isSummaryRow(firstText, formulaCount) then iterate
    record~put(row, "_ROW")
    record~put(sheet~name, "_SHEET")
    out~append(record)
  end
  return out
::method isSummaryRow
  expose fields
  use arg firstText, formulaCount
  label = translate(strip(firstText))
  if label == "TOTAL" | label == "TOTALS" | label == "SUBTOTAL" | label == "SUB-TOTAL" | label == "GRAND TOTAL" then return .true
  if left(label, 6) == "TOTAL " | left(label, 9) == "SUBTOTAL " | left(label, 12) == "GRAND TOTAL " then return .true
  if fields~items > 1 then do
    if formulaCount * 2 >= fields~items then return .true
  end
  return .false
::method selectRows
  use arg fieldName = "", operator = "", wanted = ""
  records = self~records
  if strip(fieldName) == "" then return records
  field = self~field(fieldName)
  if field == .nil then return .Array~new
  out = .Array~new
  op = translate(strip(operator))
  if op == "" then op = "EQ"
  loop i = 1 to records~items
    record = records~at(i)
    actual = record~at(field~name)
    if self~matches(actual, op, wanted, field~inferredType) then out~append(record)
  end
  return out
::method matches
  use arg actual, operator, wanted, inferredType
  op = translate(strip(operator))
  if op == "EQ" then return translate(strip(actual)) == translate(strip(wanted))
  if op == "NE" then return translate(strip(actual)) \== translate(strip(wanted))
  if op == "CONTAINS" then return pos(translate(wanted), translate(actual)) > 0
  if op == "STARTS" then return left(translate(actual), length(wanted)) == translate(wanted)
  if op == "GT" | op == "GE" | op == "LT" | op == "LE" then do
    if \datatype(actual, "N") then return .false
    if \datatype(wanted, "N") then return .false
    if op == "GT" then return actual > wanted
    if op == "GE" then return actual >= wanted
    if op == "LT" then return actual < wanted
    if op == "LE" then return actual <= wanted
  end
  return .false
::method fieldsContainingValue
  expose fields
  use arg wanted
  matches = .Array~new
  records = self~records
  loop fieldIndex = 1 to fields~items
    field = fields~at(fieldIndex)
    found = .false
    loop rowIndex = 1 to records~items
      value = records~at(rowIndex)~at(field~name)
      if translate(strip(value)) == translate(strip(wanted)) then do
        found = .true
        leave
      end
    end
    if found then matches~append(field)
  end
  return matches
::method sum
  use arg fieldName, selected = .nil
  field = self~field(fieldName)
  if field == .nil then return .nil
  if selected == .nil then selected = self~records
  total = 0
  count = 0
  loop i = 1 to selected~items
    record = selected~at(i)
    value = record~at(field~name)
    if datatype(value, "N") then do
      total = total + value
      count = count + 1
    end
  end
  if count == 0 then return .nil
  return total
::method groupCount
  use arg fieldName
  field = self~field(fieldName)
  if field == .nil then return .nil
  out = .Directory~new
  records = self~records
  loop i = 1 to records~items
    value = records~at(i)~at(field~name)
    if out~hasIndex(value) then out~put(out~at(value) + 1, value)
    else out~put(1, value)
  end
  return out

::class SpreadsheetField public
::method init
  expose name column inferredType confidence probableKey aliases numericTextCount formulaCount nonBlankCount typeCounts
  use arg name, column
  inferredType = "UNKNOWN"
  confidence = 0
  probableKey = .false
  aliases = .Array~new
  numericTextCount = 0
  formulaCount = 0
  nonBlankCount = 0
  typeCounts = .Directory~new
  self~deriveAliases
::attribute name get
::attribute column get
::attribute inferredType get
::attribute inferredType set
::attribute confidence get
::attribute confidence set
::attribute probableKey get
::attribute probableKey set
::attribute numericTextCount get
::attribute numericTextCount set
::attribute formulaCount get
::attribute formulaCount set
::attribute nonBlankCount get
::attribute nonBlankCount set
::method aliases
  expose aliases
  return aliases~copy
::method typeCounts
  expose typeCounts
  return typeCounts~copy
::method addType
  expose typeCounts
  use arg valueType
  key = translate(strip(valueType))
  if key == "" | key == "BLANK" then return self
  if typeCounts~hasIndex(key) then typeCounts~put(typeCounts~at(key) + 1, key)
  else typeCounts~put(1, key)
  return self
::method deriveAliases
  expose name aliases
  normalized = translate(strip(name))
  aliases~append(name)
  aliases~append(normalized)
  clean = normalized
  notePos = pos("[NOTE", clean)
  if notePos > 1 then clean = strip(substr(clean, 1, notePos - 1))
  linePos = pos(.endOfLine, clean)
  if linePos > 1 then clean = strip(substr(clean, 1, linePos - 1))
  if clean \== "" then do
    if clean \== normalized then aliases~append(clean)
  end
  words = changestr("_", normalized, " ")
  if words \== normalized then aliases~append(words)
  if pos(" ID", normalized) > 0 then aliases~append(changestr(" ID", normalized, ""))
  if normalized == "NAME" then aliases~append("NAMED")
  return self

::class SpreadsheetRegionCandidate public
::method init
  expose headerRow startColumn endColumn dataEndRow ordinal
  use arg headerRow, startColumn, endColumn, dataEndRow, ordinal = 1
::attribute headerRow get
::attribute startColumn get
::attribute endColumn get
::attribute dataEndRow get
::attribute ordinal get

::class SpreadsheetRelationDiscoverer public
::method discover
  use arg workbook
  catalog = .SpreadsheetCatalog~new(workbook)
  sheets = workbook~sheets
  declaredTables = workbook~declaredTables
  loop i = 1 to sheets~items
    sheet = sheets~at(i)
    candidates = self~declaredRegions(sheet, declaredTables)
    if candidates~items == 0 then candidates = self~findRegions(sheet)
    if candidates~items > 1 then catalog~addDiagnostic(.SpreadsheetDiagnostic~new( -
        "MULTIPLE_TABLE_REGIONS", "INFO", sheet~name, "", -
        "Sheet contains multiple discovered table-like regions.", -
        "Each region is modelled as an independent relation."))
    loop j = 1 to candidates~items
      relation = self~discoverRegion(sheet, candidates~at(j), candidates~items)
      if relation \== .nil then do
        catalog~addRelation(relation)
        self~diagnoseRelation(relation, catalog)
        self~diagnoseSummaryRows(relation, catalog)
      end
    end
  end
  self~discoverRelationships(catalog)
  return catalog
::method declaredRegions
  use arg sheet, declaredTables
  out = .Array~new
  ordinal = 0
  loop i = 1 to declaredTables~items
    declared = declaredTables~at(i)
    if translate(declared~sheetName) \== translate(sheet~name) then iterate
    bounds = self~referenceBounds(declared~reference)
    if bounds == .nil then iterate
    ordinal = ordinal + 1
    out~append(.SpreadsheetRegionCandidate~new(bounds~at(1), bounds~at(2), bounds~at(4), bounds~at(3), ordinal))
  end
  return out
::method referenceBounds
  use arg reference
  colon = pos(":", reference)
  if colon == 0 then return .nil
  first = .SpreadsheetAddress~rowColumn(substr(reference, 1, colon - 1))
  last = .SpreadsheetAddress~rowColumn(substr(reference, colon + 1))
  if first == .nil then return .nil
  if last == .nil then return .nil
  return .Array~of(first~at(1), first~at(2), last~at(1), last~at(2))
::method discoverSheet
  use arg sheet
  candidates = self~findRegions(sheet)
  if candidates~items == 0 then return .nil
  return self~discoverRegion(sheet, candidates~at(1), candidates~items)
::method discoverRegion
  use arg sheet, candidate, regionCount = 1
  headerRow = candidate~headerRow
  startColumn = candidate~startColumn
  endColumn = candidate~endColumn
  dataEndRow = candidate~dataEndRow
  fields = .Array~new
  textCount = 0
  loop column = startColumn to endColumn
    cell = sheet~cellAt(headerRow, column)
    if cell == .nil then iterate
    name = strip(cell~semanticValue)
    if name == "" then iterate
    if cell~valueType == "TEXT" then textCount = textCount + 1
    field = .SpreadsheetField~new(name, column)
    self~inferField(sheet, headerRow, field, dataEndRow, startColumn, endColumn)
    fields~append(field)
  end
  if fields~items < 2 then return .nil
  confidence = 55 + min(35, textCount * 5)
  if fields~items >= 3 then confidence = min(98, confidence + 5)
  regionName = self~regionName(sheet, fields, candidate, regionCount)
  relation = .SpreadsheetRelation~new(regionName, sheet, headerRow, confidence, -
      "header row=" || headerRow || "; columns=" || startColumn || "-" || endColumn || "; data end=" || dataEndRow, -
      startColumn, endColumn, dataEndRow)
  loop i = 1 to fields~items
    relation~addField(fields~at(i))
  end
  self~inferKeys(relation)
  return relation
::method regionName
  use arg sheet, fields, candidate, regionCount
  if regionCount == 1 then return sheet~name
  loop i = 1 to fields~items
    name = strip(fields~at(i)~name)
    upper = translate(name)
    if right(upper, 3) == " ID" then do
      stem = strip(substr(name, 1, length(name) - 3))
      if stem \== "" then do
        if right(translate(stem), 1) == "S" then return stem
        return stem || "s"
      end
    end
    if right(upper, 3) == "_ID" then do
      stem = strip(substr(name, 1, length(name) - 3))
      if stem \== "" then return stem || "s"
    end
  end
  return sheet~name || " Region " || candidate~ordinal
::method findRegions
  use arg sheet
  out = .Array~new
  ordinal = 0
  maximumRow = sheet~maxRow
  maximumColumn = sheet~maxColumn
  loop row = 1 to maximumRow
    column = 1
    loop while column <= maximumColumn
      if \self~headerCell(sheet, row, column) then do
        column = column + 1
        iterate
      end
      startColumn = column
      textish = 0
      nonBlank = 0
      loop while column <= maximumColumn
        cell = sheet~cellAt(row, column)
        if cell == .nil then leave
        if cell~isBlank then leave
        nonBlank = nonBlank + 1
        if cell~valueType == "TEXT" then textish = textish + 1
        column = column + 1
      end
      endColumn = column - 1
      if nonBlank >= 2 then do
        if textish * 2 >= nonBlank then do
          if self~headerBoundary(sheet, row, startColumn, endColumn) then do
            dataEndRow = self~regionDataEnd(sheet, row, startColumn, endColumn)
            if dataEndRow > row then do
              ordinal = ordinal + 1
              out~append(.SpreadsheetRegionCandidate~new(row, startColumn, endColumn, dataEndRow, ordinal))
            end
          end
        end
      end
      if column == startColumn then column = column + 1
    end
  end
  return out
::method headerCell
  use arg sheet, row, column
  cell = sheet~cellAt(row, column)
  if cell == .nil then return .false
  if cell~isBlank then return .false
  return cell~valueType == "TEXT"
::method headerBoundary
  use arg sheet, row, startColumn, endColumn
  if row == 1 then return .true
  return self~rowBlank(sheet, row - 1, startColumn, endColumn)
::method regionDataEnd
  use arg sheet, headerRow, startColumn, endColumn
  last = headerRow
  loop row = headerRow + 1 to sheet~maxRow
    if self~rowBlank(sheet, row, startColumn, endColumn) then leave
    last = row
  end
  return last
::method rowBlank
  use arg sheet, row, startColumn, endColumn
  loop column = startColumn to endColumn
    cell = sheet~cellAt(row, column)
    if cell \== .nil then do
      if \cell~isBlank then return .false
    end
  end
  return .true
::method summaryRow
  use arg sheet, row, startColumn, endColumn
  firstText = ""
  formulaCount = 0
  populated = 0
  fieldCount = endColumn - startColumn + 1
  loop column = startColumn to endColumn
    cell = sheet~cellAt(row, column)
    if cell == .nil then iterate
    if cell~isBlank then iterate
    populated = populated + 1
    if firstText == "" then firstText = translate(strip(cell~semanticValue))
    if cell~hasFormula then formulaCount = formulaCount + 1
  end
  if populated == 0 then return .false
  if firstText == "TOTAL" | firstText == "TOTALS" | firstText == "SUBTOTAL" | firstText == "SUB-TOTAL" | firstText == "GRAND TOTAL" then return .true
  if left(firstText, 6) == "TOTAL " | left(firstText, 9) == "SUBTOTAL " | left(firstText, 12) == "GRAND TOTAL " then return .true
  if fieldCount > 1 then do
    if formulaCount * 2 >= fieldCount then return .true
  end
  return .false
::method inferField
  use arg sheet, headerRow, field, dataEndRow = 0, startColumn = 1, endColumn = 0
  if dataEndRow == 0 then dataEndRow = sheet~maxRow
  if endColumn == 0 then endColumn = sheet~maxColumn
  nonBlank = 0
  numericText = 0
  formulas = 0
  loop row = headerRow + 1 to dataEndRow
    if self~summaryRow(sheet, row, startColumn, endColumn) then iterate
    cell = sheet~cellAt(row, field~column)
    if cell == .nil then iterate
    if cell~isBlank then iterate
    nonBlank = nonBlank + 1
    field~addType(cell~valueType)
    if cell~looksNumericText then numericText = numericText + 1
    if cell~hasFormula then formulas = formulas + 1
  end
  field~nonBlankCount = nonBlank
  field~numericTextCount = numericText
  field~formulaCount = formulas
  counts = field~typeCounts
  types = counts~items
  if nonBlank == 0 then do
    field~inferredType = "UNKNOWN"
    field~confidence = 0
    return field
  end
  if types == 1 then do
    supplier = counts~supplier
    supplier~next
    /* supplier starts available; reset via a fresh supplier for clarity. */
    supplier = counts~supplier
    if supplier~available then field~inferredType = supplier~index
    field~confidence = 95
  end
  else do
    field~inferredType = "MIXED"
    field~confidence = 60
  end
  if numericText > 0 then field~confidence = max(25, field~confidence - 20)
  return field
::method inferKeys
  use arg relation
  records = relation~records
  fields = relation~fields
  loop i = 1 to fields~items
    field = fields~at(i)
    normalized = translate(field~name)
    keyNamed = normalized == "ID" | right(normalized, 3) == " ID" | right(normalized, 3) == "_ID"
    if \keyNamed then iterate
    seen = .Directory~new
    unique = .true
    populated = 0
    loop j = 1 to records~items
      value = strip(records~at(j)~at(field~name))
      if value == "" then do
        unique = .false
        leave
      end
      populated = populated + 1
      marker = translate(value)
      if seen~hasIndex(marker) then do
        unique = .false
        leave
      end
      seen~put(.true, marker)
    end
    if unique then do
      if populated > 0 then field~probableKey = .true
    end
  end
::method discoverRelationships
  use arg catalog
  relations = catalog~relations
  loop sourceIndex = 1 to relations~items
    source = relations~at(sourceIndex)
    sourceFields = source~fields
    loop fieldIndex = 1 to sourceFields~items
      sourceField = sourceFields~at(fieldIndex)
      sourceName = translate(strip(sourceField~name))
      keyNamed = sourceName == "ID" | right(sourceName, 3) == " ID" | right(sourceName, 3) == "_ID"
      if \keyNamed then iterate
      loop targetIndex = 1 to relations~items
        if targetIndex == sourceIndex then iterate
        target = relations~at(targetIndex)
        targetField = target~field(sourceField~name)
        if targetField == .nil then iterate
        if \targetField~probableKey then iterate
        coverage = self~relationshipCoverage(source, sourceField, target, targetField)
        if coverage < 80 then iterate
        confidence = min(99, 80 + (coverage % 5))
        relationship = .SpreadsheetRelationship~new(source, sourceField, target, targetField, -
            confidence, coverage, "matching key field; observed value coverage")
        catalog~addRelationship(relationship)
      end
    end
  end
  return catalog
::method relationshipCoverage
  use arg sourceRelation, sourceField, targetRelation, targetField
  targetValues = .Directory~new
  targetRows = targetRelation~records
  loop i = 1 to targetRows~items
    value = translate(strip(targetRows~at(i)~at(targetField~name)))
    if value \== "" then targetValues~put(.true, value)
  end
  sourceRows = sourceRelation~records
  populated = 0
  matched = 0
  loop i = 1 to sourceRows~items
    value = translate(strip(sourceRows~at(i)~at(sourceField~name)))
    if value == "" then iterate
    populated = populated + 1
    if targetValues~hasIndex(value) then matched = matched + 1
  end
  if populated == 0 then return 0
  return (matched * 100) % populated

::method diagnoseSummaryRows
  use arg relation, catalog
  loop row = relation~headerRow + 1 to relation~dataEndRow
    if self~summaryRow(relation~sheet, row, relation~startColumn, relation~endColumn) then do
      catalog~addDiagnostic(.SpreadsheetDiagnostic~new( -
          "SUMMARY_ROW_EXCLUDED", "INFO", relation~sheet~name, "row " || row, -
          "Summary-like row was excluded from inferred records and field types.", -
          "relation=" || relation~name))
    end
  end
  return catalog
::method diagnoseRelation
  use arg relation, catalog
  fields = relation~fields
  sheetName = relation~sheet~name
  loop i = 1 to fields~items
    field = fields~at(i)
    if field~inferredType == "MIXED" then catalog~addDiagnostic(.SpreadsheetDiagnostic~new( -
        "MIXED_COLUMN_TYPE", "WARN", sheetName, field~name, -
        "Column contains multiple stored value types.", "Do not coerce by display appearance."))
    if field~numericTextCount > 0 then catalog~addDiagnostic(.SpreadsheetDiagnostic~new( -
        "NUMERIC_LOOKING_TEXT", "WARN", sheetName, field~name, -
        "Column contains text values that look numeric or currency-like.", -
        "Text remains text unless an explicit conversion policy says otherwise."))
    if field~formulaCount > 0 then catalog~addDiagnostic(.SpreadsheetDiagnostic~new( -
        "FORMULA_COLUMN", "INFO", sheetName, field~name, -
        "Column contains formula cells.", "Stored cached results are not independently recalculated."))
  end
  return catalog

::requires "SpreadsheetOpenFormats.cls"
