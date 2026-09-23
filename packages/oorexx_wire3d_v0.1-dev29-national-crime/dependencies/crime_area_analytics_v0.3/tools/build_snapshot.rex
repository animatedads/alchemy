/* build_snapshot.rex INPUT_ROOT OUTPUT_DIR [LSOA_REFERENCE] [INCLUDE_STOPS] */
parse arg inputRoot outputDir lsoaReference includeStops
if inputRoot = "" then do
  say "usage: rexx build_snapshot.rex INPUT_ROOT OUTPUT_DIR [LSOA_REFERENCE] [INCLUDE_STOPS]"
  exit 2
end
if outputDir = "" then outputDir = "crime_snapshot"
if includeStops = "" then includeStops = 0

builder = .CrimeAreaAggregateBuilder~new
builder~progressEnabled = .true
if lsoaReference <> "" then .CrimeLSOAReferenceReader~seedDataset(builder~dataset, lsoaReference)
start = time('R')
dataset = builder~ingestDirectory(inputRoot, .true, includeStops = 1)
elapsed = time('E')
dataset~sourceRevision = "data.police.uk-derived-"date('S')
.CrimeSnapshotWriter~write(dataset, outputDir)

say "streetRows="dataset~streetRowCount
say "outcomeRows="dataset~outcomeRowCount
say "stopSearchRows="dataset~stopSearchRowCount
say "areas="dataset~areas~items
say "periods="dataset~periods~items
say "frames="dataset~frames~items
say "outcomeCells="dataset~outcomeCounts~items
say "elapsedSeconds="elapsed
say "output="outputDir
exit 0

::requires "CrimePoliceData.cls"
