parse arg port bridge caFile
if port = "" | bridge = "" | caFile = "" then do; say "usage test_starttls_transport.rex PORT BRIDGE CA"; exit 2; end
cfg = .ImapSocketTransportConfig~new
cfg~host = "localhost"; cfg~port = port + 0; cfg~security = "STARTTLS_REQUIRED"; cfg~bridgeDirectory = bridge; cfg~caFile = caFile; cfg~verifyPeer = .true
transport = .ImapSocketTransport~new(cfg)
call assert \transport~encrypted, "starts plaintext"
s = .ImapSession~new(transport)
boot = s~bootstrapSecurity("STARTTLS_REQUIRED")
call assert boot~ok, "STARTTLS bootstrap completed"
call assert transport~encrypted, "transport upgraded"
call assert \s~capabilities~has("STARTTLS"), "post-TLS capability snapshot replaced pre-TLS snapshot"
call assert s~capabilities~has("MOVE"), "post-TLS capabilities visible"
l = s~login("user", "pass"); call assert l~ok, "login after TLS"
s~logout; transport~close
say "PASS test_starttls_transport"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapApiTlsTransport.cls"
