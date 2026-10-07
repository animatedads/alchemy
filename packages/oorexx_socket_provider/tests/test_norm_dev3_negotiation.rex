call main
exit 0

main:
  address=.SocketAddresses~norm('239.255.42.63',47063,'lo','',1,'norm.dev3')
  offers=.NormDev3SocketOfferProvider~new
  offers~register('norm.dev3','norm3',address,10,'REMOTE',.true,'NORM dev3 descriptor-ready provider')
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)
  req=.SocketNegotiationRequest~new('norm.dev3',.SocketRole~LISTENER,.false,.false,.true)
  selected=n~negotiate(req)
  call assert selected~selected,'NORM dev3 multicast listener selected'
  call assert selected~address==address,'NORM dev3 exact address identity retained'
  call assert selected~offer~capabilities~multicast,'NORM dev3 multicast capability retained'
  call assert \selected~offer~capabilities~stream,'NORM dev3 remains non-stream'
  say 'PASS NORM dev3 negotiation projection'
  return

assert: procedure
  use strict arg ok, why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::requires '../src/SocketProvider.cls'
::requires '../src/SocketIntentions.cls'
