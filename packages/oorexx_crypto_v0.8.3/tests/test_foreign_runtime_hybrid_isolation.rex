parse arg directBridge compatBridge badBridge
if directBridge='' then directBridge='../native/openssl_direct.bridge.json'
if compatBridge='' then compatBridge='../native/openssl_compat.bridge.json'
if badBridge='' then badBridge='../native/does-not-exist.bridge.json'

/* Direct libcrypto remains fully usable when the compatibility shim is absent. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(directBridge,b,1000,'foreign.openssl.crypto',badBridge)
call assertEq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',.SHA256~new('abc')~digest,'direct SHA without compat'
call assertCompleted b,'crypto.sha256.digest/1'
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
sig='e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'||,
    'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
call assertEq sig,.Ed25519~sign('',seed),'direct Ed25519 without compat'
call assertCompleted b,'crypto.ed25519.sign/1'
kp=.RSA~keypair(61,53,17)
call assertEq 3233,kp['n'],'direct RSA without compat'
call assertCompleted b,'crypto.rsa.keypair/1'
/* A compat-only operation safely falls to native when its tiny shim is absent. */
.CryptoLibraryBuild~referenceSwitch=.nil
native=.X25519~publicKey(12345678901234567890)
.CryptoLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch
actual=.X25519~publicKey(12345678901234567890)
call assertEq native,actual,'compat missing native fallback value'
call assertTrue b~lastEvidence~fallbackAllowed,'compat missing fallback allowed'
call assertTrue b~lastEvidence~outcomeCode\='COMPLETED','compat missing not falsely completed'
installed['target']~close

/* Conversely, the compat library remains usable if direct libcrypto metadata is broken. */
b=.RuntimeImplementationBroker~new
installed=.CryptoForeignRuntimeInstaller~install(badBridge,b,1000,'foreign.openssl.crypto',compatBridge)
actual=.X25519~publicKey(12345678901234567890)
call assertEq native,actual,'compat survives direct outage'
call assertCompleted b,'crypto.x25519.public_key/1'
/* Direct-only SHA falls safely to native. */
call assertEq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',.SHA256~new('abc')~digest,'direct missing native SHA fallback'
call assertTrue b~lastEvidence~fallbackAllowed,'direct missing fallback allowed'
installed['target']~close

.CryptoLibraryBuild~referenceSwitch=.nil
.RuntimeImplementationSwitch~reset
say 'PASS hybrid direct-libcrypto / compatibility-shim isolation'
exit 0

assertCompleted: procedure
  use arg b,op
  e=b~lastEvidence
  if e~outcomeCode\='COMPLETED' then raise syntax 88.900 array(op||' not completed: '||e~outcomeCode||' '||e~detail)
  if e~providerId\='foreign.openssl.crypto' then raise syntax 88.900 array(op||' wrong provider')
  if e~operationId\=op then raise syntax 88.900 array(op||' wrong operation evidence')
  return
assertEq: procedure; use arg e,a,l; if e\==a then raise syntax 88.900 array(l||' expected='||e||' actual='||a); return
assertTrue: procedure; use arg v,l; if \v then raise syntax 88.900 array(l); return
::requires 'CryptoForeignRuntimeProvider.cls'
