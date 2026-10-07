parse source . . thisFile
root=value("TEST_ROOT",,"ENVIRONMENT")
if root="" then root="."
tmp=value("SMTP_TEST_TMP",,"ENVIRONMENT")
if tmp="" then tmp="/tmp/oorexx-smtp-durable-test"
address system "rm -rf '"||tmp||"'"
call SysMkDir tmp
cat=.StorageCatalogue~new
store=.StorageFabricSmtpStore~new(tmp,cat,"smtp-test","smtp-test-domain",tmp||"/catalogue.tsv")
localDomains=.array~of("example.test")
delivery=.StorageFabricSmtpDeliveryProvider~new(store,localDomains)

/* Inbound: verified signed message becomes one durable object plus INBOX membership. */
env=.SmtpEnvelope~new("alice@remote.test"); env~addRecipient("bob@example.test")
msg=.SmtpMessage~new(env,"From: alice@remote.test"||"0d0a"x||"To: bob@example.test"||"0d0a"x||"0d0a"x||"hello")
sess=.SmtpSession~new("s-in","127.0.0.1","",.false,.true)
sig=.SmtpMessageSignatureEvidence~new(.true,.true,"alice@remote.test","cert-a","smime/cms","verified")
msg~metadata["signature.present"]=.true; msg~metadata["signature.verified"]=.true; msg~metadata["signature.signerIdentity"]="alice@remote.test"
r=delivery~deliverLocal(sess,msg,env~recipients,"INBOX")
call assert r~ok,"inbound durable delivery"
objectId=r~value
call assert cat~get(objectId)<>.nil,"catalogued object"
call assert cat~get(objectId)~availableLocations[1]~countsAsDurable,"verified durable location"
call assert stream(tmp||"/objects/"||objectId||".eml","c","query exists")<>"","message bytes stored"

/* Replay of the same in-memory message must not duplicate message bytes. */
r2=store~persist(sess,msg,"INBOUND")
call assert r2~ok & r2~value=objectId,"storage replay returns same object"

/* Outbound: one message object plus spool projection, no relay dispatch yet. */
env2=.SmtpEnvelope~new("alice@example.test"); env2~addRecipient("carol@outside.test")
msg2=.SmtpMessage~new(env2,"signed outbound")
sess2=.SmtpSession~new("s-out","127.0.0.1","alice@example.test",.true,.true)
sig2=.SmtpMessageSignatureEvidence~new(.true,.true,"alice@example.test","cert-2","smime/cms","verified")
r3=delivery~relaySigned(sess2,msg2,env2~recipients,sig2)
call assert r3~ok & r3~code="SPOOLED_DURABLE","outbound durable spool"
call assert stream(tmp||"/spool.tsv","c","query exists")<>"","spool ledger exists"
call assert cat~count=2,"exactly two message objects"

/* QueueRexx publisher contract: persistent, security-domain-bound transport. */
channels=.TestChannels~new
pub=.SmtpQueueRexxPublisher~new(channels,"REMOTE.ALIAS","SMTP.CHANNEL","smtp-service")
q=pub~publish("spool-1",objectId,"alice@example.test")
call assert q~ok,"queue publisher success"
call assert channels~lastOptions["persistent"]=.true,"queue message persistent"
call assert channels~lastOptions["securityDomain"]=.SmtpQueueContract~SECURITY_DOMAIN,"queue security domain"
call assert channels~lastPayload["schema"]="smtp.relay.request/1","queue schema"

say "test_durable_delivery: PASS"
exit 0

assert:
  use arg condition,label
  if \condition then do
    say "FAIL:" label
    exit 1
  end
return

::class TestResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg okArg=.true,codeArg="OK",detailArg=""
  ok=okArg; code=codeArg; detail=detailArg

::class TestChannels public
::attribute lastPayload get
::attribute lastOptions get
::method put
  expose lastPayload lastOptions
  use strict arg alias,payload,options,principal
  lastPayload=payload; lastOptions=options
  return .TestResult~new(.true)
::method pump
  use strict arg channel,limit,principal
  return .TestResult~new(.true)

::requires "SmtpCore.cls"
::requires "SmtpDurableDelivery.cls"
::requires "SmtpQueueRexxDispatch.cls"
::requires "StorageFabric.cls"
