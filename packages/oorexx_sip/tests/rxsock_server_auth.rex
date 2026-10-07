s = .SipServer~new('127.0.0.1', 5098, 'test-realm')
rc=s~credential('1001','secret')
say 'READY' s~port
do 2
  e=s~poll(5)
  say 'TYPE' e[1]
end
s~close
::requires 'sip.cls'
