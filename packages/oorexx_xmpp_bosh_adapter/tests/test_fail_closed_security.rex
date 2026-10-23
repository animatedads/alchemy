parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
http=.OneShotHttp~new
bosh=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(730001))
transport=.XmppBoshTransport~new(bosh,.BoshEndpoint~new("http://example.test/http-bind","example.test"),.XmppBoshFixedSecurity~new(.false))
creds=.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret"))
s=.XmppSessionEngine~new(transport,"example.test",creds,"rexx")
call assertTrue s~connect,"unprotected BOSH transport can establish carrier"
s~pump
call assertEq .XmppSessionState~FAILED,s~state,"XMPP refuses SASL on unprotected BOSH carrier"
call assertEq "TLS_REQUIRED",s~failure~code,"fail-closed reason"
call assertEq 1,http~count,"credentials never submitted after protection refusal"
say "PASS XMPP/BOSH lower-security fail-closed qualification"
exit 0
assertTrue: procedure
  use strict arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  say "PASS" label; return
assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  say "PASS" label; return
::class OneShotHttp subclass BoshHttpExchangeProvider
::method init; expose count; count=0
::attribute count get
::method exchange
  expose count
  use strict arg uri,method,headers,body
  count+=1
  return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='U1'><stream:features xmlns:stream='http://etherx.jabber.org/streams'><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features></body>")
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
::requires "BoshTransport.cls"
::requires "XmppBoshTransport.cls"
