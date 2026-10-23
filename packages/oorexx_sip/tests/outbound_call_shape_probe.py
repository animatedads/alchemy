from pathlib import Path
s=Path(__file__).resolve().parents[1].joinpath('src/sip.cls').read_text()
required=[
 '::class SipClientDialog public',
 '::method invite',
 '::method receiveFinalResponse',
 '::method sdpConnectionAddress',
 'SIP.CLIENT.DIALOG.TERMINATED',
 'request="INVITE" requestUri "SIP/2.0"',
 'request="ACK" requestUri "SIP/2.0"',
 'request="BYE" requestUri "SIP/2.0"',
 'call=.SipCall~new(.nil,callId',
 'dialog=.SipClientDialog~new(',
 '::attribute dialog get'
]
missing=[x for x in required if x not in s]
if missing:
 print('FAIL outbound shape missing:',missing); raise SystemExit(1)
if 'startEverything' in s:
 print('FAIL monolithic lifecycle helper present'); raise SystemExit(1)
print('PASS outbound INVITE/ACK/BYE independent-dialog source shape')