call main
exit 0

main:
  offers=.XtpDev12SocketOfferProvider~new
  offers~register('fabric.current','xtp12',.SocketAddresses~xtp('peer:ed209d'),10,'REMOTE',.true,'XTP dev12 path-health/multipath route')
  offers~register('fabric.group','xtp12-group',.SocketAddresses~xtp('group:future',.true),10,'REMOTE',.true,'address form retained but native multicast outside executable profile')
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)

  sender=.SocketNegotiationRequest~new('fabric.current',.SocketRole~SENDER,.true,.false,.false)
  s=n~negotiate(sender)
  call assert s~selected,'dev12 sender remains available'
  call assert s~offer~capabilities~sender,'dev12 sender capability'
  call assert s~offer~capabilities~listener,'dev12 listener capability'
  call assert \s~offer~capabilities~multicast,'dev12 multicast is not overclaimed'

  group=.SocketNegotiationRequest~new('fabric.group',.SocketRole~SENDER,.true,.false,.true)
  g=n~negotiate(group)
  call assert g~status=.SocketNegotiationStatus~NO_OFFER,'dev12 multicast request fails closed'
  call assert g~rejected[1]['reason']='MULTICAST_REQUIRED','native implementation capability is authoritative'
  say 'PASS XTP dev12 capability truth: sender/listener yes, multicast not yet claimed'
  return

assert:
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::requires '../src/SocketProvider.cls'
::requires '../src/SocketIntentions.cls'
