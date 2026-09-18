parse arg port principal keyHex holdSeconds
if holdSeconds == "" then holdSeconds = 0.80
client = .TerminalBrokerLocalSocketClient~new(port, principal, "k1", keyHex, 262144, .nil, .nil, .nil, 30000)
connected = client~connect
if \connected~ok then do; say "CONNECT_FAIL" principal connected~code; exit 31; end
say "SERVICE_AUTH_CLIENT_OK" principal
/* Keep two independently authenticated client processes resident at once.
 * Deliberately do not perform authenticated BYE here: v0.16 already exercises
 * BYE/BYE_ACK.  Exiting lets UNINIT raw-close the socket so this regression
 * isolates v0.17 concurrent worker lifetime without doubling the expensive
 * pure-ooRexx SHA-512 shutdown work in the debug interpreter. */
call SysSleep holdSeconds
exit 0
::requires "TerminalBrokerSocket.cls"
