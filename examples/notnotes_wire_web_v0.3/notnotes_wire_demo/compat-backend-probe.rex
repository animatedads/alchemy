/* Isolated adapter startup probe. No seed, no writes, no implicit migration. */
parse arg dbRoot
if dbRoot = '' then do
  say 'ERROR: missing isolated database root'
  exit 2
end
app = .MiniNotesApp~new(dbRoot)
db = app~persistence~database
if db~hasMethod('backendId') then say 'BACKEND_ID='db~backendId
else say 'BACKEND_ID=legacy-file'
exit 0
::requires 'MiniNotesApp.cls'
