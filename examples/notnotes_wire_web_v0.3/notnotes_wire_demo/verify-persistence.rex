/* Verify that the real NotNotes persistent store survives an interpreter restart. */
parse arg dbRoot
if dbRoot='' then do
  say 'FAIL persistence: dbRoot required'
  exit 2
end
app=.MiniNotesApp~new(dbRoot)
document=app~byKey('PR-1003')
if document==.nil then do
  say 'FAIL persistence: PR-1003 not reloaded'
  exit 3
end
if document~Title\='INTENT-ADJUSTED' then do
  say 'FAIL persistence: unexpected title' document~Title
  exit 4
end
found=.nil
do doc over app~allDocuments
  if doc~formName='Purchase Checklist' then found=doc
end
if found==.nil then do
  say 'FAIL persistence: Purchase Checklist missing'
  exit 5
end
if found~field('COST')\='175' then do
  say 'FAIL persistence: COST expected 175 got' found~field('COST')
  exit 6
end
if found~field('RELATED')\='PR-1002' then do
  say 'FAIL persistence: RELATED expected PR-1002 got' found~field('RELATED')
  exit 7
end
if app~reportDefinition('Checklist totals')==.nil then do
  say 'FAIL persistence: saved report missing'
  exit 8
end
say 'PASS persistence: user format, typed field, single retained reference and saved report'
say 'PASS persistence: PR-1003 reloaded with confirmed intention title' document~Title
exit 0
::requires 'MiniNotesApp.cls'
