parse arg port goodBridge badBridge
if port='' | goodBridge='' | badBridge='' then raise syntax 88.900 array('port goodBridge badBridge required')
expected256='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
expected512='ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'

/* Preferred in-process Foreign Runtime beats a healthy TCP provider. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(goodBridge,b,1000)
tcp=.RuntimeTcpJsonProvider~new('python.crypto.reference','127.0.0.1',port+0,2,8388608,'')
b~register('crypto.sha256.digest/1',.RuntimeImplementationReference~new(tcp,100,.true,1,1))
call assertEqual expected256,.SHA256~new('abc')~digest,'foreign preferred value'
call assertEqual 'foreign.openssl.crypto',b~lastEvidence~providerId,'foreign preferred provider'
installed['target']~close

/* Broken Foreign Runtime falls through to healthy TCP for the same operation. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(badBridge,b,1000)
tcp=.RuntimeTcpJsonProvider~new('python.crypto.reference','127.0.0.1',port+0,2,8388608,'')
b~register('crypto.sha512.digest/1',.RuntimeImplementationReference~new(tcp,100,.true,1,1))
call assertEqual expected512,.SHA512~new('abc')~digest,'TCP after foreign outage value'
call assertEqual 'python.crypto.reference',b~lastEvidence~providerId,'TCP after foreign outage provider'
call assertEqual 'COMPLETED',b~lastEvidence~outcomeCode,'TCP after foreign outage completion'
installed['target']~close

/* Broken Foreign Runtime with no lower reference leaves native as final fallback. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(badBridge,b,1000)
call assertEqual expected256,.SHA256~new('abc')~digest,'native after all references unavailable'
call assertTrue b~lastEvidence~fallbackAllowed,'native fallback evidence allows fallback'
call assertTrue b~lastEvidence~outcomeCode \= 'COMPLETED','native fallback evidence records failed reference'
installed['target']~close

.CryptoLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'PASS Foreign Runtime -> TCP -> native SHA failover chain'
exit 0
assertEqual: procedure
  use strict arg expected,actual,label
  if expected\=actual then raise syntax 88.900 array('FAILED '||label||' expected='||expected||' actual='||actual)
  return
assertTrue: procedure
  use strict arg value,label
  if \value then raise syntax 88.900 array('FAILED '||label)
  return
::requires 'CryptoForeignRuntimeProvider.cls'
::requires 'RuntimeTcpJsonProvider.cls'
