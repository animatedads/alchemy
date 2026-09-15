parse arg host port keyHex
client = .ShannonSocketIngressClient~new(host, port, keyHex)
submitOperation = client~submit('Can I put my EpiPen in a 10 kg cabin bag that might be gate-checked and put in the hold?')
if \submitOperation~ok then do
  say 'CLIENT FAIL:' submitOperation~code submitOperation~detail
  exit 31
end
say 'CLIENT OK'
exit 0

::requires 'ShannonSocketGateway.cls'
