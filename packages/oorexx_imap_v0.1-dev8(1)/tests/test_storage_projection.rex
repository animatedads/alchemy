cat=.StorageCatalogue~new
env=.StorageEnvironment~new("imap-qual",.StorageEnvironmentKind~TEST)
ns=.StorageNamespace~new("imap-qual",cat,env)
rec=.ImapStorageMessageRecord~new("gmail:bashqueue","INBOX",13,1,323,"Your Mailbox is at 99%","no-reply@accounts.google.com","2026-09-16T14:30:00","","<m1@example>")
proj=.ImapStorageNamespaceProjector~new("imap:gmail","/mail/inbox")
path=proj~bindMessage(ns,rec)
call assert path~left(12)="/mail/inbox/", "message projected under inbox"
r=ns~resolve(path)
call assert r~found, "projected path resolves"
obj=cat~get(rec~objectId)
call assert obj<>.nil, "catalogue object exists"
call assert obj~eaValue("imap.from")="no-reply@accounts.google.com", "From exposed as Storage EA"
call assert obj~eaValue("imap.uid")=1, "UID exposed as Storage EA"
call assert r~entry~writePolicy=.StorageWritePolicy~READ_ONLY, "initial IMAP projection is read-only"

idxRec=.ImapIndexRecord~new("gmail:bashqueue","INBOX",13,2,401,"Facebook notice","social@example.net","2026-09-16T14:31:00","","<m2@example>")
idxResult=.ImapIndexSearchResult~new("facebook",.array~of("facebook"),.array~of(idxRec),.false,.false)
paths=proj~bindIndexResult(ns,idxResult)
call assert paths~items=1, "index result projects without database-specific types"
call assert ns~resolve(paths[1])~found, "indexed projection resolves"
s=.ImapStorageSemanticSelector~new("?attachment:1:?filename")
call assert s~isAttachment, "attachment relation recognized"
call assert s~attachmentIndex=1, "attachment index parsed"
call assert s~tailCount=1, "selector tail retained"
say "PASS test_storage_projection"
exit 0
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapStorageFabricProjection.cls"
::requires "ImapIndexCore.cls"
