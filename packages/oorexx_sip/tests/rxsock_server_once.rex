s = .SipServer~new('127.0.0.1', 5097, 'test-realm')
say 'READY' s~port
e = s~poll(5)
say 'TYPE' e[1]
do i=2 to e~items; say 'ARG' i e[i]; end
s~close
::requires 'sip.cls'
