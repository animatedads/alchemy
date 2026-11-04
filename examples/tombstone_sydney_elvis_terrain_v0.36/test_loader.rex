parse arg file
if file=='' then exit 2
h=.HarbourHeightWords~new(file)
p=h~provenance
say 'SOURCE_GRID_ACCEPTED' p['CELLS'] p['MISSING_SAMPLES']
exit 0
::requires 'HarbourHeightWords.cls'
