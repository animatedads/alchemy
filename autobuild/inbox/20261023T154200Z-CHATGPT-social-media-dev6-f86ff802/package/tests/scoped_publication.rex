/* Dev5: strict capability admission and independent publication authority. */
lib = .SocialLibrary~new
memory = .SocialMemoryProvider~new
lib~register(memory)
policy = .SocialTestGrant~new
policy~grant('publish')
policy~grant('reply')
lib~policy = .SocialPolicy~new(policy)
steam = .SocialSurface~new('memory','gaming.review','app:1','public')
otherSteam = .SocialSurface~new('memory','gaming.review','app:2','public')
req = .SocialPublicationRequest~new('job:5','brand:game','acct:dev',steam,'publish','cms:news','v2','New patch available','approved:2','intent:launch','narrative:patch')
auth = .SocialTestPublicationAuthority~new
auth~permit(req)
/* Fail closed without resolver even with valid brand approval and policy. */
strict = .SocialScopedPublicationService~new(lib)
strict~authority = auth
call denied strict,req
if memory~operations~items <> 0 then exit 11
resolver = .SocialTestScopedResolver~new
strict = .SocialScopedPublicationService~new(lib,.nil,resolver)
strict~authority = auth
call denied strict,req
if memory~operations~items <> 0 then exit 12
cap = .SocialScopedCapability~new('memory','acct:dev',steam~key,'publish','r1','test:evidence',.true,64,0)
resolver~install(cap)
result = strict~submit(req)
if result~status <> 'simulated' then exit 13
if memory~operations~items <> 1 then exit 14
/* Replay never dispatches again, even after capability revocation. */
resolver~revoke(cap)
if strict~submit(req) <> result then exit 15
if memory~operations~items <> 1 then exit 16
/* Exact account and surface do not inherit another account's capability. */
different = .SocialPublicationRequest~new('job:6','brand:game','acct:other',steam,'publish','cms:news','v2','New patch available','approved:2','intent:launch','narrative:patch')
auth~permit(different)
call denied strict,different
cross = .SocialPublicationRequest~new('job:7','brand:game','acct:dev',otherSteam,'publish','cms:news','v2','New patch available','approved:2','intent:launch','narrative:patch')
auth~permit(cross)
call denied strict,cross
/* Reenable capability and prove content and media limits fail BEFORE dispatch. */
resolver~install(cap)
long = .SocialPublicationRequest~new('job:8','brand:game','acct:dev',steam,'publish','cms:news','v2',copies('a',65),'approved:2','intent:launch','narrative:patch')
auth~permit(long)
call denied strict,long
asset = .SocialPublicationRequest~new('job:9','brand:game','acct:dev',steam,'publish','cms:news','v2','New patch available','approved:2','intent:launch','narrative:patch')
asset~addAsset('media:a')
auth~permit(asset)
call denied strict,asset
/* Reply requires a distinct capability: publish does not imply reply. */
parent = .SocialReference~new(steam,'review:1','review')
reply = .SocialPublicationRequest~new('job:10','brand:game','acct:dev',steam,'reply','cms:response','v1','Thank you','approved:3','intent:support','narrative:care',parent)
auth~permit(reply)
call denied strict,reply
/* A discovered surface capability cannot replace institutional approval. */
capReply = .SocialScopedCapability~new('memory','acct:dev',steam~key,'reply','r2','test:evidence',.true,64,0)
resolver~install(capReply)
strictNoAuthority = .SocialScopedPublicationService~new(lib,.nil,resolver)
call denied strictNoAuthority,reply
if memory~operations~items <> 1 then exit 17
/* Dynamic revocation is checked per newly admitted request. */
resolver~revoke(capReply)
call denied strict,reply
resolver~install(capReply)
rep = strict~submit(reply)
if rep~status <> 'simulated' then exit 18
if memory~operations~items <> 2 then exit 19
say 'PASS scoped publication: account/surface/action capability, deny default, independent policy, limits, live revocation, replay'
exit 0
denied: procedure
  use arg service,req
  signal on syntax name caught
  x = service~submit(req)
  exit 97
  caught:
  return
::requires 'SocialScopedPublication.cls'
