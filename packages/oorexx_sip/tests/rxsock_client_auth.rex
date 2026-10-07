c=.SipClient~new('127.0.0.1',0)
rc=c~register('sip:127.0.0.1:5098','sip:1001@127.0.0.1','sip:1001@127.0.0.1:'||c~port,'1001','secret',300,3)
say 'STATUS' rc
c~close
::requires 'sip.cls'
