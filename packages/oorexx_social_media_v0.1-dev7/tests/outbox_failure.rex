/* Failed durable checkpoint MUST prevent the external provider call. */
lib = .SocialLibrary~new
mem = .SocialMemoryProvider~new
lib~register(mem)
grant = .SocialTestGrant~new
grant~grant('publish')
lib~policy = .SocialPolicy~new(grant)
surface = .SocialSurface~new('memory','social.feed','account:test','public')
r = .SocialPublicationRequest~new('req:savefail','brand','account',surface,'publish','cms','v1','Text','approval','intent','story')
auth = .SocialTestPublicationAuthority~new
auth~permit(r)
noPrepare = .SocialFailCheckpoint~new('prepared')
a = .SocialPublicationService~new(lib,noPrepare)
a~authority = auth
call expectFailure a,r
if mem~operations~items <> 0 then exit 11
if a~lookup('req:savefail') <> .nil then exit 12
noDispatch = .SocialFailCheckpoint~new('dispatching')
b = .SocialPublicationService~new(lib,noDispatch)
b~authority = auth
call expectFailure b,r
if mem~operations~items <> 0 then exit 13
if noDispatch~states~items <> 2 then exit 14
/* An interrupted dispatcher remains blocked even if caller retries. */
if b~submit(r)~status <> 'dispatching' | mem~operations~items <> 0 then exit 15
say 'PASS outbox: journal checkpoint failure prevents provider side effects'
exit 0
expectFailure: procedure
  use arg service,req
  signal on syntax name caught
  r = service~submit(req)
  exit 80
  caught:
  return
::class SocialFailCheckpoint public subclass SocialPublicationJournal
::method failAt attribute
::method states attribute
::method init
  expose failAt states
  use strict arg failAt
  states = .array~new
::method replay
  return .directory~new
::method save
  expose failAt states
  use strict arg ticket
  states~append(ticket~status)
  if ticket~status == failAt then raise syntax 93.900 array ('Simulated durable checkpoint failure')
  return .true
::requires 'SocialPublicationJournal.cls'
