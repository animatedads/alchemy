/* Alchemy Website Publisher — NoSQLServer v0.90 snapshot adapter.
 * A deliberately single-writer, append-only editorial candidate ledger.
 * ONE native SQLite INSERT per revision. No cross-statement transaction claim.
 * The application never links to SQLite and never dispatches a publication.
 */
::class CmsWebsiteSnapshotStore public
::attribute path get
::attribute engine get
::attribute sql get

::method init
  expose path engine sql
  use arg dbPath
  if dbPath == '' | dbPath == .nil then raise syntax 93.900 additional('Missing database path')
  path = dbPath
  exists = stream(path, 'C', 'QUERY EXISTS')
  if exists == '' then engine = .SQLiteWritableDatabaseEngine~create(path)
  else engine = .SQLiteWritableDatabaseEngine~new(path)
  if engine~version~storage \= 'SQLITE_NATIVE_READWRITE' then raise syntax 93.900 additional('Wrong storage engine')
  sql = .NoSQLServerSQL~new(engine)
  if engine~table('publisher_snapshots') == .nil then do
    rs = sql~execute('CREATE TABLE publisher_snapshots (revision INTEGER PRIMARY KEY, site TEXT NOT NULL, parent_revision INTEGER NOT NULL, recorded_at TEXT NOT NULL, document TEXT NOT NULL)')
    self~mustSucceed(rs, 'CREATE TABLE')
  end

::method mustSucceed private
  use arg result, label
  if result~status \= .Error~SUCCESS then raise syntax 93.900 additional(label ':' result~message)
  return result

::method all
  expose sql
  rs = sql~execute('SELECT revision,site,parent_revision,recorded_at,document FROM publisher_snapshots ORDER BY revision')
  self~mustSucceed(rs, 'SELECT')
  return rs~rows

::method latest
  rows = self~all
  last = .nil
  do row over rows
    if row['site'] == 'rasenfalcon.com' then last = row
  end
  return last

::method revision
  last = self~latest
  if last == .nil then return 0
  return last['revision']

::method append
  expose engine
  use arg text, expected
  if text == .nil | text == '' then raise syntax 93.900 additional('Empty document')
  if text~length > 3000000 then raise syntax 93.900 additional('Document too large')
  if \datatype(expected,'W') | expected < 0 then raise syntax 93.900 additional('Expected revision must be a nonnegative integer')
  -- Content is opaque archival data, not trusted authorisation or validated JSON.
  -- Browser validates before export; the subsequent importer validates again.
  rows = self~all
  maxRev = 0
  latestSite = 0
  do row over rows
    if row['revision'] > maxRev then maxRev = row['revision']
    if row['site'] == 'rasenfalcon.com' then latestSite = row['revision']
  end
  if expected \= latestSite then raise syntax 93.900 additional('STALE_REVISION: use the current native snapshot')
  newRev = maxRev + 1
  vals = .table~new
  vals['revision'] = newRev
  vals['site'] = 'rasenfalcon.com'
  vals['parent_revision'] = latestSite
  vals['recorded_at'] = date('S') || 'T' || time('N') || ' LOCAL_UNVERIFIED'
  vals['document'] = text
  -- Native prepared insert: no interpolation of user-controlled JSON in SQL.
  -- Unique PRIMARY KEY detects concurrent inserts; no retry can silently overwrite.
  rs = engine~insert('publisher_snapshots', vals)
  self~mustSucceed(rs, 'INSERT')
  if rs~affectedRows \= 1 then raise syntax 93.900 additional('Unexpected insert count')
  return newRev

::method verify
  -- Read-only structural validation, not a cryptographic attestation or publishing approval.
  -- The site is deliberately fixed at rasenfalcon.com for this reference module.
  previous = 0
  count = 0
  do row over self~all
    if row['site'] \= 'rasenfalcon.com' then iterate
    rev = row['revision']
    parent = row['parent_revision']
    if \datatype(rev,'W') | \datatype(parent,'W') then raise syntax 93.900 additional('BAD_LEDGER_REVISION')
    if rev <= previous then raise syntax 93.900 additional('NON_MONOTONIC_REVISION')
    if parent \= previous then raise syntax 93.900 additional('BROKEN_PARENT_CHAIN')
    if row['document'] == '' then raise syntax 93.900 additional('EMPTY_LEDGER_DOCUMENT')
    previous = rev
    count += 1
  end
  return count

::method get
  use arg wanted = 0
  if \datatype(wanted,'W') | wanted < 0 then raise syntax 93.900 additional('Invalid revision')
  if wanted = 0 then return self~latest
  do row over self~all
    if row['revision'] = wanted & row['site'] == 'rasenfalcon.com' then return row
  end
  return .nil

::requires 'NoSQLServerSQLiteWritable.cls'
