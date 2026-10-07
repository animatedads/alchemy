journal='/tmp/oorexx-webdav-dev4-sync-'||time('S')||'.txt'
address system 'rm -f' journal

j=.WebDavSyncJournal~new(100,journal)
j~record('/a',201,'PUT',1)
token=j~currentToken
j~record('/b',404,'DELETE',2)

j2=.WebDavSyncJournal~new(100,journal)
o=j2~changesSince(token,'/',100)
call must o~ok,'reloaded token accepted'
call eq o~changes~items,1,'one post-token change'
call eq o~changes[1]~path,'/b','reloaded changed path'
call eq o~changes[1]~status,404,'reloaded deletion status'

address system 'rm -f' journal
say 'WEBDAV DEV4 SYNC JOURNAL: OK'
exit 0
must: procedure
  use arg c,l
  if \c then do; say 'FAIL:' l; exit 1; end
  return
eq: procedure
  use arg a,e,l
  if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'WebDavCore.cls'
