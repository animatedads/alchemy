/*
 * XmlRelationAdapter v0.2
 *
 * NoSQLServer-compatible external provider over rich XML objects.
 * Rows are projections over retained source structure, never the native form.
 */

::class XmlRelationColumn public
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
  if value~isA(.XmlSelection) then raise syntax 93.900 additional("Refusing to coerce multi-valued XML selection for" name)
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
  if left~isA(.XmlSelection) then return .false
  if right~isA(.XmlSelection) then return .false
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


::class XmlRelationDefinition public
::attribute name get
::attribute rootXPath get
::attribute columns get
::attribute columnNames get
::attribute document get
::attribute generation get
::attribute rowCount
::attribute metadata get

::method init
  expose name rootXPath columns columnNames document generation rowCount metadata
  use arg nameArg, documentArg, rootXPathArg
  name = nameArg~string
  document = documentArg
  rootXPath = rootXPathArg~string
  columns = .array~new
  columnNames = .array~new
  generation = 0
  rowCount = .nil
  metadata = .table~new
  metadata["adapter"] = "XML"
  metadata["rootSelector"] = rootXPath
  metadata["sourceDocument"] = document

::method columnMap
  expose columns columnNames
  use arg columnName, selector, type = "VARCHAR", cardinality = "ZERO_OR_ONE"
  if self~canonicalColumn(columnName) \== .nil then raise syntax 93.900 additional("Duplicate XML relation column:" columnName)
  c = .XmlRelationColumn~new(columnName, selector, type, cardinality)
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


::class XmlProjectedRow public
::attribute values get
::attribute rawValues get
::attribute sources get
::attribute states get
::attribute cells get
::attribute diagnostics get
::attribute diagnosticsByColumn get
::attribute originNode get
::attribute document get
::attribute projection get
::attribute createdAt get

::method init
  expose values rawValues sources states cells diagnostics diagnosticsByColumn originNode document projection createdAt
  use arg valuesArg, rawValuesArg, sourcesArg, statesArg, diagnosticsArg, originNodeArg, documentArg, projectionArg, diagnosticsByColumnArg = .nil
  values = valuesArg
  rawValues = rawValuesArg
  sources = sourcesArg
  states = statesArg
  diagnostics = diagnosticsArg
  if diagnosticsByColumnArg == .nil then diagnosticsByColumn = .table~new
  else diagnosticsByColumn = diagnosticsByColumnArg
  originNode = originNodeArg
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
  expose projection
  use arg name
  cell = self~cell(name)
  if cell == .nil then return .nil
  return .XmlBusinessFact~new(cell~name, cell~value, cell~state, cell~source, self, cell~semanticType, cell~lexicalValue, cell~diagnostics)

::method copy
  expose values rawValues sources states diagnostics originNode document projection diagnosticsByColumn
  return .XmlProjectedRow~new(values~copy, rawValues~copy, sources~copy, states~copy, diagnostics~copy, originNode, document, projection, diagnosticsByColumn~copy)

::method provenance
  expose originNode document projection createdAt
  p = .table~new
  p["origin"] = originNode
  p["document"] = document
  p["projection"] = projection
  p["createdAt"] = createdAt
  return p

::method string
  expose projection originNode
  return "XML-PROJECTED-ROW(" || projection~name || "," || originNode~path || ")"


::class XmlRelationTable public
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
  roots = document~xpath(definition~rootXPath)
  if roots~kind \= "NODESET" then raise syntax 93.900 additional("XML relation root XPath must yield a node set:" definition~rootXPath)

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
      selection = document~xpath(c~selector, origin)
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
          sourceNode = selection~nodes[1]
          sources[c~name] = sourceNode
          value = sourceNode~text
          rawValues[c~name] = value

          if value = "" then do
            states[c~name] = "PRESENT_EMPTY"
            if c~type = "INTEGER" then values[c~name] = .nil
            else if c~type = "DECIMAL" then values[c~name] = .nil
            else values[c~name] = value
            iterate
          end

          if c~type = "INTEGER" then do
            if datatype(value, "W") then do
              values[c~name] = value
              states[c~name] = "PRESENT"
            end
            else do
              values[c~name] = .nil
              states[c~name] = "TYPE_ERROR"
              finding = .XmlValidationFinding~new("ERROR", "XML.PROJECTION.TYPE", -
                "Column " || c~name || " value is not INTEGER: " || value, sourceNode, "PROJECTION")
              diagnostics~append(finding)
              columnDiagnostics~append(finding)
              document~addFinding(finding)
            end
            iterate
          end

          if c~type = "DECIMAL" then do
            if datatype(value, "N") then do
              values[c~name] = value
              states[c~name] = "PRESENT"
            end
            else do
              values[c~name] = .nil
              states[c~name] = "TYPE_ERROR"
              finding = .XmlValidationFinding~new("ERROR", "XML.PROJECTION.TYPE", -
                "Column " || c~name || " value is not DECIMAL: " || value, sourceNode, "PROJECTION")
              diagnostics~append(finding)
              columnDiagnostics~append(finding)
              document~addFinding(finding)
            end
            iterate
          end

          values[c~name] = value
          states[c~name] = "PRESENT"
          iterate
        end

        if c~cardinality = "MANY" then do
          values[c~name] = selection
          rawValues[c~name] = selection
          states[c~name] = "MULTI"
          iterate
        end
        if c~cardinality = "NODESET" then do
          values[c~name] = selection
          rawValues[c~name] = selection
          states[c~name] = "MULTI"
          iterate
        end

        values[c~name] = .nil
        rawValues[c~name] = selection
        states[c~name] = "CARDINALITY_ERROR"
        finding = .XmlValidationFinding~new("ERROR", "XML.PROJECTION.CARDINALITY", -
          "Column " || c~name || " selected " || nodeCount || " nodes; expected at most one", selection, "PROJECTION")
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

    rows~append(.XmlProjectedRow~new(values, rawValues, sources, states, diagnostics, origin, document, definition, diagnosticsByColumn))
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


::class XmlRelationProvider public
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
  if \document~isA(.XmlDocumentContext) then raise syntax 93.900 additional("XmlRelationProvider requires XmlDocumentContext")
  documents~append(document)
  return document

::method defineRelation
  expose tables documents
  use arg tableName, document, rootXPath
  if \document~isA(.XmlDocumentContext) then raise syntax 93.900 additional("XML relation requires XmlDocumentContext")
  definition = .XmlRelationDefinition~new(tableName, document, rootXPath)
  relation = .XmlRelationTable~new(definition)
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
  raw["name"] = "XML_RICH_SOURCE"
  raw["formatVersion"] = 2
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
    rs~message = "XML relation not found:" tableName
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
  rs~accessPath = "XML_XPATH_PROJECTION"
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


::requires "XmlNativeSource.cls"
