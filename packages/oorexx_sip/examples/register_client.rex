#!/usr/bin/env rexx
use arg registrar = "sip:127.0.0.1:5060", aor = "sip:1001@127.0.0.1", password = ""
client = .SipClient~new("127.0.0.1", 0)
contact = "sip:1001@127.0.0.1:" || client~port
status = client~register(registrar, aor, contact, "1001", password, 3600, 3000)
say "REGISTER status:" status

::requires "sip.cls"
