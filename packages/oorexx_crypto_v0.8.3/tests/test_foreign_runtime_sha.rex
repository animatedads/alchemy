parse arg bridge
if bridge = '' then raise syntax 88.900 array('bridge path required')
installed=.CryptoForeignRuntimeInstaller~install(bridge)
payload='00610062ff00010203'x
expected256='6b7f2d24560b2fc85dfb3d33882e5b6b4e88608c88e04bcd2c4e6cde6fd75640'
expected512='d997031ce9d079463f8bc3cec222f08d1337a44df92557da8350a34848b7284c1a89571d8ca524d6c07da2d87ed09d1a6a0bb902e535f0e9145ef4989b9f416f'

v=.SHA256~new(payload)~digest
call assertEqual expected256,v,'foreign SHA-256 exact bytes'
e=.RuntimeImplementationSwitch~broker~lastEvidence
call assertEqual 'COMPLETED',e~outcomeCode,'foreign SHA-256 evidence'
call assertEqual 'foreign.openssl.crypto',e~providerId,'foreign SHA-256 provider'

v=.SHA512~new(payload)~digest
call assertEqual expected512,v,'foreign SHA-512 exact bytes'
e=.RuntimeImplementationSwitch~broker~lastEvidence
call assertEqual 'COMPLETED',e~outcomeCode,'foreign SHA-512 evidence'
call assertEqual 'foreign.openssl.crypto',e~providerId,'foreign SHA-512 provider'

/* Native remains the same final implementation when the switch is absent. */
.CryptoLibraryBuild~referenceSwitch=.nil
call assertEqual expected256,.SHA256~new(payload)~digest,'native SHA-256 remains correct'
call assertEqual expected512,.SHA512~new(payload)~digest,'native SHA-512 remains correct'

installed['target']~close
.RuntimeImplementationSwitch~reset
say 'PASS foreign runtime SHA-256/SHA-512 provider'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 88.900 array('FAILED: '||label||' expected='||expected||' actual='||actual)
  return

::requires 'CryptoForeignRuntimeProvider.cls'
