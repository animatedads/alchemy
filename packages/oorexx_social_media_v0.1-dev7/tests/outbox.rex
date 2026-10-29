/* v0.1-dev4: process restart journal, idempotency, ambiguity and corruption. */
parse arg journalFile
if journalFile == '' then exit 95
if stream(journalFile,'c','query exists') <> '' then exit 96 /* runner supplies new filename */
provider = .SocialMemoryProvider~new
lib = .SocialLibrary~new
lib~register(provider)
grant = .SocialTestGrant~new
grant~grant('publish')
lib~policy = .SocialPolicy~new(grant)
surface = .SocialSurface~new('memory','video.comment','channel:official','public')
req = .SocialPublicationRequest~new('req:1','brand:main','account:main',surface,'publish','cms:post','v7','A fair statement','approval:1','intent:1','story:1')
auth = .SocialTestPublicationAuthority~new
auth~permit(req)
store = .SocialFilePublicationJournal~new(journalFile)
svc = .SocialPublicationService~new(lib,store)
svc~authority = auth
one = svc~submit(req)
if one~status <> 'simulated' | provider~operations~items <> 1 then exit 11
if store~sequence <> 3 then exit 12
store2 = .SocialFilePublicationJournal~new(journalFile)
restart = .SocialPublicationService~new(lib,store2)
/* Replay must not require an old authority to recognise and suppress the job. */
if restart~lookup('req:1')~status <> 'simulated' then exit 13
if restart~submit(req)~status <> 'simulated' then exit 14
if provider~operations~items <> 1 then exit 15
req~body = 'Unapproved revision'
call expectDenied restart,req
req~body = 'A fair statement'
/* The journal MUST reject corrupt appended bytes, instead of replaying a prefix. */
call lineout journalFile,'torn'
call stream journalFile,'c','close'
call expectCorrupt journalFile
say 'PASS outbox: recorded before dispatch, process restart, idempotency, collision and corruption fail-closed'
exit 0
expectDenied: procedure
  use arg service,req
  signal on syntax name caught
  r = service~submit(req)
  exit 81
  caught:
  return
expectCorrupt: procedure
  use arg path
  signal on syntax name caught
  j = .SocialFilePublicationJournal~new(path)
  exit 82
  caught:
  return
::requires 'SocialPublicationJournal.cls'
