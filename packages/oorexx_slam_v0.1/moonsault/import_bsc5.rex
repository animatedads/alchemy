/* Moonsault BSC5 -> Alchemy NoSQLServer SQLite (ooRexx 5.3).
   Run from packages/oorexx_slam_v0.1/moonsault:
     rexx import_bsc5.rex bsc5_j2000.csv /path/to/new/moonsault.sqlite

   This is the native NoSQLServer path; no Python dependency.
   Loader is intended for a NEW database. It fails closed if it exists.
   Initial insert may be slow due to NoSQLServer snapshot-per-statement.
   See README for the fast one-time SQLite bulk bootstrap.
   Set REXX_PATH to packages/nosqlserver_v0.92-dev1/src or equivalent.
*/
parse arg input db
if input = '' | db = '' then do
  say 'Usage: rexx import_bsc5.rex INPUT.csv NEW_DB.sqlite'
  exit 2
end
if stream(input, 'c', 'query exists') = '' then do
  say 'FAIL: CSV missing:' input
  exit 2
end
if stream(db, 'c', 'query exists') \= '' then do
  say 'FAIL: destination exists; refusing overwrite:' db
  exit 2
end
engine = .SQLiteWritableDatabaseEngine~create(db)
sql = .NoSQLServerSQL~new(engine)
create = 'CREATE TABLE moonsault_bsc5 (' || ,
 'hr INTEGER PRIMARY KEY, ra_j2000_deg DECIMAL(12,8) NOT NULL,' || ,
 'dec_j2000_deg DECIMAL(12,8) NOT NULL,' || ,
 'visual_mag DECIMAL(5,2) NOT NULL,' || ,
 'proper_name VARCHAR(100), bayer VARCHAR(24),' || ,
 'constellation VARCHAR(3), flamsteed INTEGER, approx_kelvin INTEGER)'
call mustWork sql~execute(create), 'create table'
call stream input, 'c', 'open read'
header = linein(input)
expected = 'hr,ra_j2000_deg,dec_j2000_deg,visual_mag,proper_name,bayer,constellation,flamsteed,approx_kelvin'
if header \= expected then do
  say 'FAIL: unexpected CSV schema'
  exit 2
end
inserted = 0
do while lines(input) > 0
  record = linein(input)
  if strip(record) = '' then iterate
  parse var record hr ',' ra ',' decl ',' mag ',' starName ',' bayer ',' con ',' flam ',' kelvin
  if \datatype(hr,'W') | \datatype(ra,'N') | ,
     \datatype(decl,'N') | \datatype(mag,'N') then do
    say 'FAIL: invalid numerical source row:' inserted+2
    exit 3
  end
  if hr < 1 | hr > 9110 | ra < 0 | ra >= 360 | decl < -90 | decl > 90 then do
    say 'FAIL: out-of-range stellar coordinates:' hr
    exit 3
  end
  if flam = '' then flam = 'NULL'
  if kelvin = '' then kelvin = 'NULL'
  statement = 'INSERT INTO moonsault_bsc5 ' || ,
    '(hr,ra_j2000_deg,dec_j2000_deg,visual_mag,proper_name,bayer,' || ,
    'constellation,flamsteed,approx_kelvin) VALUES (' || ,
    hr || ',' || ra || ',' || decl || ',' || mag || ',' || ,
    quoteSql(starName) || ',' || quoteSql(bayer) || ',' || ,
    quoteSql(con) || ',' || flam || ',' || kelvin || ')'
  call mustWork sql~execute(statement), 'HR=' || hr
  inserted = inserted + 1
  if inserted // 1000 = 0 then say 'Inserted' inserted
end
call stream input, 'c', 'close'
if inserted \= 9096 then do
  say 'FAIL: expected 9096 inserted, observed' inserted
  exit 4
end
do hr in .array~of(424,2491,7001)
  rs = sql~execute('SELECT hr FROM moonsault_bsc5 WHERE hr=' || hr)
  call mustWork rs, 'read HR=' || hr
  if rs~rows~items \= 1 then do
    say 'FAIL: missing HR' hr
    exit 4
  end
end
say 'MOONSAULT BSC5 IMPORT: PASS ('inserted' HR rows)'
exit 0

quoteSql: procedure
  parse arg value
  return "'" || changestr("'",value,"''") || "'"

mustWork: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say 'FAIL:' label rs~status rs~error rs~message
    exit 5
  end
  return

::requires "NoSQLServerSQLiteWritable.cls"
