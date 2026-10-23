parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
http=.TranscriptHttp~new
bosh=.BoshStreamProvider~new(http,.BoshFixedRequestIdSource~new(720001))
endpoint=.BoshEndpoint~new("https://example.test/http-bind","example.test")
security=.XmppBoshFixedSecurity~new(.true)
transport=.XmppBoshTransport~new(bosh,endpoint,security)
creds=.StaticXmppCredentialsProvider~new(.XmppCredentials~new("alice","secret"))
s=.XmppSessionEngine~new(transport,"example.test",creds,"rexx")
call assertTrue s~connect,"XMPP engine connects through BOSH adapter"
call assertEq 1,http~count,"initial BOSH session only; literal client stream-open is not sent"
do i=1 to 4; s~pump; end
call assertEq .XmppSessionState~READY,s~state,"XMPP session reaches READY over BOSH"
call assertEq "alice@example.test/rexx",s~boundJid,"resource binding preserved"
call assertEq 4,http~count,"BOSH exchanges for open/auth/restart/bind"
call assertContains http~bodies[1],"xmlns:xmpp='urn:xmpp:xbosh'","XEP-0206 namespace on initial BOSH body"
call assertContains http~bodies[1],"xmpp:version='1.0'","XEP-0206 version on initial BOSH body"
call assertTrue pos("<stream:stream",http~bodies[1])=0,"literal stream-open absent from initial BOSH payload"
call assertContains http~bodies[2],"<auth ","SASL stanza carried as BOSH payload"
call assertTrue pos("secret",http~bodies[2])=0,"credential secret not exposed as clear XML"
call assertContains http~bodies[3],"xmpp:restart='true'","post-SASL restart projected onto BOSH body"
call assertTrue pos("<stream:stream",http~bodies[3])=0,"literal restarted stream-open absent from BOSH payload"
call assertContains http~bodies[4],"<iq type='set' id='bind-1'>","bind stanza carried over BOSH"
call assertTrue transport~secure,"security projected from lower HTTP/transport authority"
call assertTrue \transport~supportsStartTls,"XMPP STARTTLS not tunneled through BOSH"
call assertTrue s~close,"clean close terminates BOSH session"
call assertContains http~bodies[5],"type='terminate'","XMPP close maps to BOSH termination"
say "PASS XEP-0206 XMPP-over-BOSH adapter qualification"
exit 0
assertTrue: procedure
  use strict arg condition,label
  if \condition then do; say "FAIL:" label; exit 1; end
  say "PASS" label; return
assertEq: procedure
  use strict arg expected,actual,label
  if expected<>actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  say "PASS" label; return
assertContains: procedure
  use strict arg haystack,needle,label
  if pos(needle,haystack)=0 then do; say "FAIL:" label "missing="needle; exit 1; end
  say "PASS" label; return
::class TranscriptHttp subclass BoshHttpExchangeProvider
::method init
  expose count bodies
  count=0; bodies=.array~new
::attribute count get
::attribute bodies get
::method exchange
  expose count bodies
  use strict arg uri,method,headers,body
  count+=1; bodies~append(body)
  select
    when count=1 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' sid='XB1' xmpp:version='1.0' xmlns:xmpp='urn:xmpp:xbosh'><stream:features xmlns:stream='http://etherx.jabber.org/streams'><mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms></stream:features></body>")
    when count=2 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/></body>")
    when count=3 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><stream:features xmlns:stream='http://etherx.jabber.org/streams'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/></stream:features></body>")
    when count=4 then return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind'><iq type='result' id='bind-1'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><jid>alice@example.test/rexx</jid></bind></iq></body>")
    otherwise return .BoshHttpResponse~new(200,"<body xmlns='http://jabber.org/protocol/httpbind' type='terminate'/>")
  end
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
::requires "BoshTransport.cls"
::requires "XmppBoshTransport.cls"
