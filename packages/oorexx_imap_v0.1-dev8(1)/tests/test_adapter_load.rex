c = .ImapSocketTransportConfig~new
c~host = "imap.example.invalid"
c~mode = "PLAIN"
call assert c~validate == c, "transport config validates without TLS bridge in PLAIN mode"
say "PASS test_adapter_load"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapApiTlsTransport.cls"
