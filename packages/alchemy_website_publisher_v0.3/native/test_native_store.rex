/* Run with a qualified ooRexx 5.3 + NoSQLServer v0.90, unused SQLite path. */
numeric digits 20
signal on syntax name failed
parse arg file
if file == '' then exit 64
if stream(file,'C','QUERY EXISTS') \= '' then do
  say 'REFUSE: choose nonexistent test database path'
  exit 2
end
s=.CmsWebsiteSnapshotStore~new(file)
call test s~revision=0, 'empty store revision'
a='{"schema":"alchemy.website.publisher.export/0.1","site":"rasenfalcon.com","authority":"CANDIDATE_ONLY","pages":{"home":{"headline":"O''Reilly & <script>"}}}'
r=s~append(a,0)
call test r=1, 'native insert #1'
call test s~revision=1, 'current revision #1'
row=s~get(1)
call test row['document']==a, 'exact bytes roundtrip #1'
rs=.CmsWebsiteSnapshotStore~new(file)
call test rs~revision=1, 'persist across engine reopen'
r=rs~append('{"schema":"alchemy.website.publisher.export/0.1","text":"second"}',1)
call test r=2, 'native insert #2'
row=rs~get(2)
call test row['parent_revision']=1, 'parent revision committed'
row=rs~get(1)
call test row['document']==a, 'immutable first revision'
rows=rs~all
call test rows~items=2, 'two committed snapshots'
call test rs~verify=2, 'revision parent chain read-only verification'
say 'PASS native editorial snapshot smoke (candidate-only)'
exit 0

test: procedure
  use arg cond,label
  if \cond then raise syntax 93.900 additional('FAIL:' label)
  return

failed:
  say 'FAIL:' condition('D')
  exit 2
::requires 'CmsWebsiteSnapshotStore.cls'
