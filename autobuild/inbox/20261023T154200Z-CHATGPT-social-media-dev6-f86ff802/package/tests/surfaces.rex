/* Social semantics, fail-closed ingress, cross-provider identity and taxonomy. */
cat = .SocialSurfaceCatalog~new~populateCommon
if cat~count <> 15 then exit 21
if \cat~profile('gaming.review')~supports('developer_response') then exit 22
if \cat~profile('video.creator')~supports('membership') then exit 23
if \cat~profile('chat.community')~supports('role') then exit 24
if \cat~profile('marketplace.product')~supports('question') then exit 25
if cat~profile('undefined') <> .nil then exit 26

steam = .SocialSurface~new('steam','gaming.review','app:440','public')
disc = .SocialSurface~new('discord','chat.community','guild:abc/channel:123','members')
youtube = .SocialSurface~new('youtube','video.comments','video:xyz','public')
if steam~key == disc~key then exit 27
if youtube~key == steam~key then exit 28
review = .SocialReference~new(steam,'r001','review')
response = .SocialReference~new(steam,'rp001','developer_response')
replyEv = .SocialInteraction~new('inbound-1','developer_response','studio:publisher',response,review,'Thanks for the feedback','steam:verified-webhook')
graph = .SocialConversationGraph~new
gate = .SocialInboundGate~new(graph)
call expectDenial gate, replyEv
if graph~count <> 0 then exit 29
verifier = .SocialTestInboundVerifier~new
verifier~permit('steam:verified-webhook')
gate~verifier = verifier
receipt = gate~accept(replyEv)
if receipt['status'] <> 'accepted' then exit 30
if graph~count <> 1 then exit 31
if graph~childrenOf(review)~items <> 1 then exit 32
receipt = gate~accept(replyEv)
if receipt['status'] <> 'duplicate' then exit 33
if graph~count <> 1 then exit 34
msg = .SocialInteraction~new('inbound-2','reply','person:alice',.SocialReference~new(disc,'m100','message'),.nil,'Hi!','unverified:discord')
call expectDenial gate, msg
if graph~count <> 1 then exit 35
variant = .SocialCreativeVariant~new('campaign:1/a','helpful','new members','What is new?','asset:original')
variant~addAsset('asset:shortform')
if variant~assets~items <> 1 then exit 36
paid = .SocialPaidPlacementPlan~new(variant~id,youtube,999,'GBP','business:account','approval:pending')
if paid~budgetMinor <> 999 then exit 37
rel = .SocialParticipation~new('channel:creator',youtube,'creator','observed','source:event:1')
fan = .SocialParticipation~new('person:fan',youtube,'member','observed','source:event:2')
roles = .SocialParticipationIndex~new
roles~record(rel)
roles~record(fan)
if roles~count <> 2 then exit 38
if roles~find('person:fan',youtube,'member') == .nil then exit 39
if roles~find('person:fan',steam,'member') <> .nil then exit 40
if roles~find('person:fan',youtube,'moderator') <> .nil then exit 41
say 'PASS: 15 semantic surface types, Steam/Discord/YouTube, review thread edges, authenticated ingress, duplicate rejection, creative variants, scoped creator roles, bounded ad request'
exit 0
expectDenial: procedure
  use arg gate, event
  signal on syntax name rejected
  gate~accept(event)
  raise syntax 93.900 array ('Expected denial')
  rejected:
  return
::requires 'SocialMedia.cls'
