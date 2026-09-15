/*
 * X12RelationAdapter v0.4
 *
 * NoSQLServer-compatible external provider over rich X12 objects.
 * A relation is an explicit projection over transactions/segments.  Every
 * projected cell retains lexical value, source object, state and diagnostics.
 */

::class X12RelationColumn public
::attribute name get
::attribute type get
::attribute nullable get
::attribute unique get
::attribute primaryKey get
::attribute textMode get
::attribute selector get
::attribute cardinality get

::method init
  expose name type nullable unique primaryKey textMode selector cardinality
  use arg nameArg, selectorArg, typeArg = "VARCHAR", cardinalityArg = "ZERO_OR_ONE"
  name = nameArg~string
  selector = selectorArg~string
  type = typeArg~string~translate
  cardinality = cardinalityArg~string~translate
  nullable = .true
  unique = .false
  primaryKey = .false
  textMode = "CLASSIC"

::method coerce
  expose type name
  use arg value
  if value == .nil then return .nil
  if value~isA(.X12Selection) then raise syntax 93.900 additional("Refusing to coerce multi-valued X12 selection for" name)
  if value~isA(.X12Element) then raise syntax 93.900 additional("Refusing to flatten composite X12 element for" name)
  text = value~string
  select
    when type = "INTEGER" then do
      if \datatype(text, "W") then raise syntax 93.900 additional("Invalid INTEGER for" name || ":" text)
      return text
    end
    when type = "DECIMAL" then do
      if \datatype(text, "N") then raise syntax 93.900 additional("Invalid DECIMAL for" name || ":" text)
      return text
    end
    otherwise return text
  end

::method compare
  expose type
  use arg left, operator, right
  if left == .nil then return .false
  if right == .nil then return .false
  if left~isA(.X12Selection) then return .false
  if right~isA(.X12Selection) then return .false
  l = self~coerce(left)
  r = self~coerce(right)
  op = operator~string
  if type = "INTEGER" then return self~compareOrdered(l, op, r)
  if type = "DECIMAL" then return self~compareOrdered(l, op, r)
  select
    when op = "=" then return l == r
    when op = "<>" then return l \== r
    when op = "!=" then return l \== r
    when op = "<" then return l < r
    when op = "<=" then return l <= r
    when op = ">" then return l > r
    when op = ">=" then return l >= r
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end

::method compareOrdered private
  use arg left, op, right
  select
    when op = "=" then return left = right
    when op = "<>" then return left \= right
    when op = "!=" then return left \= right
    when op = "<" then return left < right
    when op = "<=" then return left <= right
    when op = ">" then return left > right
    when op = ">=" then return left >= right
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end


::class X12RelationDefinition public
::attribute name get
::attribute rootSelector get
::attribute columns get
::attribute columnNames get
::attribute document get
::attribute generation get
::attribute rowCount
::attribute metadata get

::method init
  expose name rootSelector columns columnNames document generation rowCount metadata
  use arg nameArg, documentArg, rootSelectorArg
  name = nameArg~string
  document = documentArg
  rootSelector = rootSelectorArg~string
  columns = .array~new
  columnNames = .array~new
  generation = 0
  rowCount = .nil
  metadata = .table~new
  metadata["adapter"] = "X12"
  metadata["rootSelector"] = rootSelector
  metadata["sourceDocument"] = document

::method columnMap
  expose columns columnNames
  use arg columnName, selector, type = "VARCHAR", cardinality = "ZERO_OR_ONE"
  if self~canonicalColumn(columnName) \== .nil then raise syntax 93.900 additional("Duplicate X12 relation column:" columnName)
  c = .X12RelationColumn~new(columnName, selector, type, cardinality)
  columns~append(c)
  columnNames~append(c~name)
  return self

::method canonicalColumn
  expose columnNames
  use arg wanted
  if wanted == .nil then return .nil
  wanted = wanted~string
  do name over columnNames
    if name~caselessEquals(wanted) then return name
  end
  return .nil

::method column
  expose columns
  use arg wanted
  canonical = self~canonicalColumn(wanted)
  if canonical == .nil then return .nil
  do c over columns
    if c~name == canonical then return c
  end
  return .nil


::class X12ProjectedRow public
::attribute values get
::attribute rawValues get
::attribute sources get
::attribute states get
::attribute cells get
::attribute diagnostics get
::attribute diagnosticsByColumn get
::attribute origin get
::attribute document get
::attribute projection get
::attribute createdAt get

::method init
  expose values rawValues sources states cells diagnostics diagnosticsByColumn origin document projection createdAt
  use arg valuesArg, rawValuesArg, sourcesArg, statesArg, diagnosticsArg, originArg, documentArg, projectionArg, diagnosticsByColumnArg = .nil
  values = valuesArg
  rawValues = rawValuesArg
  sources = sourcesArg
  states = statesArg
  diagnostics = diagnosticsArg
  if diagnosticsByColumnArg == .nil then diagnosticsByColumn = .table~new
  else diagnosticsByColumn = diagnosticsByColumnArg
  origin = originArg
  document = documentArg
  projection = projectionArg
  createdAt = .DateTime~new~utcIsoDate
  cells = .table~new
  do columnName over projection~columnNames
    column = projection~column(columnName)
    columnDiagnostics = diagnosticsByColumn[columnName]
    if columnDiagnostics == .nil then columnDiagnostics = .array~new
    cells[columnName] = .RichProjectionValue~new(columnName, column~type, values[columnName], rawValues[columnName], sources[columnName], self~stateFor(columnName), columnDiagnostics)
  end

::method "[]"
  expose values
  use arg name
  return values[name]

::method at
  expose values
  use arg name
  return values[name]

::method rawAt
  expose rawValues
  use arg name
  return rawValues[name]

::method sourceFor
  expose sources
  use arg name
  return sources[name]

::method stateFor
  expose states
  use arg name
  state = states[name]
  if state == .nil then return "UNKNOWN"
  return state

::method cell
  expose cells projection
  use arg name
  canonical = projection~canonicalColumn(name)
  if canonical == .nil then return .nil
  return cells[canonical]

::method fact
  use arg name
  cell = self~cell(name)
  if cell == .nil then return .nil
  return .X12BusinessFact~new(cell~name, cell~value, cell~state, cell~source, self, cell~semanticType, cell~lexicalValue, cell~diagnostics)

::method copy
  expose values rawValues sources states diagnostics origin document projection diagnosticsByColumn
  return .X12ProjectedRow~new(values~copy, rawValues~copy, sources~copy, states~copy, diagnostics~copy, origin, document, projection, diagnosticsByColumn~copy)

::method provenance
  expose origin document projection createdAt
  p = .table~new
  p["origin"] = origin
  p["document"] = document
  p["projection"] = projection
  p["createdAt"] = createdAt
  return p

::method string
  expose projection origin
  return "X12-PROJECTED-ROW(" || projection~name || "," || origin~path || ")"


::class X12RelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation
  use arg definitionArg
  definition = definitionArg
  generation = 0

::method rowCount
  expose definition
  count = definition~rowCount
  if count \== .nil then return count
  return self~readRows~items

::method readRows
  expose definition
  document = definition~document
  roots = document~select(definition~rootSelector)
  if roots~kind \= "NODESET" then raise syntax 93.900 additional("X12 relation root selector must yield a node set:" definition~rootSelector)

  rows = .array~new
  do origin over roots~nodes
    values = .table~new
    rawValues = .table~new
    sources = .table~new
    states = .table~new
    diagnostics = .array~new
    diagnosticsByColumn = .table~new

    do c over definition~columns
      columnDiagnostics = .array~new
      diagnosticsByColumn[c~name] = columnDiagnostics
      selection = document~select(c~selector, origin)
      sources[c~name] = selection

      if selection~kind = "NODESET" then do
        nodeCount = selection~nodes~items
        if nodeCount = 0 then do
          values[c~name] = .nil
          rawValues[c~name] = .nil
          states[c~name] = "ABSENT"
          iterate
        end

        if nodeCount = 1 then do
          sourceObject = selection~nodes[1]
          sources[c~name] = sourceObject
          scalar = sourceObject~scalarValue
          if sourceObject~hasMethod("LEXICALVALUE") then lexical = sourceObject~lexicalValue
          else lexical = .nil
          rawValues[c~name] = lexical

          if scalar == .nil then do
            if c~cardinality = "STRUCTURED" then do
              values[c~name] = sourceObject
              states[c~name] = "STRUCTURED"
            end
            else do
              values[c~name] = .nil
              states[c~name] = "STRUCTURED_VALUE"
              finding = .X12ValidationFinding~new("ERROR", "X12.PROJECTION.STRUCTURED", -
                "Column " || c~name || " selected a structured value; select a component or declare STRUCTURED", -
                sourceObject, "PROJECTION")
              diagnostics~append(finding)
              columnDiagnostics~append(finding)
              document~addFinding(finding)
            end
            iterate
          end

          if scalar = "" then do
            states[c~name] = "PRESENT_EMPTY"
            if c~type = "INTEGER" then values[c~name] = .nil
            else if c~type = "DECIMAL" then values[c~name] = .nil
            else values[c~name] = scalar
            iterate
          end

          if c~type = "INTEGER" then do
            if datatype(scalar, "W") then do
              values[c~name] = scalar
              states[c~name] = "PRESENT"
            end
            else do
              values[c~name] = .nil
              states[c~name] = "TYPE_ERROR"
              finding = .X12ValidationFinding~new("ERROR", "X12.PROJECTION.TYPE", -
                "Column " || c~name || " value is not INTEGER: " || scalar, sourceObject, "PROJECTION")
              diagnostics~append(finding)
              columnDiagnostics~append(finding)
              document~addFinding(finding)
            end
            iterate
          end

          if c~type = "DECIMAL" then do
            numericText = scalar
            if datatype(numericText, "N") then do
              values[c~name] = numericText
              states[c~name] = "PRESENT"
            end
            else do
              values[c~name] = .nil
              states[c~name] = "TYPE_ERROR"
              finding = .X12ValidationFinding~new("ERROR", "X12.PROJECTION.TYPE", -
                "Column " || c~name || " value is not DECIMAL: " || scalar, sourceObject, "PROJECTION")
              diagnostics~append(finding)
              columnDiagnostics~append(finding)
              document~addFinding(finding)
            end
            iterate
          end

          values[c~name] = scalar
          states[c~name] = "PRESENT"
          iterate
        end

        if c~cardinality = "MANY" | c~cardinality = "NODESET" then do
          values[c~name] = selection
          rawValues[c~name] = selection
          states[c~name] = "MULTI"
          iterate
        end

        values[c~name] = .nil
        rawValues[c~name] = selection
        states[c~name] = "CARDINALITY_ERROR"
        finding = .X12ValidationFinding~new("ERROR", "X12.PROJECTION.CARDINALITY", -
          "Column " || c~name || " selected " || nodeCount || " source objects; expected at most one", selection, "PROJECTION")
        diagnostics~append(finding)
        columnDiagnostics~append(finding)
        document~addFinding(finding)
        iterate
      end

      rawValue = selection~value
      rawValues[c~name] = rawValue
      sources[c~name] = selection
      if rawValue == .nil then do
        values[c~name] = .nil
        states[c~name] = "ABSENT"
      end
      else do
        values[c~name] = rawValue
        states[c~name] = "PRESENT"
      end
    end

    rows~append(.X12ProjectedRow~new(values, rawValues, sources, states, diagnostics, origin, document, definition, diagnosticsByColumn))
  end
  definition~rowCount = rows~items
  return rows

::method selectWhere
  use arg predicate
  allRows = self~readRows
  if predicate == .nil then return allRows
  found = .array~new
  do row over allRows
    if predicate~evaluate(row, self~definition) then found~append(row)
  end
  return found


::class X12RelationProvider public
::attribute resultClass get
::attribute tables get
::attribute documents get

::method init
  expose resultClass tables documents
  use arg resultClassArg
  resultClass = resultClassArg
  tables = .table~new
  documents = .array~new

::method addDocument
  expose documents
  use arg document
  if \document~isA(.X12DocumentContext) then raise syntax 93.900 additional("X12RelationProvider requires X12DocumentContext")
  documents~append(document)
  return document

::method defineRelation
  expose tables documents
  use arg tableName, document, rootSelector
  if \document~isA(.X12DocumentContext) then raise syntax 93.900 additional("X12 relation requires X12DocumentContext")
  definition = .X12RelationDefinition~new(tableName, document, rootSelector)
  relation = .X12RelationTable~new(definition)
  tables[tableName~string~translate] = relation
  known = .false
  do existing over documents
    if existing == document then known = .true
  end
  if \known then documents~append(document)
  return definition

::method table
  expose tables
  use arg tableName
  return tables[tableName~string~translate]

::method tableNames
  expose tables
  names = .array~new
  do key over tables~allIndexes
    names~append(tables[key]~definition~name)
  end
  names~sort
  return names

::method readCatalog
  raw = .table~new
  raw["name"] = "X12_RICH_SOURCE"
  raw["formatVersion"] = 4
  raw["tables"] = self~tableNames
  raw["projectionModel"] = "RICH_SOURCE_CORE_V1"
  return raw

::method selectWhere
  expose resultClass
  use arg tableName, predicate
  rs = resultClass~new("SELECT")
  relation = self~table(tableName)
  if relation == .nil then do
    rs~status = "NOTEXECUTED"
    rs~error = "NOTFOUND"
    rs~message = "X12 relation not found:" tableName
    return rs
  end
  allRows = relation~readRows
  rows = .array~new
  do row over allRows
    if predicate == .nil then rows~append(row)
    else if predicate~evaluate(row, relation~definition) then rows~append(row)
  end
  rs~rows = rows
  rs~affectedRows = rows~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "X12_RICH_PROJECTION"
  return rs

::method close
  expose documents
  ok = .true
  do document over documents
    if \document~closed then do
      if document~close then nop
      else ok = .false
    end
  end
  return ok


::requires "X12NativeSource.cls"
