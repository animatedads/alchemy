/* Independent ooRexx processes verify that application document identity
 * survives one store/reopen cycle. No browser or mock NotNotes objects. */
parse arg phase root mapFile
if root = '' | mapFile = '' then do
  say 'usage: identity-restart-probe.rex capture|verify db-root map-file'
  exit 2
end
if phase <> 'capture' & phase <> 'verify' then exit 2
app = .MiniNotesApp~new(root)
if phase = 'capture' then do
  app~seedFive
  call stream mapFile, 'C', 'OPEN WRITE REPLACE'
  count = 0
  do document over app~allDocuments
    call lineout mapFile, document~DocKey || '09'x || document~documentId
    count = count + 1
  end
  call lineout mapFile
  say 'IDENTITY_CAPTURE='count
  if count < 5 then exit 3
  exit 0
end

expected = .Directory~new
call stream mapFile, 'C', 'OPEN READ'
tab = '09'x
do while lines(mapFile) > 0
  line = linein(mapFile)
  parse var line key (tab) identity
  expected[key~upper] = identity
end
call linein mapFile
missing = expected~items
drift = 0
do document over app~allDocuments
  key = document~DocKey~string~upper
  if \expected~hasIndex(key) then iterate
  missing = missing - 1
  if expected[key] \== document~documentId then do
    say 'IDENTITY_DRIFT key='key 'before='expected[key] 'after='document~documentId
    drift = drift + 1
  end
end
say 'IDENTITY_REOPEN_MATCH='expected~items - missing - drift 'DRIFT='drift 'MISSING='missing
if drift > 0 | missing > 0 then exit 1
exit 0

::requires 'MiniNotesApp.cls'
