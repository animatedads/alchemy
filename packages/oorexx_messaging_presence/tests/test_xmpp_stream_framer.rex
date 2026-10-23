parse source . . here
base=filespec("L",here)
call value "REXX_PATH", base||"/../src:"||base||"/../providers/xmpp:"||value("REXX_PATH",,"ENVIRONMENT"), "ENVIRONMENT"
f=.XmppStreamFramer~new
frames=f~feed("<?xml version='1.0'?><stream:st")
call assertEq 0,frames~items,"partial stream open waits"
frames=f~feed("ream from='example.test' xmlns:stream='http://etherx.jabber.org/streams'><stream:features><starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'><required/></starttls></stream:features>")
call assertEq 2,frames~items,"stream open plus features"
call assertEq .XmppFrameKind~STREAM_OPEN,frames[1]~kind,"stream frame kind"
call assertEq .XmppFrameKind~ELEMENT,frames[2]~kind,"features frame kind"
frames=f~feed("<message from='bob@example.test' id='m1'><body>A &lt; B")
call assertEq 0,frames~items,"partial message waits"
frames=f~feed(" &amp; C</body><thread>t1</thread></message><presence from='bob@example.test'><show>dnd</show></presence>")
call assertEq 2,frames~items,"two complete stanzas"
call assertEq "A < B & C",.XmppXmlLite~elementText(frames[1]~xml,"body"),"entity decode"
frames=f~feed("</stream:stream>")
call assertEq .XmppFrameKind~STREAM_CLOSE,frames[1]~kind,"stream close kind"
say "PASS test_xmpp_stream_framer"; exit 0
assertEq: procedure; use arg e,a,l; if e==a then return; say "FAIL" l "expected="e "actual="a; exit 1
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "XmppSessionEngine.cls"
