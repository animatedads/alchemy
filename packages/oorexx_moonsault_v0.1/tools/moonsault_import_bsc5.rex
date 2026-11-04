/* Moonsault BSC5/J2000 CSV -> Alchemy NoSQLServer native SQLite import.
   Run: rexx moonsault_import_bsc5.rex <csv-path> <database.sqlite>
   Pre-validation is entirely native ooRexx; DB operations use NoSQLServer.
   A new table is created only when the target table does not exist.
*/
parse arg csvPath dbPath mode
if csvPath = '' | dbPath = '' then do
  say 'USAGE: rexx moonsault_import_bsc5.rex <yale_bsc5_j2000.csv> <database.sqlite>'
  exit 2
end
if stream(csvPath, 'C', 'QUERY EXISTS') = '' then do
  say 'FAIL: input CSV not found:' csvPath
  exit 2
end
header = 'hr,ra_deg_j2000,dec_deg_j2000,vmag,color_temperature_k,common_name,bayer,flamsteed,constellation'
call stream csvPath, 'C', 'OPEN READ'
actual = linein(csvPath)
if actual \== header then do
  say 'FAIL: unexpected CSV schema'
  call stream csvPath, 'C', 'CLOSE'
  exit 3
end
rows = .array~new
seen = .table~new
count = 0
hasFirst = 0
hasLast = 0
do while lines(csvPath) > 0
  line = linein(csvPath)
  if line = '' then iterate
  cells = parseCsvLine(line)
  if cells~items \= 9 then do
    say 'FAIL: CSV column count at line' count + 2
    exit 3
  end
  hr = cells[1]
  ra = cells[2]
  dec = cells[3]
  vm = cells[4]
  k = cells[5]
  if \datatype(hr, 'W') | \datatype(ra, 'N') | \datatype(dec, 'N') | \datatype(vm, 'N') then do
    say 'FAIL: nonnumeric core fields at HR' hr
    exit 3
  end
  if hr < 1 | hr > 9110 | ra < 0 | ra >= 360 | dec < -90 | dec > 90 | vm < -5 | vm > 20 then do
    say 'FAIL: out-of-range values at HR' hr
    exit 3
  end
  if k \= '' then if \datatype(k, 'W') | k < 0 then do
    say 'FAIL: invalid temperature at HR' hr
    exit 3
  end
  if seen~hasIndex(hr) then do
    say 'FAIL: duplicate HR' hr
    exit 3
  end
  seen[hr] = 1
  if hr = 1 then hasFirst = 1
  if hr = 9110 then hasLast = 1
  rows~append(cells)
  count = count + 1
end
call stream csvPath, 'C', 'CLOSE'
if count \= 9096 | \hasFirst | \hasLast then do
  say 'FAIL: incomplete source; rows=' count 'HR1=' hasFirst 'HR9110=' hasLast
  exit 3
end
say 'MOONSAULT BSC5 SOURCE: validated 9096 distinct HR rows'
if translate(mode) = 'VALIDATE_ONLY' then exit 0

-- No external SQL engine is allowed: the Alchemy NoSQLServer engine owns the SQL.
if stream(dbPath, 'C', 'QUERY EXISTS') = '' then
  engine = .SQLiteWritableDatabaseEngine~create(dbPath)
else
  engine = .SQLiteWritableDatabaseEngine~new(dbPath)
if engine~table('moonsault_bsc5') \== .nil then do
  say 'FAIL: moonsault_bsc5 already exists; refusing mutation'
  exit 4
end
sql = .NoSQLServerSQL~new(engine)
stmt = 'CREATE TABLE moonsault_bsc5 (' ||,
       'hr INTEGER PRIMARY KEY, ra_deg_j2000 DECIMAL, dec_deg_j2000 DECIMAL,' ||,
       'vmag DECIMAL, color_temperature_k INTEGER, common_name TEXT,' ||,
       'bayer TEXT, flamsteed TEXT, constellation TEXT)'
call requireOk sql~execute(stmt), 'CREATE TABLE'

-- Batch inserts: each NoSQLServer SQL statement is transactionally atomic.
batch = ''
inBatch = 0
inserted = 0
do i = 1 to rows~items
  c = rows[i]
  temp = 'NULL'
  if c[5] \= '' then temp = c[5]
  entry = '(' || c[1] || ',' || c[2] || ',' || c[3] || ',' || c[4] || ',' || temp || ',' ||,
    q(c[6]) || ',' || q(c[7]) || ',' || q(c[8]) || ',' || q(c[9]) || ')'
  if inBatch = 0 then batch = entry
  else batch = batch || ',' || entry
  inBatch = inBatch + 1
  if inBatch = 50 | i = rows~items then do
    call requireOk sql~execute('INSERT INTO moonsault_bsc5 (' ||,
      'hr,ra_deg_j2000,dec_deg_j2000,vmag,color_temperature_k,common_name,bayer,flamsteed,constellation)' ||,
      ' VALUES ' || batch), 'INSERT batch ending row' i
    inserted = inserted + inBatch
    batch = ''
    inBatch = 0
  end
end
check = sql~execute('SELECT hr FROM moonsault_bsc5')
call requireOk check, 'read-back'
if check~rows~items \= 9096 then do
  say 'FAIL: readback row count:' check~rows~items
  exit 6
end
say 'MOONSAULT BSC5 IMPORT: PASS' inserted 'records; read-back=9096'
exit 0

q: procedure
  use arg value
  if value = '' then return 'NULL'
  return "'" || changestr("'", value, "''") || "'"

requireOk: procedure
  use arg result, label
  if result~status \= .Error~SUCCESS then do
    say 'FAIL:' label result~status result~error result~message
    exit 5
  end
  return

parseCsvLine: procedure
  use arg line
  a = .array~new
  v = ''
  quoted = 0
  do n = 1 to length(line)
    ch = substr(line, n, 1)
    if ch = '"' then do
      if quoted & n < length(line) & substr(line, n+1, 1) = '"' then do
        v = v || '"'
        n = n + 1
      end
      else quoted = \quoted
    end
    else if ch = ',' & \quoted then do
      a~append(v)
      v = ''
    end
    else v = v || ch
  end
  a~append(v)
  if quoted then a~append('INVALID_UNCLOSED_QUOTE')
  return a

::requires 'NoSQLServerSQLiteWritable.cls'