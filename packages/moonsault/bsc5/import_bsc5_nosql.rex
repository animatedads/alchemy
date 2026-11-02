/* Moonsault native NoSQLServer BSC5 ingestion.
 * The CSV is parsed and verified BEFORE the first database mutation.
 * On the NoSQLServer FILE engine, one staged transaction publishes the two
 * new tables, all rows, and catalogue provenance atomically.
 *
 * Usage:
 *   rexx import_bsc5_nosql.rex PATH/stars.csv /existing/nosqlserver/database
 * Environment: REXX_PATH includes NoSQLServer v0.92-dev1 dependencies
 *              csvStream.cls, yaml.cls, json.cls, AlchemyObject.cls.
 * No Python; no new SQLite dependency; no implicit deployment target.
 */
numeric digits 18
parse arg csvPath dbRoot
if csvPath = '' | dbRoot = '' then do
  say 'Usage: rexx import_bsc5_nosql.rex SOURCE.csv NOSQL_DB_ROOT'
  exit 2
end

report = .MoonsaultBSC5Validator~new~scan(csvPath)
if \report['ok'] then do
  say 'REJECT: CSV preflight failed. Database was not opened.'
  do problem over report['errors']
    say problem
  end
  exit 1
end
if report['count'] \= 9096 then do
  say 'REJECT: unexpected catalogue count'
  exit 1
end
say 'PREFLIGHT PASSED:' report['count'] 'stars'

/* NoSQLServer is part of the Alchemy package estate; it is not reimplemented. */
engine = .FileDatabaseEngine~new(dbRoot)
if engine~table('moonsault_bsc5') \== .nil | engine~table('moonsault_catalogue_sources') \== .nil then do
  say 'REJECT: Moonsault tables already exist (no implicit overwrite)'
  exit 3
end

tx = engine~transaction
createStars = 'CREATE TABLE moonsault_bsc5 (' || -
  'hd INTEGER PRIMARY KEY, hip INTEGER, ra_j2000_deg DECIMAL NOT NULL, ' || -
  'dec_j2000_deg DECIMAL NOT NULL, visual_mag DECIMAL NOT NULL, ' || -
  'bv_colour DECIMAL, spectral_type VARCHAR, distance_pc DECIMAL, ' || -
  'proper_name VARCHAR, source_id VARCHAR NOT NULL, coordinate_epoch VARCHAR NOT NULL)'
createSources = 'CREATE TABLE moonsault_catalogue_sources (' || -
  'source_id VARCHAR PRIMARY KEY, title VARCHAR, source_url VARCHAR, ' || -
  'source_commit VARCHAR, source_blob VARCHAR, coordinate_epoch VARCHAR, ' || -
  'star_count INTEGER, qualification VARCHAR)'
if tx~execute(createStars)~error \= .Error~SUCCESS then do
  say 'REJECT: could not stage moonsault_bsc5 table'
  ignore = tx~rollback
  exit 4
end
if tx~execute(createSources)~error \= .Error~SUCCESS then do
  say 'REJECT: could not stage provenance table'
  ignore = tx~rollback
  exit 4
end

sourceId = 'ISENE_STARMAP_BSC5_20261031'
insertSql = 'INSERT INTO moonsault_bsc5 ' || -
  '(hd, hip, ra_j2000_deg, dec_j2000_deg, visual_mag, bv_colour, ' || -
  'spectral_type, distance_pc, proper_name, source_id, coordinate_epoch) ' || -
  'VALUES (?,?,?,?,?,?,?,?,?,?,?)'
prepared = tx~prepareStatement('moonsault_star', insertSql)
if prepared~error \= .Error~SUCCESS then do
  say 'REJECT: prepared insert declaration failed'
  ignore = tx~rollback
  exit 4
end
batch = tx~prepareBatch(prepared)
do record over report['rows']
  params = .array~new
  params~append(.DatabaseValue~integer(record['hd']))
  params~append(optionalNumber(record['hip'], 'INTEGER'))
  params~append(.DatabaseValue~decimal(record['ra']))
  params~append(.DatabaseValue~decimal(record['dec']))
  params~append(.DatabaseValue~decimal(record['mag']))
  params~append(optionalNumber(record['bv'], 'DECIMAL'))
  params~append(.DatabaseValue~varchar(record['spectral']))
  params~append(optionalNumber(record['distance'], 'DECIMAL'))
  params~append(optionalText(record['name']))
  params~append(.DatabaseValue~varchar(sourceId))
  params~append(.DatabaseValue~varchar('J2000'))
  ignore = batch~add(params)
end
queued = tx~executePreparedBatch(batch)
if queued~error \= .Error~SUCCESS then do
  say 'REJECT: unable to queue batch:' queued~message
  ignore = tx~rollback
  exit 4
end

sourceStmt = tx~prepareStatement('moonsault_source', -
  'INSERT INTO moonsault_catalogue_sources ' || -
  '(source_id,title,source_url,source_commit,source_blob,coordinate_epoch,star_count,qualification) ' || -
  'VALUES (?,?,?,?,?,?,?,?)')
if sourceStmt~error \= .Error~SUCCESS then do
  say 'REJECT: provenance statement preparation failed'
  ignore = tx~rollback
  exit 4
end
sourceParams = .array~of( -
  .DatabaseValue~varchar(sourceId), -
  .DatabaseValue~varchar('Yale Bright Star Catalogue-derived starmap CSV'), -
  .DatabaseValue~varchar('https://github.com/isene/starmap/blob/504bcd08ae90f2ca5772dca99de716db3c29e09f/data/stars.csv'), -
  .DatabaseValue~varchar('504bcd08ae90f2ca5772dca99de716db3c29e09f'), -
  .DatabaseValue~varchar('c7b9458deeb6aaa2d8fc71e98c47ea8cfcca4f6c'), -
  .DatabaseValue~varchar('J2000'), -
  .DatabaseValue~integer(report['count']), -
  .DatabaseValue~varchar('CSV_VALIDATED_NOT_ASTROMETRICALLY_QUALIFIED'))
queued = tx~executePrepared(sourceStmt, sourceParams)
if queued~error \= .Error~SUCCESS then do
  say 'REJECT: unable to stage catalogue source record'
  ignore = tx~rollback
  exit 4
end

say 'Committing native NoSQLServer staged transaction...'
result = tx~commit
if result~status \= .Error~COMMITTED | result~error \= .Error~SUCCESS then do
  say 'ROLLBACK / NOT COMMITTED:' result~status result~error result~message
  exit 5
end

loaded = engine~table('moonsault_bsc5')~rowCount
if loaded \= report['count'] then do
  say 'VERIFY FAILED: loaded rows' loaded 'expected' report['count']
  exit 6
end
say 'MOONSAULT BSC5 IMPORT PASS:' loaded 'stars committed in native NoSQLServer'
say 'Catalogue qualification: CSV_VALIDATED_NOT_ASTROMETRICALLY_QUALIFIED'
exit 0

optionalNumber: procedure
  use arg value, type
  if value = '' then return .DatabaseValue~nullValue
  if type = 'INTEGER' then return .DatabaseValue~integer(value)
  return .DatabaseValue~decimal(value)

optionalText: procedure
  use arg value
  if value = '' then return .DatabaseValue~nullValue
  return .DatabaseValue~varchar(value)

::requires 'MoonsaultBSC5Validator.cls'
::requires '../../nosqlserver_v0.92-dev1/src/NoSQLServer.cls'
