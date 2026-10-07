call main
exit 0

main:
  offers=.XtpDev17SocketOfferProvider~new
  a=.SocketAddresses~xtp('MCG',.true,'xtp.dev17.multicast')
  offers~register('fabric.group','xtp17-group',a,10,'REMOTE',.true,'libxtp dev17 multicast stream qualified')
  n=.SocketNegotiator~new
  n~registerOfferProvider(offers)
  req=.SocketNegotiationRequest~new('fabric.group',.SocketRole~SENDER,.true,.false,.true)
  s=n~negotiate(req)
  call assert s~selected,'dev17 stream+multicast request selected'
  call assert s~offer~capabilities~stream,'dev17 stream capability'
  call assert s~offer~capabilities~multicast,'dev17 multicast capability'
  call assert s~address==a,'dev17 exact XTP group address retained'
  call assert .SocketCapabilityProfiles~xtpDev14Rexx~multicast=.false,'historical dev14 remains false'
  say 'PASS XTP dev17 capability truth and historical profile isolation'
  return

assert: procedure
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::requires '../src/SocketProvider.cls'
::requires '../src/SocketIntentions.cls'
