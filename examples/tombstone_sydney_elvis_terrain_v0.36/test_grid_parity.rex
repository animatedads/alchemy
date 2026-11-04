/* Deterministic 120 source-exact height/NoData probes, ooRexx only. */
parse arg wordFile fixture
if wordFile=='' | fixture=='' then exit 2
numeric digits 18
h=.HarbourHeightWords~new(wordFile)
if linein(fixture)\=='row|col|source_word' then exit 3
n=0;missing=0
do while lines(fixture)>0
 rec=linein(fixture)
 parse var rec row '|' col '|' wordExpected
 if \datatype(row,'W') | \datatype(col,'W') | wordExpected=='' then exit 4
 e=330586.9+(col-1)*50
 north=6259261.5-(row-1)*50
 p=h~queryXY(e,north)
 if p['ROW_1_BASED']<>row | p['COLUMN_1_BASED']<>col then do
  say 'GRID_INDEX_FAILED' row col 'queryXY='e north 'status='p['HEIGHT_STATUS'] p['ROW_1_BASED'] p['COLUMN_1_BASED'];exit 5
 end
 if wordExpected=='-' then do
  if p['HEIGHT_STATUS']\=='NO_DATA' then exit 6
  missing=missing+1
 end
 else if p['HEIGHT_STATUS']\=='HEIGHT_WORD_AVAILABLE' | p['HEIGHT_AHD_METRES']<>wordExpected then do
  say 'GRID_VALUE_FAILED' row col wordExpected p['HEIGHT_AHD_METRES']; exit 7
 end
 n=n+1
end
call stream fixture,'C','CLOSE'
if n<>120 | missing<>20 then exit 8
say 'HARBOUR_HEIGHT_WORDS_120_POINT_PARITY_PASS' n 'including_NODATA='missing
exit 0
::requires 'HarbourHeightWords.cls'
