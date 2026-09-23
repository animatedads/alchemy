call assert .ImapTransportSecurity~canonical("IMPLICIT_TLS") = "IMPLICIT_TLS", "implicit canonical"
call assert .ImapTransportSecurity~canonical("IMAPS") = "IMPLICIT_TLS", "IMAPS compatibility alias"
call assert .ImapTransportSecurity~canonical("STARTTLS") = "STARTTLS_REQUIRED", "STARTTLS compatibility alias"
call assert rejectAmbiguous("IMAP"), "bare IMAP rejected because it does not specify transport security"
call assert .ImapTransportSecurity~defaultPort("IMPLICIT_TLS") = 993, "implicit default port"
call assert .ImapTransportSecurity~defaultPort("STARTTLS_REQUIRED") = 143, "STARTTLS default port"
call assert .ImapTransportSecurity~defaultPort("PLAINTEXT") = 143, "plaintext default port"
call assert rejectAmbiguous("TLS"), "bare TLS rejected as ambiguous"
call assert rejectAmbiguous("SSL"), "bare SSL rejected as ambiguous"

e = .ImapEndpoint~new
e~host = "imap.example.test"
e~security = "IMAPS"
e~validate
call assert e~security = "IMPLICIT_TLS", "endpoint canonicalizes security"
call assert e~port = 993, "endpoint derives port from security"
call assert e~encryptedFromConnect, "endpoint implicit encrypted-from-connect"

s = .ImapEndpoint~new
s~host = "imap.example.test"
s~security = "STARTTLS_REQUIRED"
s~validate
call assert s~port = 143, "STARTTLS endpoint port"
call assert s~requiresStartTls, "STARTTLS endpoint requires upgrade"

say "PASS test_security_modes"
exit 0

rejectAmbiguous: procedure
  use strict arg label
  signal on syntax name caught
  ignored = .ImapTransportSecurity~canonical(label)
  signal off syntax
  return .false
caught:
  signal off syntax
  args = condition("A")
  return args[1] = "IMAP_AMBIGUOUS_SECURITY_LABEL"

assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapCore.cls"
