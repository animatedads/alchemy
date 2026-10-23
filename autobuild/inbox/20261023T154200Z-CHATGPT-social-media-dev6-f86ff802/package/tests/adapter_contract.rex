/* dev6: complete simulated provider via adapter SPI, not a network service. */
lib = .SocialLibrary~new
reg = .SocialAdapterRegistry~new
adapter = .SocialTestAdapter~new('steam-test')
reg~register(adapter)
call deniedRegistration reg,adapter
lib~register(.SocialAdapterProvider~new(adapter))
lib~policy = .SocialPolicy~new(.SocialTestGrant~new)
lib~policy~authorizer~grant('publish')
surface = .SocialSurface~new('steam-test','gaming.review','app:42','public')
other = .SocialSurface~new('steam-test','gaming.review','app:43','public')
req = .SocialPublicationRequest~new('job:61','studio','acct:42',surface,'publish','cms:1','v1','Patch notes','cms-approval:1','launch','positive')
auth = .SocialTestPublicationAuthority~new
auth~permit(req)
svc = .SocialScopedPublicationService~new(lib,.nil,.SocialAdapterScopedResolver~new(reg))
svc~authority = auth
call denied svc,req
if adapter~operations~items <> 0 then exit 11
cap = .SocialScopedCapability~new('steam-test','acct:42',surface~key,'publish','r1','test-only',.true,200,0)
adapter~permit(cap)
x = svc~submit(req)
if x~status <> 'simulated' then exit 12
if adapter~operations~items <> 1 then exit 13
adapter~revoke(cap)
if svc~submit(req) <> x then exit 14
if adapter~operations~items <> 1 then exit 15
otherReq = .SocialPublicationRequest~new('job:62','studio','acct:42',other,'publish','cms:1','v1','Patch notes','cms-approval:1','launch','positive')
auth~permit(otherReq)
call denied svc,otherReq
if adapter~operations~items <> 1 then exit 16
noAuthority = .SocialScopedPublicationService~new(lib,.nil,.SocialAdapterScopedResolver~new(reg))
adapter~permit(cap)
newReq = .SocialPublicationRequest~new('job:63','studio','acct:42',surface,'publish','cms:1','v1','Update','cms-approval:1','launch','positive')
call denied noAuthority,newReq
if adapter~operations~items <> 1 then exit 17
/* Any adapter-controlled inbound proof defaults to denial in test mode. */
ref = .SocialReference~new(surface,'review:19','review')
interaction = .SocialInteraction~new('event:1','review','user:1',ref,.nil,'Loved it','steam-test')
graph = .SocialConversationGraph~new
gate = .SocialInboundGate~new(graph)
gate~verifier = .SocialAdapterInboundVerifier~new(reg)
call deniedInbound gate,interaction
if graph~count <> 0 then exit 18
verifier = .SocialAdapterDeliveryVerifier~new(reg)
if verifier~verify(x,'delivered','proof') then exit 19
say 'PASS adapter contract: scope/approval/idempotency/inbound/reconcile gates'
exit 0
denied: procedure
  use arg service,req
  signal on syntax name caught
  x = service~submit(req)
  exit 97
  caught:
  return
deniedRegistration: procedure
  use arg registry,adapter
  signal on syntax name caught
  registry~register(adapter)
  exit 98
  caught:
  return
deniedInbound: procedure
  use arg gate,event
  signal on syntax name caught
  x = gate~accept(event)
  exit 99
  caught:
  return
::requires 'SocialAdapterContract.cls'
