/* Prove category shard writing is sparse and CsvStream-backed. */
root = directory()
fixture = root || '/tests/fixtures/police'
outDir = root || '/tests/.sparse_snapshot'
shardDir = outDir || '/category_shards'
call SysMkDir outDir
call SysMkDir shardDir

builder = .CrimeAreaAggregateBuilder~new
set = builder~ingestDirectory(fixture, .true, .false)

/* Seed a large empty area universe.  The shard writer must not emit rows for
   areas without a non-zero category cell. */
do i = 1 to 1000
  code = 'X' || i~right(8, '0')
  ignore = set~ensureArea(code, 'empty area' i)
end

.CrimeSnapshotWriter~write(set, outDir)

manifest = .CsvStream~new(shardDir || '/manifest.csv', .false, .true)
manifest~open('READ')
if manifest~chars > 0 then ignore = manifest~csvLineIn
categories = 0
cells = 0
do while manifest~chars > 0
  fields = manifest~csvLineIn
  if fields~items >= 3 then do
    categories += 1
    cells += fields[3] + 0
  end
end
manifest~close

call assert categories = 2, 'two non-zero crime category shards'
call assert cells = 2, 'only two non-zero cells written'

loaded = .CrimeMapSnapshotReader~read(outDir, .array~of('Burglary', 'Anti-social behaviour'))
call assert loaded~areas~items = 1001, 'empty area universe preserved separately'
call assert loaded~count('2025-08', 'E01000001', .array~of('Burglary')) = 1, 'burglary shard roundtrip'
call assert loaded~count('2025-08', 'E01000001', .array~of('Anti-social behaviour')) = 1, 'asb shard roundtrip'

/* Fixed test artefacts: remove without invoking a shell. */
do file over .array~of('lsoa_catalog.csv', 'crime_area_period.csv', 'crime_area_category_period.csv', 'crime_area_outcome_period.csv', 'crime_ingest_stats.csv')
  call SysFileDelete outDir || '/' || file
end
call SysFileDelete shardDir || '/manifest.csv'
call SysFileDelete shardDir || '/category-001.csv'
call SysFileDelete shardDir || '/category-002.csv'
call SysRmDir shardDir
call SysRmDir outDir

say 'PASS crime_area_analytics_v0.3 sparse category shard smoke'
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say 'FAIL' message
  exit 1

::requires 'CrimePoliceData.cls'
::requires 'csvStream.cls'
