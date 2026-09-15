/* SourceEvidenceRelationAdapter v0.6
 * Optional NoSQLServer projection over rich GitHub/code evidence.
 * SQL sees scalar columns; each row/fact keeps the originating PR object.
 */

::class SourceEvidenceRelationColumn public
::attribute name get
::attribute type get
::attribute nullable get
::attribute unique get
::attribute primaryKey get
::attribute textMode get
::attribute extractor get

::method init
  expose name type nullable unique primaryKey textMode extractor
  use arg nameArg, typeArg, extractorArg
  name = nameArg~string
  type = typeArg~string~translate
  extractor = extractorArg~string
  nullable = .true
  unique = .false
  primaryKey = .false
  textMode = "CLASSIC"

::method coerce
  expose type
  use arg value
  if value == .nil then return .nil
  text = value~string
  if type = "INTEGER" then do
    if \datatype(text, "W") then raise syntax 93.900 additional("Invalid INTEGER:" text)
    return text
  end
  return text

::method compare
  expose type
  use arg left, operator, right
  if left == .nil | right == .nil then return .false
  l = self~coerce(left); r = self~coerce(right); op = operator~string
  if type = "INTEGER" then do
    select
      when op = "=" then return l = r
      when op = "<>" | op = "!=" then return l \= r
      when op = "<" then return l < r
      when op = "<=" then return l <= r
      when op = ">" then return l > r
      when op = ">=" then return l >= r
      otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
    end
  end
  select
    when op = "=" then return l == r
    when op = "<>" | op = "!=" then return l \== r
    when op = "<" then return l < r
    when op = "<=" then return l <= r
    when op = ">" then return l > r
    when op = ">=" then return l >= r
    otherwise raise syntax 93.900 additional("Unsupported comparison operator:" op)
  end


::class SourceEvidenceRelationDefinition public
::attribute name get
::attribute columns get
::attribute columnNames get
::attribute sourceRepository get
::attribute generation get
::attribute rowCount
::attribute metadata get

::method init
  expose name columns columnNames sourceRepository generation rowCount metadata
  use arg nameArg, sourceRepositoryArg
  name = nameArg~string
  sourceRepository = sourceRepositoryArg
  columns = .array~new
  columnNames = .array~new
  generation = 0
  rowCount = .nil
  metadata = .table~new
  metadata["adapter"] = "SOURCE_EVIDENCE"
  metadata["sourceRepository"] = sourceRepository

::method columnMap
  expose columns columnNames
  use arg nameArg, extractorArg, typeArg = "VARCHAR"
  c = .SourceEvidenceRelationColumn~new(nameArg, typeArg, extractorArg)
  columns~append(c); columnNames~append(c~name)
  return self

::method canonicalColumn
  expose columnNames
  use arg wanted
  if wanted == .nil then return .nil
  do n over columnNames
    if n~caselessEquals(wanted~string) then return n
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


::class SourceEvidenceProjectedRow public
::attribute values get
::attribute origin get
::attribute projection get
::attribute cells get

::method init
  expose values origin projection cells
  use arg valuesArg, originArg, projectionArg
  values = valuesArg; origin = originArg; projection = projectionArg
  cells = .table~new
  do columnName over projection~columnNames
    c = projection~column(columnName)
    cells[columnName] = .RichProjectionValue~new(columnName, c~type, values[columnName], values[columnName], origin, "PRESENT")
  end

::method "[]"
  expose values
  use arg name
  return values[name]

::method at
  expose values
  use arg name
  return values[name]

::method cell
  expose cells projection
  use arg name
  canonical = projection~canonicalColumn(name)
  if canonical == .nil then return .nil
  return cells[canonical]

::method fact
  use arg name
  c = self~cell(name)
  if c == .nil then return .nil
  return c~fact(self)

::method sourceFor
  expose origin
  use arg name
  return origin

::method rawAt
  expose values
  use arg name
  return values[name]

::method copy
  expose values origin projection
  return .SourceEvidenceProjectedRow~new(values~copy, origin, projection)


::class SourceEvidenceRelationTable public
::attribute definition get
::attribute generation get

::method init
  expose definition generation
  use arg definitionArg
  definition = definitionArg; generation = 0

::method rowCount
  return self~readRows~items

::method readRows
  expose definition
  rows = .array~new
  prs = definition~sourceRepository~pullRequests
  indexes = prs~allIndexes
  indexes~sort
  do idx over indexes
    pr = prs[idx]
    values = .table~new
    do c over definition~columns
      select
        when c~extractor = "NUMBER" then v = pr~number
        when c~extractor = "TITLE" then v = pr~title
        when c~extractor = "STATE" then v = pr~state
        when c~extractor = "DRAFT" then do
          if pr~draft then v = "TRUE"; else v = "FALSE"
        end
        when c~extractor = "AUTHOR" then v = pr~author
        when c~extractor = "BASE_SHA" then v = pr~baseSha
        when c~extractor = "HEAD_SHA" then v = pr~headSha
        when c~extractor = "URL" then v = pr~url
        otherwise v = .nil
      end
      values[c~name] = v
    end
    rows~append(.SourceEvidenceProjectedRow~new(values, pr, definition))
  end
  return rows

::method readWhere
  use arg predicate
  allRows = self~readRows
  if predicate == .nil then return allRows
  found = .array~new
  do row over allRows
    if predicate~evaluate(row, self~definition) then found~append(row)
  end
  return found


::class SourceEvidenceRelationProvider public
::attribute resultClass get
::attribute tables get

::method init
  expose resultClass tables
  use arg resultClassArg
  resultClass = resultClassArg
  tables = .table~new

::method definePullRequestRelation
  expose tables
  use arg tableName, sourceRepository
  d = .SourceEvidenceRelationDefinition~new(tableName, sourceRepository)
  d~columnMap("number", "NUMBER", "INTEGER")
  d~columnMap("title", "TITLE")
  d~columnMap("state", "STATE")
  d~columnMap("draft", "DRAFT")
  d~columnMap("author", "AUTHOR")
  d~columnMap("base_sha", "BASE_SHA")
  d~columnMap("head_sha", "HEAD_SHA")
  d~columnMap("url", "URL")
  tables[tableName~string~translate] = .SourceEvidenceRelationTable~new(d)
  return d

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
  raw["name"] = "SOURCE_EVIDENCE"
  raw["formatVersion"] = 6
  raw["tables"] = self~tableNames
  raw["projectionModel"] = "RICH_SOURCE_CORE_V1"
  return raw

::method selectWhere
  expose resultClass
  use arg tableName, predicate
  rs = resultClass~new("SELECT")
  relation = self~table(tableName)
  if relation == .nil then do
    rs~status = "NOTEXECUTED"; rs~error = "NOTFOUND"; rs~message = "Source evidence relation not found:" tableName
    return rs
  end
  allRows = relation~readRows
  rows = .array~new
  do row over allRows
    if predicate == .nil then rows~append(row)
    else if predicate~evaluate(row, relation~definition) then rows~append(row)
  end
  rs~rows = rows; rs~affectedRows = rows~items; rs~rowsScanned = allRows~items; rs~accessPath = "SOURCE_EVIDENCE_RICH_PROJECTION"
  return rs

::method close
  return .true

::requires "GitHubEvidence.cls"
