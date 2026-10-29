/* v0.1-dev4: crash-window recovery, verified outcome, retry suppression. */
parse arg journalFile
if journalFile == '' then exit 95
if stream(journalFile,'c','query exists') <> '' then exit 96
lib = .SocialLibrary~new
provider = .SocialUnknownProviderDev4~new
lib~register(provider)
grant = .SocialTestGrant~new
grant~grant('publish')
lib~policy = .SocialPolicy~new(grant)
surface = .SocialSurface~new('unknown-provider','social.feed','acct','public')
req = .SocialPublicationRequest~new('req:unknown','brand','account',surface,'publish','cms:item','v1','Hello world','approval','intent','narrative')
auth = .SocialTestPublicationAuthority~new
auth~permit(req)
store = .SocialFilePublicationJournal~new(journalFile)
service = .SocialPublicationService~new(lib,store)
service~authority = auth
one = service~submit(req)
if one~status <> 'unknown' | provider~attempts <> 1 then exit 11
if store~sequence <> 3 then exit 12
reopened = .SocialPublicationService~new(lib,.SocialFilePublicationJournal~new(journalFile))
if reopened~lookup('req:unknown')~status <> 'unknown' then exit 13
if reopened~submit(req)~status <> 'unknown' | provider~attempts <> 1 then exit 14
verifier = .SocialTestDeliveryVerifier~new
verifier~permit('req:unknown','delivered','signed-test-proof')
reopened~reconcile('req:unknown','delivered','signed-test-proof',verifier)
if reopened~lookup('req:unknown')~status <> 'delivered' then exit 15
reopened2 = .SocialPublicationService~new(lib,.SocialFilePublicationJournal~new(journalFile))
if reopened2~lookup('req:unknown')~providerEvidence <> 'signed-test-proof' then exit 16
if reopened2~lookup('req:unknown')~status <> 'delivered' then exit 17
/* The incomplete prepared record represents an interrupted execution. */
path2 = journalFile || '.prepared'
j2 = .SocialFilePublicationJournal~new(path2)
req2 = .SocialPublicationRequest~new('req:prepared','brand','account',surface,'publish','cms:item','v1','Hello world','approval','intent','narrative')
prepared = .SocialPublicationReceipt~new(req2)
j2~save(prepared)
restored = .SocialPublicationService~new(lib,.SocialFilePublicationJournal~new(path2))
if restored~lookup('req:prepared')~status <> 'unknown' then exit 18
if restored~submit(req2)~status <> 'unknown' | provider~attempts <> 1 then exit 19
/* Prepared-only crash now has a durable unknown transition and can be resolved. */
if restored~journal~sequence <> 2 then exit 20
verifier2 = .SocialTestDeliveryVerifier~new
verifier2~permit('req:prepared','rejected','provider-not-found')
restored~reconcile('req:prepared','rejected','provider-not-found',verifier2)
if .SocialFilePublicationJournal~new(path2)~sequence <> 3 then exit 21
restoredAgain = .SocialPublicationService~new(lib,.SocialFilePublicationJournal~new(path2))
if restoredAgain~lookup('req:prepared')~status <> 'rejected' then exit 22
say 'PASS outbox: unknown dispatch recovery, verified reconciliation, persisted delivery, prepared crash window'
exit 0
::class SocialUnknownProviderDev4 public subclass SocialProvider
::method attempts attribute
::method init
  expose attempts
  attempts = 0
::method id
  return 'unknown-provider'
::method capabilities
  caps = .directory~new
  caps['publish'] = .SocialCapability~new('publish',.true)
  return caps
::method perform
  expose attempts
  use strict arg action, context
  attempts += 1
  raise syntax 93.900 array ('Simulated lost reply after potential remote commit')
::requires 'SocialPublicationJournal.cls'
