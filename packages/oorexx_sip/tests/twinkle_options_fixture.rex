crlf = '0d0a'x
msg = 'OPTIONS sip:1001@127.0.0.1 SIP/2.0' || crlf ||,
      'Via: SIP/2.0/UDP 127.0.0.1:5071;rport;branch=z9hG4bKoptions' || crlf ||,
      'Max-Forwards: 70' || crlf ||,
      'To: <sip:1001@127.0.0.1>' || crlf ||,
      'From: <sip:probe@127.0.0.1>;tag=probe' || crlf ||,
      'Call-ID: options-fixture@localhost' || crlf ||,
      'CSeq: 1 OPTIONS' || crlf ||,
      'Content-Length: 0' || crlf || crlf
engine = sip_engine_open('127.0.0.1', 'oorexx-sip', 'SHA-256')
event = sip_engine_process(engine, msg, '127.0.0.1', 5071)
response = event[2]
say 'TYPE' event[1]
say 'STATUS' sip_message_status(response)
say 'ALLOW' sip_message_header(response, 'Allow')
say 'VIA' sip_message_header(response, 'Via')
call sip_engine_close engine
if event[1] <> 'options' then exit 20
if sip_message_status(response) <> 200 then exit 21
if pos('rport=5071', sip_message_header(response, 'Via')) = 0 then exit 22
exit 0
::requires '../src/sip.cls'
