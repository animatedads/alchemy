parse arg folder manifest
bundle=.DiplomacyDesignBundle~new(folder,manifest)
if bundle~digest~length\=128 then exit 1
if bundle~bytes~pos('Exact rules')=0 then exit 2
other=.DiplomacyDesignBundle~new(folder,manifest)
if bundle~bytes\==other~bytes | bundle~digest\==other~digest then exit 3
say 'PASS deterministic designer bundle'
exit 0
::requires 'DiplomacyDesignBundle.cls'
