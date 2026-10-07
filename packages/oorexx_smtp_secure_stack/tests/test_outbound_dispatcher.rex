root=value("TEST_ROOT",,"ENVIRONMENT")
if root="" then root="."
tmp=value("SMTP_TEST_TMP",,"ENVIRONMENT")
if tmp="" then tmp="/tmp/oorexx-smtp-dispatch-test"
address system "rm -rf '"||tmp||"'"
call SysMkDir tmp
cat=.StorageCatalogue~new
store=.StorageFabricSmtpStore~new(tmp,cat,"smtp-test","smtp-test-domain",tmp||"/catalogue.tsv")
delivery=.StorageFabricSmtpDeliveryProvider~new(store,.array~of("example.test"))
authority=.ToggleAuthority~new(.true)
verifier=.AlwaysSignedVerifier~new
svc=.SmtpService~new(.nil,.nil,authority,.AllowInspector~new,.nil,verifier,delivery,.CollectEvents~new)
sess=.SmtpSession~new("user-session","127.0.0.1","alice@example.test",.true,.true)

/* Queue while authorised, then revoke before release. Release must not touch network. */
env=.SmtpEnvelope~new("<alice@example.test>"); env~addRecipient("<carol@outside.test>")
msg=.SmtpMessage~new(env,"From: alice@example.test"||"0d0a"x||"0d0a"x||"signed body"||"0d0a"x)
queued=svc~relayOutbound(sess,msg,env~recipients)
call assert queued~ok,"initial outbound spool"
spool1=queued~value
authority~allowed=.false
blockedTransport=.CountingTransport~new
dispatcher=.SmtpOutboundDispatcher~new(svc,store,.StaticSmtpNextHopResolver~new(.SmtpNextHop~new("mx.test",25)),blockedTransport)
r=dispatcher~dispatch(spool1)
call assert \r~ok & r~code="DISPATCH_RELEASE_DENIED","release revalidation denies revoked EMAIL_SEND"
call assert blockedTransport~calls=0,"network not contacted after release denial"
sr=store~loadSpool(spool1); call assert sr~ok & sr~value~state=.SmtpSpoolState~HELD,"spool held after authority loss"

/* Separate message: first remote attempt delivers one recipient and defers one.
 * Retry must send only the still-deferred recipient. */
authority~allowed=.true
env2=.SmtpEnvelope~new("<alice@example.test>"); env2~addRecipient("<one@outside.test>"); env2~addRecipient("<two@outside.test>")
msg2=.SmtpMessage~new(env2,"From: alice@example.test"||"0d0a"x||"0d0a"x||"signed two-recipient body"||"0d0a"x)
queued2=svc~relayOutbound(sess,msg2,env2~recipients)
call assert queued2~ok,"second outbound spool"
spool2=queued2~value
partial=.PartialThenSuccessTransport~new
dispatcher2=.SmtpOutboundDispatcher~new(svc,store,.StaticSmtpNextHopResolver~new(.SmtpNextHop~new("mx.test",25)),partial)
r1=dispatcher2~dispatch(spool2)
call assert \r1~ok & r1~code="DEFERRED","partial first attempt deferred"
call assert partial~firstCount=2,"first attempt includes both recipients"
states=store~recipientStates(spool2,env2~recipients)
call assert states["<one@outside.test>"]["state"]=.SmtpSpoolState~DELIVERED,"first recipient durably delivered"
call assert states["<two@outside.test>"]["state"]=.SmtpSpoolState~DEFERRED,"second recipient durably deferred"
r2=dispatcher2~dispatch(spool2)
call assert r2~ok & r2~code="DELIVERED","retry completes spool"
call assert partial~secondCount=1,"retry contains one recipient only"
call assert partial~secondRecipient="<two@outside.test>","retry does not redeliver successful recipient"


/* Permanent remote failure records durable bounce evidence. */
env3=.SmtpEnvelope~new("<alice@example.test>"); env3~addRecipient("<gone@outside.test>")
msg3=.SmtpMessage~new(env3,"From: alice@example.test"||"0d0a"x||"0d0a"x||"signed permanent failure"||"0d0a"x)
queued3=svc~relayOutbound(sess,msg3,env3~recipients)
call assert queued3~ok,"third outbound spool"
failer=.PermanentFailTransport~new
dispatcher3=.SmtpOutboundDispatcher~new(svc,store,.StaticSmtpNextHopResolver~new(.SmtpNextHop~new("mx.test",25)),failer)
r3=dispatcher3~dispatch(queued3~value)
call assert \r3~ok & r3~code="FAILED","permanent remote failure finalizes failed"
call assert stream(tmp||"/bounce.tsv","c","query exists")<>"","bounce evidence ledger exists"
bounceText=charin(tmp||"/bounce.tsv",1,stream(tmp||"/bounce.tsv","c","query size")); call stream tmp||"/bounce.tsv","c","close"
call assert pos("550",bounceText)>0,"bounce evidence records remote 550"

say "test_outbound_dispatcher: PASS"
exit 0

assert:
  use arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
return

::class ToggleAuthority subclass SmtpAccessAuthority public
::attribute allowed
::method init
  expose allowed
  use strict arg allowedArg=.true
  allowed=allowedArg
::method authorize
  expose allowed
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then if allowed then return .SmtpResult~success("permit","PERMIT")
  return .SmtpResult~failure("DENY")

::class AlwaysSignedVerifier subclass SmtpMessageSignatureVerifier public
::method inspect
  use strict arg message,expectedIdentity=""
  identity="alice@example.test"; if expectedIdentity<>"" then identity=expectedIdentity
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.true,identity,"cert-alice","smime/cms","verified"),"SIGNED")

::class AllowInspector subclass SmtpPolicyInspector public
::method inspect
  use strict arg direction,session,message,context=.nil
  return .SmtpInspection~new(direction,"allow","test allow",0)

::class CollectEvents subclass SmtpEventSink public
::method init; expose events; events=.array~new
::method emit; expose events; use strict arg event; events~append(event); return .true

::class CountingTransport subclass SmtpRelayTransport public
::attribute calls get
::method init; expose calls; calls=0
::method deliver
  expose calls
  use strict arg hop,message,recipients
  calls+=1
  return .SmtpResult~failure("SHOULD_NOT_BE_CALLED")

::class PermanentFailTransport subclass SmtpRelayTransport public
::method deliver
  use strict arg hop,message,recipients
  a=.SmtpRelayAttempt~new(hop~host)
  do r over recipients; a~setRecipient(r,.SmtpSpoolState~FAILED,"550","5.1.1 mailbox unavailable"); end
  return .SmtpResult~success(a,"REMOTE_ATTEMPT")

::class PartialThenSuccessTransport subclass SmtpRelayTransport public
::attribute firstCount get
::attribute secondCount get
::attribute secondRecipient get
::method init
  expose calls firstCount secondCount secondRecipient
  calls=0; firstCount=0; secondCount=0; secondRecipient=""
::method deliver
  expose calls firstCount secondCount secondRecipient
  use strict arg hop,message,recipients
  calls+=1; a=.SmtpRelayAttempt~new(hop~host)
  if calls=1 then do
    firstCount=recipients~items
    a~setRecipient(recipients[1],.SmtpSpoolState~DELIVERED,"250","accepted")
    a~setRecipient(recipients[2],.SmtpSpoolState~DEFERRED,"451","try later")
  end
  else do
    secondCount=recipients~items; secondRecipient=recipients[1]
    do r over recipients; a~setRecipient(r,.SmtpSpoolState~DELIVERED,"250","accepted retry"); end
  end
  return .SmtpResult~success(a,"REMOTE_ATTEMPT")

::requires "SmtpCore.cls"
::requires "SmtpDurableDelivery.cls"
::requires "SmtpOutboundDispatcher.cls"
::requires "StorageFabric.cls"
