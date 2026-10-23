/* The phases must be executed in two distinct rexx processes by run_all.sh. */
parse arg phase journalFile
if phase <> 'produce' & phase <> 'restart' then exit 91
lib = .SocialLibrary~new
provider = .SocialMemoryProvider~new
lib~register(provider)
grant = .SocialTestGrant~new
grant~grant('publish')
lib~policy = .SocialPolicy~new(grant)
surface = .SocialSurface~new('memory','social.feed','publisher:1','public')
req = .SocialPublicationRequest~new('two-process:1','brand:1','account:1',surface,'publish','cms:two','v2','Hello with a' || '0a'x || 'newline!','approved:2','intent:2','story:2')
req~addAsset('artwork:7')
store = .SocialFilePublicationJournal~new(journalFile)
service = .SocialPublicationService~new(lib,store)
if phase == 'produce' then do
  approval = .SocialTestPublicationAuthority~new
  approval~permit(req)
  service~authority = approval
  receipt = service~submit(req)
  if receipt~status <> 'simulated' | provider~operations~items <> 1 then exit 11
  say 'PASS process 1: journal written, multiline content and asset preserved'
end
else do
  receipt = service~lookup('two-process:1')
  if receipt == .nil then exit 12
  if receipt~status <> 'simulated' then exit 13
  if receipt~context['body'] <> req~body then exit 14
  if receipt~context['assets'][1] <> 'artwork:7' then exit 15
  if service~submit(req)~status <> 'simulated' then exit 16
  if provider~operations~items <> 0 then exit 17
  say 'PASS process 2: independent interpreter replay, no provider repeat'
end
exit 0
::requires 'SocialPublicationJournal.cls'
