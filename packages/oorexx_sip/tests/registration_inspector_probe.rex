call RxFuncAdd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs
service = .LogService~new('sip-registration-inspector')
mem = .LogMemoryTarget~new('memory', .Log~INTERNAL)
service~addTarget(mem)
sink = .SipAlchemyLogSink~new(service, .Log~INFO, .Log~INTERNAL)
server = .SipServer~new('127.0.0.1', 0, 'oorexx-sip', 'SHA-256', sink)
server~credential('1001', 'secret')
client = .SipUdpTransport~new('127.0.0.1', 0, sink)
registrar = 'sip:127.0.0.1'
aor = 'sip:1001@127.0.0.1'
contact = 'sip:1001@127.0.0.1:' || client~bindPort

req1 = registerRequest(registrar, aor, contact, client~bindPort, 1, '', 30)
sent = client~sendTo(req1, '127.0.0.1', server~port)
e1 = server~poll(2)
r1 = client~receive(2)
if e1[1] <> 'register-challenge' then do; say 'FAIL first' e1[1]; exit 1; end
if e1[5] <> 'missing-authorization' then do; say 'FAIL challenge reason' e1[5]; exit 2; end
challenge = sip_message_header(r1[1], 'WWW-Authenticate')

auth = sip_digest_authorization(challenge, '1001', 'secret', 'REGISTER', registrar)
req2 = registerRequest(registrar, aor, contact, client~bindPort, 2, auth, 30)
sent = client~sendTo(req2, '127.0.0.1', server~port)
e2 = server~poll(2)
r2 = client~receive(2)
if e2[1] <> 'registered' then do; say 'FAIL registered' e2[1]; exit 3; end

binding = server~registrationForUser('1001')
if binding == .nil then do; say 'FAIL no binding'; exit 4; end
say 'REGISTRATION' binding~registrationId binding~objectId binding~username binding~contact binding~peerAddress binding~peerPort binding~expires binding~expiresAt binding~revision
if binding~expires <> '30' then do; say 'FAIL expiry' binding~expires; exit 5; end
if server~activeRegistrations~items <> 1 then do; say 'FAIL active count'; exit 6; end
bindingId = binding~objectId
req3 = registerRequest(registrar, aor, contact, client~bindPort, 3, auth, 2)
sent = client~sendTo(req3, '127.0.0.1', server~port)
e3 = server~poll(2)
r3 = client~receive(2)
if e3[1] <> 'registered' then do; say 'FAIL refresh' e3[1]; exit 14; end
binding = server~registrationForUser('1001')
if binding == .nil then do; say 'FAIL refresh binding missing'; exit 15; end
if binding~objectId <> bindingId then do; say 'FAIL refresh identity changed'; exit 16; end
if binding~revision <> 2 then do; say 'FAIL refresh revision' binding~revision; exit 17; end
if binding~expires <> '2' then do; say 'FAIL refresh expiry' binding~expires; exit 18; end
say 'REFRESH' binding~registrationId binding~objectId 'revision='binding~revision 'expires='binding~expires

call SysSleep 3
active = server~activeRegistrations
if active~items <> 0 then do; say 'FAIL expired count' active~items; exit 7; end
if server~registrationForUser('1001') <> .nil then do; say 'FAIL expired lookup'; exit 8; end

seenExpired = 0
seenBound = 0
seenRefreshed = 0
seenReason = 0
previousByObject = .directory~new
do logEvent over mem~events
  p = logEvent~payload
  if \p~hasIndex('eventId') then do; say 'FAIL no eventId' p['eventType']; exit 9; end
  if \p~hasIndex('eventSequence') then do; say 'FAIL no sequence' p['eventType']; exit 10; end
  if \p~hasIndex('emittedAtMs') then do; say 'FAIL no timestamp' p['eventType']; exit 11; end
  oid = p['objectId']
  seq = p['eventSequence']
  if previousByObject~hasIndex(oid) then do
    if seq <= previousByObject[oid] then do; say 'FAIL non-monotonic sequence' oid seq; exit 12; end
  end
  previousByObject[oid] = seq
  if p['eventType'] = 'SIP.REGISTRATION.BOUND' then seenBound = 1
  if p['eventType'] = 'SIP.REGISTRATION.REFRESHED' then seenRefreshed = 1
  if p['eventType'] = 'SIP.REGISTRATION.EXPIRED' then seenExpired = 1
  if p['eventType'] = 'SIP.AUTH.CHALLENGE' then do
    if p['reason'] = 'missing-authorization' then seenReason = 1
  end
end
if \seenBound | \seenRefreshed | \seenExpired | \seenReason then do; say 'FAIL evidence' seenBound seenRefreshed seenExpired seenReason; exit 13; end
say 'PASS registration inspector bind-refresh-expiry-sequenced-evidence'
client~close
server~close
exit 0

registerRequest: procedure
  use strict arg registrar, aor, contact, localPort, cseq, auth, expires
  crlf = '0d0a'x
  r = 'REGISTER' registrar 'SIP/2.0' || crlf
  r ||= 'Via: SIP/2.0/UDP 127.0.0.1:' || localPort || ';branch=z9hG4bKinspect' || cseq || ';rport' || crlf
  r ||= 'Max-Forwards: 70' || crlf
  r ||= 'To: <' || aor || '>' || crlf
  r ||= 'From: <' || aor || '>;tag=inspect' || crlf
  r ||= 'Call-ID: inspector@localhost' || crlf
  r ||= 'CSeq:' cseq 'REGISTER' || crlf
  r ||= 'Contact: <' || contact || '>;expires=' || expires || crlf
  if auth <> '' then r ||= 'Authorization:' auth || crlf
  r ||= 'Content-Length: 0' || crlf || crlf
  return r

::requires 'sip.cls'
::requires 'sip_logging.cls'
