parse arg port goodBridge badBridge
if port='' | goodBridge='' | badBridge='' then raise syntax 88.900 array('port goodBridge badBridge required')
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
sig='e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'||,
    'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
hkey='0b'~copies(20)
hmac='87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde'||,
     'daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854'

/* Preferred in-process provider wins over the lower TCP implementation. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(goodBridge,b,1000)
tcp=.RuntimeTcpJsonProvider~new('python.crypto.reference','127.0.0.1',port+0,2,8388608,'')
b~register('crypto.ed25519.sign/1',.RuntimeImplementationReference~new(tcp,100,.true,1,1))
call assertEqual sig,.Ed25519~sign('',seed),'foreign preferred Ed25519'
call assertEqual 'foreign.openssl.crypto',b~lastEvidence~providerId,'foreign preferred provider'
installed['target']~close

/* Broken foreign provider falls through to healthy TCP for an existing op. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(badBridge,b,1000)
tcp=.RuntimeTcpJsonProvider~new('python.crypto.reference','127.0.0.1',port+0,2,8388608,'')
b~register('crypto.ed25519.sign/1',.RuntimeImplementationReference~new(tcp,100,.true,1,1))
call assertEqual sig,.Ed25519~sign('',seed),'TCP after foreign outage Ed25519'
call assertEqual 'python.crypto.reference',b~lastEvidence~providerId,'TCP after foreign outage provider'
call assertEqual 'COMPLETED',b~lastEvidence~outcomeCode,'TCP after foreign outage completion'
installed['target']~close

/* Broken foreign provider with no lower HMAC provider falls to native ooRexx. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(badBridge,b,1000)
call assertEqual hmac,.HMACSHA512~digest(hkey,'Hi There'),'native HMAC after foreign outage'
call assertTrue b~lastEvidence~fallbackAllowed,'native HMAC fallback evidence allows fallback'
call assertTrue b~lastEvidence~outcomeCode \= 'COMPLETED','native HMAC fallback evidence records failed reference'
installed['target']~close

.CryptoLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'PASS Foreign Runtime -> TCP -> native expensive crypto failover chain'
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
