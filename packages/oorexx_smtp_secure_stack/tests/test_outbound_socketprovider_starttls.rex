root=value("TEST_ROOT",,"ENVIRONMENT")
if root="" then root="."
tmp=value("SMTP_TEST_TMP",,"ENVIRONMENT")
cert=value("SMTP_TEST_CA",,"ENVIRONMENT")
bridge=value("SMTP_TEST_BRIDGE",,"ENVIRONMENT")
if tmp="" | cert="" | bridge="" then do; say "missing SMTP_TEST_TMP/CA/BRIDGE"; exit 2; end
address system "rm -rf '"||tmp||"'"
call SysMkDir tmp
cat=.StorageCatalogue~new
store=.StorageFabricSmtpStore~new(tmp,cat,"smtp-test","smtp-test-domain",tmp||"/catalogue.tsv")
delivery=.StorageFabricSmtpDeliveryProvider~new(store,.array~of("example.test"))
svc=.SmtpService~new(.nil,.nil,.PermitAuthority~new,.AllowInspector~new,.nil,.AlwaysSignedVerifier~new,delivery,.CollectEvents~new)
sess=.SmtpSession~new("live-user","127.0.0.1","alice@example.test",.true,.true)
env=.SmtpEnvelope~new("<alice@example.test>"); env~addRecipient("<carol@outside.test>")
content="From: alice@example.test"||"0d0a"x||"To: carol@outside.test"||"0d0a"x||"Subject: socket provider dispatcher"||"0d0a"x||"0d0a"x||"hello from dev7 socket provider"||"0d0a"x
msg=.SmtpMessage~new(env,content)
q=svc~relayOutbound(sess,msg,env~recipients)
call assert q~ok,"spooled for live dispatch"
config=.SecureSocketClientConfig~new; config~bridgeDirectory=bridge; config~caFile=cert; config~verifyPeer=.true; config~readTimeout=10; config~writeTimeout=10
provider=.OpenSslSecureSocketClientProvider~new(config)
addresses=.RegisteredSocketAddressProvider~new
sockets=.SocketProvider~new(addresses)
sockets~registerBinding(.SocketTransportKind~TCP,.RxSockTcpBinding~new)
connector=.SmtpPlatformSocketConnector~new(sockets,"smtp.relay")
relay=.RxSockStartTlsSmtpRelayTransport~new(provider,connector)
resolver=.StaticSmtpNextHopResolver~new(.SmtpNextHop~new("localhost",25254,"smtp-client.test",.true))
d=.SmtpOutboundDispatcher~new(svc,store,resolver,relay)
r=d~dispatch(q~value)
provider~close
if \r~ok then say "LIVE RESULT" r~code r~detail
call assert r~ok & r~code="DELIVERED","live dispatcher delivered"
sr=store~loadSpool(q~value); call assert sr~ok & sr~value~state=.SmtpSpoolState~DELIVERED,"durable delivered state"
states=store~recipientStates(q~value,env~recipients)
call assert states["<carol@outside.test>"]["state"]=.SmtpSpoolState~DELIVERED,"recipient durable delivered state"
say "test_outbound_socketprovider_starttls: PASS"
exit 0
assert:
  use arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
return
::class PermitAuthority subclass SmtpAccessAuthority public
::method authorize
  use strict arg session,action,resource,message=.nil
  if action="EMAIL_SEND" then return .SmtpResult~success("permit","PERMIT")
  return .SmtpResult~failure("DENY")
::class AlwaysSignedVerifier subclass SmtpMessageSignatureVerifier public
::method inspect
  use strict arg message,expectedIdentity=""
  identity="alice@example.test"; if expectedIdentity<>"" then identity=expectedIdentity
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.true,.true,identity,"cert-live","smime/cms","verified"),"SIGNED")
::class AllowInspector subclass SmtpPolicyInspector public
::method inspect
  use strict arg direction,session,message,context=.nil
  return .SmtpInspection~new(direction,"allow","",0)
::class CollectEvents subclass SmtpEventSink public
::method emit; use strict arg event; return .true
::requires "SmtpCore.cls"
::requires "SmtpDurableDelivery.cls"
::requires "SmtpOutboundDispatcher.cls"
::requires "SecureSocketOpenSslClient.cls"
::requires "StorageFabric.cls"

::requires "SocketProvider.cls"
::requires "RxSockSocketBinding.cls"
