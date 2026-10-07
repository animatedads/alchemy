call main
exit 0

main:
  offers=.XtpDev14SocketOfferProvider~new
  offers~register('fabric.current','xtp14',.SocketAddresses~xtp('peer:ed209d'),10,'REMOTE',.true,'XTP dev14 current route')
  offers~register('fabric.group','xtp14-group',.SocketAddresses~xtp('group:future',.true),10,'REMOTE',.true,'group identity retained; native multicast absent')
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)

  sender=.SocketNegotiationRequest~new('fabric.current',.SocketRole~SENDER,.true,.false,.false)
  s=n~negotiate(sender)
  call assert s~selected,'dev14 sender remains available'
  call assert s~offer~capabilities~listener,'dev14 listener remains available'
  call assert \s~offer~capabilities~multicast,'dev14 multicast is not overclaimed'

  group=.SocketNegotiationRequest~new('fabric.group',.SocketRole~SENDER,.true,.false,.true)
  g=n~negotiate(group)
  call assert g~status=.SocketNegotiationStatus~NO_OFFER,'dev14 multicast request fails closed'
  call assert g~rejected[1]['reason']='MULTICAST_REQUIRED','dev14 current implementation capability is authoritative'
  say 'PASS XTP dev14 capability truth'
  return

assert: procedure
  use strict arg ok, why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::requires '../src/SocketProvider.cls'
::requires '../src/SocketIntentions.cls'
