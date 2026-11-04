/* WAL-mode qualification against an EXISTING publisher smoke database.
 * Requires revisions 1 and 2 from native/test_native_store.rex.
 * This command commits one additional candidate snapshot (revision 3).
 */
numeric digits 20
signal on syntax name failed
parse arg file
if file == '' then exit 64
store=.CmsWebsiteSnapshotStore~new(file)
if store~revision \= 2 then raise syntax 93.900 additional('WAL start revision mismatch')
if store~verify \= 2 then raise syntax 93.900 additional('WAL parent chain mismatch')
if store~append('{"schema":"alchemy.website.publisher.export/0.1","case":"WAL-3"}',2) \= 3 then raise syntax 93.900 additional('WAL insert mismatch')
reopened=.CmsWebsiteSnapshotStore~new(file)
if reopened~revision \= 3 then raise syntax 93.900 additional('WAL reopen mismatch')
row=reopened~get(3)
if row['parent_revision'] \= 2 then raise syntax 93.900 additional('WAL parent mismatch')
if reopened~verify \= 3 then raise syntax 93.900 additional('WAL final chain mismatch')
say 'PASS native WAL publisher read, append, reopen, verify'
exit 0
failed:
  say 'FAIL WAL publisher:' condition('D')
  exit 2
::requires 'CmsWebsiteSnapshotStore.cls'
