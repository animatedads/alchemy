/* NoSQLServer columnar virtual-relation prototype.
 * Logic is backend-independent; the port owns durable staging/publication.
 * Callers must supply a real transactional storage port for deployment.
 */

::requires "NoSQLServer.cls"

::class NoSQLColumnarCodec public
::method token class
  use strict arg value
  if value == .nil then return "N"
  return "H" || c2x(value~string)

::method encode class
  use strict arg values
  n = values~items
  plain = "P|" || n
  run = "R|" || n
  previous = ""
  count = 0
  do value over values
    token = self~token(value)
    plain ||= "|" || token
    if count = 0 then do
      previous = token
      count = 1
    end
    else if token == previous then count += 1
    else do
      run ||= "|" || count || ":" || previous
      previous = token
      count = 1
    end
  end
  if count > 0 then run ||= "|" || count || ":" || previous
  if run~length < plain~length then return run
  return plain

::method decode class
  use strict arg encoded
  items = encoded~makeArray("|")
  if items~items < 2 then raise syntax 93.900 additional("Invalid column segment")
  kind = items[1]
  n = items[2]
  if \datatype(n, "W") | n < 0 then raise syntax 93.900 additional("Invalid column segment count")
  values = .array~new
  do i = 3 to items~items
    token = items[i]
    repeats = 1
    if kind = "R" then do
      split = token~pos(":")
      if split < 2 then raise syntax 93.900 additional("Invalid column run")
      repeats = token~left(split - 1)
      if \datatype(repeats, "W") | repeats < 1 then raise syntax 93.900 additional("Invalid column run length")
      token = token~substr(split + 1)
    end
    else if kind \= "P" then raise syntax 93.900 additional("Unknown column segment encoding")
    if token = "N" then decoded = .nil
    else do
      if token~left(1) \= "H" then raise syntax 93.900 additional("Invalid column value encoding")
      hex = token~substr(2)
      if hex~length // 2 \= 0 then raise syntax 93.900 additional("Odd column hex length")
      if hex~length > 0 & \datatype(hex,"X") then raise syntax 93.900 additional("Invalid column hex value")
      decoded = x2c(hex)
    end
    do j = 1 to repeats
      values~append(decoded)
    end
  end
  if values~items \= n then raise syntax 93.900 additional("Column segment cardinality mismatch")
  return values

/* The storage port contract: stage -> write -> publish; publication must
 * atomically replace a single active generation pointer, or fail. Readers
 * must see only published generations. The port may use any Alchemy backend.
 */
::class NoSQLColumnarMemoryPort public
::attribute failWriteAt
::attribute writeCount
::attribute readCount
::method init
  expose segments manifests
  segments = .table~new
  manifests = .table~new
  self~writeCount = 0
  self~readCount = 0
  self~failWriteAt = 0
::method manifest
  expose manifests
  use strict arg name
  return manifests[name~translate]
::method begin
  use strict arg name, version
  return .true
::method write
  expose segments
  use strict arg name, version, col, chunk, value
  self~writeCount += 1
  if self~failWriteAt > 0 & self~writeCount = self~failWriteAt then ,
    raise syntax 93.900 additional("Simulated physical segment failure")
  key = name~translate || "|" || version || "|" || col~translate || "|" || chunk
  segments[key] = value
  return .true
::method read
  expose segments
  use strict arg name, version, col, chunk
  self~readCount += 1
  key = name~translate || "|" || version || "|" || col~translate || "|" || chunk
  return segments[key]
::method publish
  expose manifests
  use strict arg name, generation, rowCount, blockSize, definition
  current = manifests[name~translate]
  if current == .nil then do
    if generation \= 1 then ,
      raise syntax 93.900 additional("Concurrent initial column generation")
  end
  else if generation \= current["generation"] + 1 then ,
    raise syntax 93.900 additional("Concurrent column generation publication")
  manifest = .directory~new
  manifest["generation"] = generation
  manifest["rowCount"] = rowCount
  manifest["blockSize"] = blockSize
  manifest["definition"] = definition
  manifests[name~translate] = manifest
  return .true
::method abort
  use strict arg name, generation
  return .true

::class NoSQLColumnarTable public
::attribute definition
::attribute port
::attribute blockSize
::attribute name
::attribute generation
::attribute lastColumnsRead
::attribute lastSegmentsRead

::method init
  use strict arg name, definition, port, blockSize = 1024
  if blockSize < 1 | \datatype(blockSize,"W") then ,
    raise syntax 93.900 additional("Column block size must be positive integer")
  self~name = name
  self~definition = definition
  self~port = port
  self~blockSize = blockSize
  self~lastColumnsRead = .array~new
  self~lastSegmentsRead = 0
  self~generation = 0
  manifest = port~manifest(name)
  if manifest \== .nil then do
    self~generation = manifest["generation"]
    self~blockSize = manifest["blockSize"]
  end

::method rowCount
  manifest = self~port~manifest(self~name)
  if manifest == .nil then return 0
  return manifest["rowCount"]

/* One-time row->column shadow conversion. The active generation switches
 * only after all segments have been written; the source remains intact.
 */
::method publishRows
  use strict arg rows, source = .nil, sourceGeneration = .nil
  manifest = self~port~manifest(self~name)
  generation = 1
  if manifest \== .nil then generation = manifest["generation"] + 1
  n = rows~items
  ignore = self~port~begin(self~name, generation)
  signal on syntax name conversionFailed
  do col over self~definition~columns
    if col~type = "GEOMETRY" then ,
      raise syntax 93.900 additional("GEOMETRY column requires a registered binary column codec")
    columnValues = .array~new
    chunk = 1
    do i = 1 to n
      row = rows[i]
      columnValues~append(row[col~name])
      if columnValues~items >= self~blockSize | i = n then do
        payload = .NoSQLColumnarCodec~encode(columnValues)
        ignore = self~port~write(self~name,generation,col~name,chunk,payload)
        chunk += 1
        columnValues = .array~new
      end
    end
  end
  -- Avoid publishing a shadow built from a concurrently changed row source.
  -- The calling provider must guarantee source generation validity.
  if source \== .nil then do
    if source~generation \= sourceGeneration then ,
      raise syntax 93.900 additional("Row source changed during columnar conversion")
  end
  ignore = self~port~publish(self~name,generation,n,self~blockSize,self~definition)
  self~generation = generation
  signal off syntax
  return generation
conversionFailed:
  signal off syntax
  ignore = self~port~abort(self~name,generation)
  raise propagate

/* Access ONLY named physical columns, with positions stable in each snapshot. */
::method readColumns
  use strict arg wanted, manifest = .nil
  if manifest == .nil then manifest = self~port~manifest(self~name)
  if manifest == .nil then raise syntax 93.900 additional("No published columnar generation")
  n = manifest["rowCount"]
  block = manifest["blockSize"]
  version = manifest["generation"]
  out = .table~new
  seen = .table~new
  self~lastColumnsRead = .array~new
  self~lastSegmentsRead = 0
  do requested over wanted
    col = self~definition~column(requested)
    if col == .nil then raise syntax 93.900 additional("Unknown column:" requested)
    name = col~name
    if seen~hasIndex(name~translate) then iterate
    seen[name~translate] = .true
    self~lastColumnsRead~append(name)
    values = .array~new
    count = 0
    chunk = 1
    do while count < n
      payload = self~port~read(self~name,version,name,chunk)
      self~lastSegmentsRead += 1
      if payload == .nil then raise syntax 93.900 additional("Missing column segment:" name || "/" || chunk)
      decoded = .NoSQLColumnarCodec~decode(payload)
      expected = min(block, n - count)
      if decoded~items \= expected then raise syntax 93.900 additional("Column segment row count mismatch")
      do value over decoded
        values~append(value)
      end
      count += decoded~items
      chunk += 1
    end
    out[name] = values
  end
  return out

/* Fetch projected values only from physical chunks containing accepted
 * row ordinals. The output arrays retain the order (and duplicates) of
 * requested positions, without decoding unrelated segment blocks.
 */
::method readPositions
  use strict arg wanted, positions, manifest = .nil
  if manifest == .nil then manifest = self~port~manifest(self~name)
  if manifest == .nil then raise syntax 93.900 additional("No published columnar generation")
  n = manifest["rowCount"]
  block = manifest["blockSize"]
  version = manifest["generation"]
  out = .table~new
  seen = .table~new
  self~lastColumnsRead = .array~new
  self~lastSegmentsRead = 0
  do requested over wanted
    col = self~definition~column(requested)
    if col == .nil then raise syntax 93.900 additional("Unknown column:" requested)
    name = col~name
    if seen~hasIndex(name~translate) then iterate
    seen[name~translate] = .true
    self~lastColumnsRead~append(name)
    values = .array~new
    decodedChunks = .table~new
    do ordinal over positions
      if \datatype(ordinal, "W") | ordinal < 1 | ordinal > n then ,
        raise syntax 93.900 additional("Column row ordinal outside published bounds")
      chunk = (ordinal - 1) % block + 1
      within = (ordinal - 1) // block + 1
      decoded = decodedChunks[chunk]
      if decoded == .nil then do
        payload = self~port~read(self~name,version,name,chunk)
        self~lastSegmentsRead += 1
        if payload == .nil then ,
          raise syntax 93.900 additional("Missing projected column segment:" name || "/" || chunk)
        decoded = .NoSQLColumnarCodec~decode(payload)
        expected = min(block, n - (chunk - 1) * block)
        if decoded~items \= expected then ,
          raise syntax 93.900 additional("Projected column segment cardinality mismatch")
        decodedChunks[chunk] = decoded
      end
      values~append(decoded[within])
    end
    out[name] = values
  end
  return out

::method readRows
  return self~project(self~definition~columnNames)

::method project
  use strict arg columns
  manifest = self~port~manifest(self~name)
  if manifest == .nil then raise syntax 93.900 additional("No published columnar generation")
  arrays = self~readColumns(columns,manifest)
  rows = .array~new
  do i = 1 to manifest["rowCount"]
    values = .table~new
    raw = .table~new
    types = .table~new
    do colName over columns
      c = self~definition~column(colName)
      v = arrays[c~name][i]
      values[c~name] = v
      raw[c~name] = v
      types[c~name] = c~type
    end
    rows~append(.DatabaseRow~new(values,raw,types))
  end
  return rows

/* Predicate evaluation touches only filter columns first. The second pass
 * collects projection columns for matching row ordinals. No complete-row
 * reconstruction or reading of unrelated columns is required.
 */
::method selectProject
  use strict arg projectionColumns, predicate = .nil, filterColumns = .nil, orderColumns = .nil
  if filterColumns == .nil then filterColumns = .array~new
  if orderColumns == .nil then orderColumns = .array~new
  manifest = self~port~manifest(self~name)
  if manifest == .nil then raise syntax 93.900 additional("No published columnar generation")
  scanCols = .array~new
  do c over filterColumns
    scanCols~append(c)
  end
  filter = .table~new
  if scanCols~items > 0 then filter = self~readColumns(scanCols,manifest)
  accepted = .array~new
  do i = 1 to manifest["rowCount"]
    include = .true
    if predicate \== .nil then do
      values = .table~new
      do c over filterColumns
        actual = self~definition~column(c)~name
        values[actual] = filter[actual][i]
      end
      predicateRow = .DatabaseRow~new(values)
      include = predicate~evaluate(predicateRow,self~definition)
    end
    if include then accepted~append(i)
  end
  wanted = .array~new
  do c over projectionColumns
    wanted~append(c)
  end
  do c over orderColumns
    wanted~append(c)
  end
  data = self~readPositions(wanted,accepted,manifest)
  rows = .array~new
  selectedIndex = 0
  do i over accepted
    selectedIndex += 1
    values = .table~new
    raw = .table~new
    types = .table~new
    do c over wanted
      col = self~definition~column(c)
      values[col~name] = data[col~name][selectedIndex]
      raw[col~name] = data[col~name][selectedIndex]
      types[col~name] = col~type
    end
    rows~append(.DatabaseRow~new(values,raw,types))
  end
  return rows

/* Planner can compare row access versus column scan without backend guessing.
 * Byte statistics and cache/index costs are provided by storage adapters.
 */
::method estimateReadFraction
  use strict arg projectionColumns
  if self~definition~columns~items = 0 then return 1
  return projectionColumns~items / self~definition~columns~items

/* A virtual relation engine compatible with the existing federation port.
 * SELECT fallback is full row materialisation; selectColumnar is the fast path.
 */
::class NoSQLColumnarEngine public
::attribute tables
::attribute port
::attribute queryLog
::attribute rowEngine
::attribute sourceGenerations
::attribute layoutModes
::attribute lastPlan
::method init
  use strict arg port, rowEngine = .nil
  self~rowEngine = rowEngine
  self~port = port
  self~tables = .table~new
  self~sourceGenerations = .table~new
  self~layoutModes = .table~new
  self~lastPlan = .directory~new
  if rowEngine \== .nil then do
    if rowEngine~hasMethod("queryPatternLog") then self~queryLog = rowEngine~queryPatternLog
    else self~queryLog = .NullQueryPatternLog~new
  end
  else self~queryLog = .NullQueryPatternLog~new
::method register
  use strict arg name, definition, sourceRows, blockSize = 1024
  t = .NoSQLColumnarTable~new(name,definition,self~port,blockSize)
  version = t~publishRows(sourceRows)
  self~tables[name~translate] = t
  return version
::method promote
  use strict arg name, blockSize = 1024
  if self~rowEngine == .nil then ,
    raise syntax 93.900 additional("Promote requires an authoritative row engine")
  source = self~rowEngine~table(name)
  if source == .nil then ,
    raise syntax 93.900 additional("Source relation not found:" name)
  if \source~hasMethod("generation") then ,
    raise syntax 93.900 additional("Source revision proof required for conversion")
  before = source~generation
  rows = source~readRows
  if source~generation \= before then ,
    raise syntax 93.900 additional("Source changed during row snapshot")
  t = .NoSQLColumnarTable~new(name,source~definition,self~port,blockSize)
  version = t~publishRows(rows,source,before)
  self~tables[name~translate] = t
  self~sourceGenerations[name~translate] = before
  return version
::method setLayout
  use strict arg name, requested
  mode = requested~string~translate
  if mode \= "ROW" & mode \= "COLUMN" & mode \= "AUTO" then ,
    raise syntax 93.900 additional("Layout must be ROW, COLUMN or AUTO")
  if mode = "ROW" & self~rowEngine == .nil then ,
    raise syntax 93.900 additional("ROW layout requires a row engine")
  if mode = "COLUMN" & self~tables[name~translate] == .nil then ,
    raise syntax 93.900 additional("COLUMN layout requires a published projection")
  self~layoutModes[name~translate] = mode
  return mode
::method layout
  use strict arg name
  mode = self~layoutModes[name~translate]
  if mode == .nil then return "AUTO"
  return mode
::method table
  use strict arg name
  if self~layout(name) = "ROW" then return self~rowEngine~table(name)
  t = self~tables[name~translate]
  if t \== .nil then do
    if self~rowEngine \== .nil then do
      source = self~rowEngine~table(name)
      tracked = self~sourceGenerations[name~translate]
      if tracked \== .nil then do
        if source == .nil then do
          self~tables~remove(name~translate)
          return .nil
        end
        if source~generation \= tracked then do
          self~tables~remove(name~translate)
          return source
        end
      end
    end
    return t
  end
  if self~rowEngine \== .nil then return self~rowEngine~table(name)
  return .nil
::method tableNames
  return self~tables~allIndexes
::method tableRowCount
  use strict arg name
  t = self~table(name)
  if t == .nil then return .nil
  return t~rowCount
::method selectAll
  use strict arg name
  return self~selectWhere(name,.nil)
::method selectWhere
  use strict arg name, predicate
  if self~rowEngine \== .nil then return self~rowEngine~selectWhere(name,predicate)
  r = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  t = self~table(name)
  if t == .nil then return r~fail(.Error~NOTFOUND, "No columnar relation:" name)
  all = t~readRows
  found = .array~new
  do row over all
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row,t~definition) then found~append(row)
  end
  r~rows = found
  r~rowsScanned = all~items
  r~affectedRows = found~items
  r~accessPath = "COLUMNAR_ROW_MATERIALIZE"
  return r
::method version
  if self~rowEngine \== .nil then return self~rowEngine~version
  return .NoSQLServerVersionInfo~new(1)
::method execute
  use strict arg statement
  return .NoSQLServerSQL~new(self)~execute(statement)
::method query
  use strict arg statement
  return self~execute(statement)
::method transaction
  if self~rowEngine == .nil then return .ObjectUnsupportedTransaction~new
  return self~rowEngine~transaction
::method selectJoin
  if self~rowEngine == .nil then return self~immutableError
  forward to (self~rowEngine)
::method selectJoinWithSidePredicate
  if self~rowEngine == .nil then return self~immutableError
  forward to (self~rowEngine)
::method selectCrossJoin
  if self~rowEngine == .nil then return self~immutableError
  forward to (self~rowEngine)
::method selectCrossJoinWithSidePredicate
  if self~rowEngine == .nil then return self~immutableError
  forward to (self~rowEngine)
::method currentIndexCandidateCount
  if self~rowEngine == .nil then return .nil
  forward to (self~rowEngine)
::method joinMapSnapshot
  if self~rowEngine == .nil then return .nil
  forward to (self~rowEngine)
::method immutableError
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  return rs~fail(.Error~SQLUNSUPPORTED, 'Columnar snapshot is read-only without source engine')
::method invalidate
  use strict arg name
  self~tables~remove(name~translate)
  self~sourceGenerations~remove(name~translate)
  self~layoutModes~remove(name~translate)
  return .true
::method createTable
  if self~rowEngine == .nil then return self~immutableError
  forward to (self~rowEngine)
::method dropTable
  use arg name
  if self~rowEngine == .nil then return self~immutableError
  rs = self~rowEngine~dropTable(name)
  if rs~status = .Error~SUCCESS then self~invalidate(name)
  return rs
::method insert
  use arg name, values
  if self~rowEngine == .nil then return self~immutableError
  rs = self~rowEngine~insert(name,values)
  if rs~status = .Error~SUCCESS then self~invalidate(name)
  return rs
::method insertMany
  use arg name, rows
  if self~rowEngine == .nil then return self~immutableError
  rs = self~rowEngine~insertMany(name,rows)
  if rs~status = .Error~SUCCESS then self~invalidate(name)
  return rs
::method updateWhere
  use arg name, predicate, assignments
  if self~rowEngine == .nil then return self~immutableError
  rs = self~rowEngine~updateWhere(name,predicate,assignments)
  if rs~status = .Error~SUCCESS then self~invalidate(name)
  return rs
::method deleteWhere
  use arg name, predicate
  if self~rowEngine == .nil then return self~immutableError
  rs = self~rowEngine~deleteWhere(name,predicate)
  if rs~status = .Error~SUCCESS then self~invalidate(name)
  return rs
::method tableMetadata
  use strict arg name
  t = self~table(name)
  if t == .nil then return .nil
  return .DatabaseTableMetadata~new(t~definition)
::method isSimpleColumn
  use strict arg name
  if name == '' then return .false
  upper = name~translate
  if upper~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', 'N') \= 0 then return .false
  if upper~left(1)~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'N') \= 0 then return .false
  return .true
::method predicateColumns
  use strict arg predicate
  out = .array~new
  if predicate == .nil then return out
  if predicate~isA(.SQLComparisonPredicate) then do
    out~append(predicate~column)
    return out
  end
  if predicate~isA(.SQLNullPredicate) then do
    out~append(predicate~column)
    return out
  end
  if predicate~isA(.SQLLogicalPredicate) then do
    left = self~predicateColumns(predicate~left)
    right = self~predicateColumns(predicate~right)
    if left == .nil | right == .nil then return .nil
    do item over left
      out~append(item)
    end
    do item over right
      out~append(item)
    end
    return out
  end
  if predicate~isA(.SQLNotPredicate) then return self~predicateColumns(predicate~child)
  return .nil
::method selectColumnar
  use strict arg name, predicate, projection, orderBy = ''
  t = self~table(name)
  if t == .nil then return .nil
  if \t~isA(.NoSQLColumnarTable) then return .nil
  if projection == '*' then return .nil
  wanted = .array~new
  do spec over projection~makeArray(',')
    spec = spec~strip
    if \self~isSimpleColumn(spec) then return .nil
    if t~definition~column(spec) == .nil then return .nil
    wanted~append(spec)
  end
  predicateNames = self~predicateColumns(predicate)
  if predicateNames == .nil then return .nil
  do p over predicateNames
    if t~definition~column(p) == .nil then return .nil
  end
  ordering = .array~new
  if orderBy \= '' then do
    do spec over orderBy~makeArray(',')
      w = spec~strip~space~makeArray(' ')
      if w~items < 1 | w~items > 2 then return .nil
      if \self~isSimpleColumn(w[1]) then return .nil
      if t~definition~column(w[1]) == .nil then return .nil
      if w~items = 2 then do
        if w[2]~translate \= 'ASC' & w[2]~translate \= 'DESC' then return .nil
      end
      ordering~append(w[1])
    end
  end
  -- AUTO is conservative: avoid unnecessary column scans for wide row
  -- projections and indexed primary-key equality. COLUMN explicitly forces
  -- column access when the requested SQL shape is otherwise supported.
  mode = self~layout(name)
  if self~rowEngine \== .nil & mode = "AUTO" then do
    if predicate \== .nil then do
      if predicate~isA(.SQLComparisonPredicate) then do
        if predicate~operator = '=' then do
          pk = t~definition~primaryKey
          if pk~items = 1 then do
            if pk[1]~caselessEquals(predicate~column) then return .nil
          end
        end
      end
    end
    distinct = .table~new
    do col over wanted
      distinct[t~definition~column(col)~name~translate] = .true
    end
    do col over predicateNames
      distinct[t~definition~column(col)~name~translate] = .true
    end
    do col over ordering
      distinct[t~definition~column(col)~name~translate] = .true
    end
    -- A conservative default; provider statistics can replace it later.
    readFraction = distinct~items / t~definition~columns~items
    if readFraction >= 0.75 then do
      self~lastPlan["reason"] = "ROW_WIDE_PROJECTION"
      self~lastPlan["readFraction"] = readFraction
      return .nil
    end
  end
  self~lastPlan["reason"] = "COLUMN_PROJECTED_SEGMENTS"
  selected = t~selectProject(wanted,predicate,predicateNames,ordering)
  rs = .DatabaseResult~new(.DatabaseOperationType~SELECT)
  rs~rows = selected
  rs~affectedRows = selected~items
  rs~rowsScanned = t~rowCount
  rs~accessPath = 'COLUMNAR_PROJECT_LATE'
  return rs
::method readCatalog
  if self~rowEngine \== .nil then do
    if self~rowEngine~hasMethod("readCatalog") then do
      catalog = self~rowEngine~readCatalog~copy
      names = catalog["tables"]
      if names == .nil then names = .array~new
      else names = names~copy
    end
    else do
      catalog = .table~new
      names = .array~new
    end
  end
  else do
    catalog = .table~new
    names = .array~new
  end
  do name over self~tableNames
    found = .false
    do prior over names
      if name~caselessEquals(prior) then found = .true
    end
    if \found then names~append(name)
  end
  catalog["tables"] = names
  return catalog

/* SQL-backed physical port. It stores independent immutable tables per column
 * and generation; compatible backends must provide ordinary atomic SQL DDL,
 * INSERT, UPDATE, SELECT and table(name). This is not a claim that every
 * backend implements that capability. Unsupported providers fail closed.
 */
::class NoSQLColumnarSQLPort public
::attribute backend
::method init
  use strict arg backend
  self~backend = backend

::method identifier
  use strict arg value
  value = value~string~translate
  if value~length = 0 | value~length > 40 then ,
    raise syntax 93.900 additional("Columnar physical identifier length outside 1..40")
  if value~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', 'N') \= 0 then ,
    raise syntax 93.900 additional("Unsupported physical identifier:" value)
  if \datatype(value~left(1), 'A') | datatype(value~left(1), 'N') then ,
    raise syntax 93.900 additional("Physical identifier must begin with a letter")
  return value

::method metaName
  use strict arg name
  return 'CSM_' || self~identifier(name)

::method segmentName
  use strict arg name, generation, column
  tableName = self~identifier(name)
  columnName = self~identifier(column)
  if \datatype(generation, 'W') | generation < 1 then ,
    raise syntax 93.900 additional("Columnar generation is not positive integer")
  return 'CSC_' || tableName~length || '_' || tableName || '_' || ,
         generation || '_' || columnName~length || '_' || columnName

::method ensure
  use strict arg name, statement
  if self~backend~table(name) \== .nil then return .true
  r = self~backend~execute(statement)
  if r~status \= .Error~SUCCESS then do
    if self~backend~table(name) == .nil then ,
      raise syntax 93.900 additional("Columnar DDL failed:" r~message)
  end
  return .true

::method begin
  use strict arg name, version
  meta = self~metaName(name)
  statement = 'CREATE TABLE ' || meta || ,
    ' (id INTEGER PRIMARY KEY, generation INTEGER NOT NULL,' || ,
    ' row_count INTEGER NOT NULL, block_size INTEGER NOT NULL)'
  return self~ensure(meta,statement)

::method write
  use strict arg name, version, column, chunk, payload
  physical = self~segmentName(name,version,column)
  statement = 'CREATE TABLE ' || physical || ,
    ' (chunk_id INTEGER PRIMARY KEY, payload TEXT NOT NULL)'
  ignore = self~ensure(physical,statement)
  -- The column codec emits only A-Z/0-9/:/|; still escape for portability.
  safe = payload~changestr("'", "''")
  rs = self~backend~execute('INSERT INTO ' || physical || ,
    ' (chunk_id,payload) VALUES (' || chunk || ",'" || safe || "')")
  if rs~status \= .Error~SUCCESS | rs~affectedRows \= 1 then ,
    raise syntax 93.900 additional("Columnar segment write failed:" physical)
  return .true

::method read
  use strict arg name, version, column, chunk
  physical = self~segmentName(name,version,column)
  if self~backend~table(physical) == .nil then return .nil
  rs = self~backend~execute('SELECT payload FROM ' || physical || ,
    ' WHERE chunk_id = ' || chunk)
  if rs~status \= .Error~SUCCESS then ,
    raise syntax 93.900 additional("Columnar segment read failed:" physical)
  if rs~rows~items \= 1 then return .nil
  return rs~rows[1]['payload']

::method manifest
  use strict arg name
  meta = self~metaName(name)
  if self~backend~table(meta) == .nil then return .nil
  rs = self~backend~execute('SELECT generation,row_count,block_size FROM ' || meta || ,
    ' WHERE id = 1')
  if rs~status \= .Error~SUCCESS then ,
    raise syntax 93.900 additional("Columnar manifest read failed:" meta)
  if rs~rows~items = 0 then return .nil
  if rs~rows~items \= 1 then ,
    raise syntax 93.900 additional("Nonunique columnar manifest:" meta)
  r = rs~rows[1]
  out = .directory~new
  out['generation'] = r['generation']
  out['rowCount'] = r['row_count']
  out['blockSize'] = r['block_size']
  return out

::method publish
  use strict arg name, generation, rowCount, blockSize, definition
  meta = self~metaName(name)
  current = self~manifest(name)
  if current == .nil then do
    if generation \= 1 then ,
      raise syntax 93.900 additional("Columnar first generation must be 1")
    statement = 'INSERT INTO ' || meta || ,
      ' (id,generation,row_count,block_size) VALUES (1,' || ,
      generation || ',' || rowCount || ',' || blockSize || ')'
  end
  else do
    if current['generation'] + 1 \= generation then ,
      raise syntax 93.900 additional("Concurrent columnar publication conflict")
    statement = 'UPDATE ' || meta || ' SET generation = ' || generation || ,
      ', row_count = ' || rowCount || ', block_size = ' || blockSize || ,
      ' WHERE id = 1 AND generation = ' || current['generation']
  end
  -- One atomic manifest statement publishes an already-complete snapshot.
  rs = self~backend~execute(statement)
  if rs~status \= .Error~SUCCESS | rs~affectedRows \= 1 then ,
    raise syntax 93.900 additional("Columnar generation publish failed")
  return .true

::method abort
  use strict arg name, generation
  -- Orphan segments cannot become visible without manifest publication.
  -- Generation cleanup requires a separate reader-aware GC protocol.
  return .true
