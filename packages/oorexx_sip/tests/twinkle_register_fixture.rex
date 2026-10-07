crlf = '0d0a'x
msg = 'REGISTER sip:127.0.0.1 SIP/2.0' || crlf ||,
      'Via: SIP/2.0/UDP 127.0.0.1:5071;rport;branch=z9hG4bKhwyqiuci' || crlf ||,
      'Max-Forwards: 70' || crlf ||,
      'To: "Twinkle qualification" <sip:1001@127.0.0.1>' || crlf ||,
      'From: "Twinkle qualification" <sip:1001@127.0.0.1>;tag=rowyk' || crlf ||,
      'Call-ID: twinkle-fixture@localhost' || crlf ||,
      'CSeq: 53 REGISTER' || crlf ||,
      'Contact: <sip:1001@127.0.0.1:5071;transport=udp>;expires=300' || crlf ||,
      'Allow: INVITE,ACK,BYE,CANCEL,OPTIONS,PRACK,REFER,NOTIFY,SUBSCRIBE,INFO,MESSAGE' || crlf ||,
      'User-Agent: Twinkle/1.10.3' || crlf ||,
      'Content-Length: 0' || crlf || crlf
engine = sip_engine_open('127.0.0.1', 'oorexx-sip', 'SHA-256')
event = sip_engine_process(engine, msg, '127.0.0.1', 5071)
say 'TYPE' event[1]
say 'USER' event[4]
say 'CONTACT' event[6]
say 'PEER' event[7] event[8]
say 'EXPIRES' event[9]
response = event[2]
say 'STATUS' sip_message_status(response)
say 'VIA' sip_message_header(response, 'Via')
say 'RESPONSE_CONTACT' sip_message_header(response, 'Contact')
call sip_engine_close engine
if event[1] <> 'registered' then exit 10
if event[9] <> '300' then exit 11
if pos('rport=5071', sip_message_header(response, 'Via')) = 0 then exit 12
if pos('received=127.0.0.1', sip_message_header(response, 'Via')) = 0 then exit 13
exit 0
::requires '../src/sip.cls'
