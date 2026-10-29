/* dev6: complete simulated provider via adapter SPI, not a network service. */
parse arg journalPath
if journalPath == '' then exit 90
journal = .SocialFilePublicationJournal~new(journalPath)
lib = .SocialLibrary~new
reg = .SocialAdapterRegistry~new
adapter = .SocialTestAdapter~new('steam-test')
reg~register(adapter)
call deniedRegistration reg,adapter
policy = .SocialTestGrant~new
policy~grant('publish')
lib~policy = .SocialPolicy~new(policy)
auth = .SocialTestPublicationAuthority~new
resolver = .SocialAdapterScopedResolver~new(reg)
guard = .SocialDispatchGuard~new(auth,resolver,lib~policy,journal)
lib~register(.SocialAdapterProvider~new(adapter,guard))
/* Missing guard must fail at construction before any provider action. */
call deniedUnguarded adapter
surface = .SocialSurface~new('steam-test','gaming.review','app:42','public')
other = .SocialSurface~new('steam-test','gaming.review','app:43','public')
req = .SocialPublicationRequest~new('job:61','studio','acct:42',surface,'publish','cms:1','v1','Patch notes','cms-approval:1','launch','positive')
auth~permit(req)
svc = .SocialScopedPublicationService~new(lib,journal,.SocialAdapterScopedResolver~new(reg))
svc~authority = auth
call denied svc,req
if adapter~operations~items <> 0 then exit 11
/* Public low-level execute cannot evade the scope or approval authority. */
call deniedDirect lib,req
if adapter~operations~items <> 0 then exit 20
cap = .SocialScopedCapability~new('steam-test','acct:42',surface~key,'publish','r1','test-only',.true,200,0)
adapter~permit(cap)
/* Even valid approval + current capability do not permit bypassing the outbox. */
call deniedDirect lib,req
if adapter~operations~items <> 0 then exit 22
x = svc~submit(req)
if x~status <> 'simulated' then exit 12
if adapter~operations~items <> 1 then exit 13
/* Execution-time guard rejects an attempted second direct dispatch. */
call deniedDirect lib,req
if adapter~operations~items <> 1 then exit 21
adapter~revoke(cap)
if svc~submit(req) <> x then exit 14
if adapter~operations~items <> 1 then exit 15
otherReq = .SocialPublicationRequest~new('job:62','studio','acct:42',other,'publish','cms:1','v1','Patch notes','cms-approval:1','launch','positive')
auth~permit(otherReq)
call denied svc,otherReq
if adapter~operations~items <> 1 then exit 16
noAuthority = .SocialScopedPublicationService~new(lib,journal,.SocialAdapterScopedResolver~new(reg))
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
say 'PASS adapter dev7: guarded lower-layer dispatch, context binding, dedupe, scope/approval/inbound/reconcile gates'
exit 0
deniedUnguarded: procedure
  use arg adapter
  signal on syntax name caught
  unsafe = .SocialAdapterProvider~new(adapter)
  exit 96
  caught:
  return
deniedDirect: procedure
  use arg lib,request
  signal on syntax name caught
  ctx = request~context
  x = lib~execute(request~surface~providerId,request~action,ctx)
  exit 95
  caught:
  return
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
