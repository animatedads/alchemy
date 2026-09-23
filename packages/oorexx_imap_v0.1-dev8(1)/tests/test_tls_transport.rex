parse arg port bridge caFile
if port = "" | bridge = "" | caFile = "" then do; say "usage test_tls_transport.rex PORT BRIDGE CA"; exit 2; end
cfg = .ImapSocketTransportConfig~new
cfg~host = "localhost"; cfg~port = port + 0; cfg~security = "IMPLICIT_TLS"; cfg~bridgeDirectory = bridge; cfg~caFile = caFile; cfg~verifyPeer = .true
transport = .ImapSocketTransport~new(cfg)
call assert transport~encrypted, "TLS active"
s = .ImapSession~new(transport)
s~acceptGreeting
call assert s~capabilities~has("MOVE"), "greeting capabilities over TLS"
c = s~capability; call assert c~ok, "capability over TLS"
l = s~login("user", "pass"); call assert l~ok, "login over TLS"
e = s~examine("INBOX"); call assert e~ok, "examine over TLS"
call assert s~selectedState~uidValidity = "99", "UIDVALIDITY over TLS"
st = s~status("INBOX"); call assert st~unseenCount = 42, "STATUS UNSEEN over TLS"
s~logout; transport~close
say "PASS test_tls_transport"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapApiTlsTransport.cls"
