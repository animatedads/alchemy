/* Social Media dev3 end-to-end publisher/authority/provenance qualification. */
library = .SocialLibrary~new
memory = .SocialMemoryProvider~new
library~register(memory)
grant = .SocialTestGrant~new
grant~grant('publish')
grant~grant('reply')
library~policy = .SocialPolicy~new(grant)
service = .SocialPublicationService~new(library)
steam = .SocialSurface~new('memory','gaming.review','app:1/reviews','public')
post = .SocialPublicationRequest~new('job:1','brand:studio','acct:official',steam,'publish','cms:item:1','v5','Release announcement','approval:abc','intent:77','narrative:21')
call expectDenied service, post
if memory~operations~items <> 0 then exit 11
approval = .SocialTestPublicationAuthority~new
approval~permit(post)
service~authority = approval
r = service~submit(post)
if r~status <> 'simulated' then exit 12
if memory~operations~items <> 1 then exit 13
if r~projection['contentVersion'] <> 'v5' then exit 14
if r~projection['brandId'] <> 'brand:studio' then exit 15
again = service~submit(post)
if again <> r | memory~operations~items <> 1 then exit 16
call expectReconciliationDenied service, 'job:1','delivered','fake',.SocialTestDeliveryVerifier~new
post~body = 'Unreviewed new claims'
call expectDenied service, post
if memory~operations~items <> 1 then exit 17
post~body = 'Release announcement'
post~addAsset('asset:new')
call expectDenied service, post
if memory~operations~items <> 1 then exit 18
post~assetRefs = .array~new
if service~submit(post) <> r then exit 19

/* Consent/authority is bound to one brand, account and surface, not platform.
 * The dev1 action-only test grant is deliberately NOT sufficient. */
otherAccount = .SocialPublicationRequest~new('job:2','brand:studio','acct:stranger',steam,'publish','cms:item:1','v5','Release announcement','approval:abc','intent:77','narrative:21')
call expectDenied service, otherAccount
if memory~operations~items <> 1 then exit 20

/* Reply must be directed to a fully qualified item on the same surface. */
reviewRef = .SocialReference~new(steam,'review:1','review')
reply = .SocialPublicationRequest~new('job:3','brand:studio','acct:official',steam,'reply','cms:reply:1','v1','We are investigating','approval:reply','intent:support','narrative:empathetic',reviewRef)
approval~permit(reply)
receipt = service~submit(reply)
if receipt~status <> 'simulated' then exit 21
if memory~operations~items <> 2 then exit 22
if receipt~projection['action'] <> 'reply' then exit 23
wrongSurface = .SocialSurface~new('memory','gaming.review','app:2/reviews','public')
call expectBadReply wrongSurface, reviewRef

/* Unknown dispatch blocks blind retry and needs verified reconciliation. */
unknownLib = .SocialLibrary~new
unknownProvider = .SocialFailingTestProvider~new
unknownLib~register(unknownProvider)
unknownLib~policy = .SocialPolicy~new(grant)
unknownService = .SocialPublicationService~new(unknownLib)
unknownAuthority = .SocialTestPublicationAuthority~new
unknownService~authority = unknownAuthority
remoteSurface = .SocialSurface~new('failing-test','social.feed','account/1','public')
ambiguous = .SocialPublicationRequest~new('job:remote','brand:a','account:own',remoteSurface,'publish','content:1','v1','Hello','approval:r','intent:i','story:s')
unknownAuthority~permit(ambiguous)
u = unknownService~submit(ambiguous)
if u~status <> 'unknown' then exit 24
if unknownProvider~attempts <> 1 then exit 25
if unknownService~submit(ambiguous) <> u then exit 26
if unknownProvider~attempts <> 1 then exit 27
call expectReconciliationDenied unknownService,'job:remote','delivered','proof:1',.SocialTestDeliveryVerifier~new
verifier = .SocialTestDeliveryVerifier~new
verifier~permit('job:remote','delivered','proof:1')
resolved = unknownService~reconcile('job:remote','delivered','proof:1',verifier)
if resolved~status <> 'delivered' then exit 28
if resolved~providerEvidence <> 'proof:1' then exit 29
call expectReconciliationDenied unknownService,'job:remote','rejected','proof:2',verifier

/* Verified inbound receipts can project brand evidence without inventing effect. */
reviewSurface = .SocialSurface~new('steam','gaming.review','app:440','public')
reviewTarget = .SocialReference~new(reviewSurface,'r2','review')
interaction = .SocialInteraction~new('evt:2','review','user:one',reviewTarget,.nil,'Could be improved','origin:steam')
graph = .SocialConversationGraph~new
gate = .SocialInboundGate~new(graph)
inVerifier = .SocialTestInboundVerifier~new
inVerifier~permit('origin:steam')
gate~verifier = inVerifier
accepted = gate~accept(interaction)
bridge = .SocialBrandInteractionBridge~new
evidence = bridge~projectAccepted(interaction,gate,'brand:studio','intent:listen')
if evidence['brandEffect'] <> 'not_assessed' then exit 30
if evidence['targetKey'] <> reviewTarget~key then exit 31
otherGate = .SocialInboundGate~new(.SocialConversationGraph~new)
otherGate~verifier = inVerifier
call expectBridgeDenied bridge,interaction,otherGate
say 'PASS: default denial, exact scoped authorisation, replay collision, simulated receipt, reply scoping, uncertain dispatch, verified reconciliation, brand evidence projection'
exit 0
expectDenied: procedure
  use arg service, request
  signal on syntax name caught
  x = service~submit(request)
  exit 91
  caught:
  return
expectBadReply: procedure
  use arg surface, parent
  signal on syntax name caught
  item = .SocialPublicationRequest~new('bad','b','a',surface,'reply','item','v','text','approv','intent','story',parent)
  exit 92
  caught:
  return
expectReconciliationDenied: procedure
  use arg service, requestId, status, evidence, verifier
  signal on syntax name caught
  r = service~reconcile(requestId,status,evidence,verifier)
  exit 93
  caught:
  return
expectBridgeDenied: procedure
  use arg bridge, interaction, gate
  signal on syntax name caught
  p = bridge~projectAccepted(interaction,gate,'brand','intent')
  exit 94
  caught:
  return
::class SocialFailingTestProvider public subclass SocialProvider
::method attempts attribute
::method init
  expose attempts
  attempts = 0
::method id
  return 'failing-test'
::method capabilities
  d = .directory~new
  d['publish'] = .SocialCapability~new('publish',.true)
  return d
::method perform
  expose attempts
  use strict arg action, context
  attempts += 1
  raise syntax 93.900 array ('Simulated lost reply after remote commit')
::requires 'SocialPublication.cls'
