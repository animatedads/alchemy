parse arg bridge
if bridge='' then bridge='../native/openssl_direct.bridge.json'
installed=.CryptoForeignRuntimeInstaller~install(bridge)
broker=installed['broker']
/* Generate the expensive RSA fixture through the accelerator; the same key is then used for native/reference timing. */
rsa=.RSA~generateKeypair
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
pub='d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
sig='e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'||,
    'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
ed448Seed='01'~copies(57)
alice=123456789012345678901234567890
bob=98765432109876543210987654321
bobPub=.X25519~publicKey(bob)
hkey='0b'~copies(20)
hmsg=copies('H',1024)
ckey='000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'
nonce='000000000000004a00000000'
cdata=copies('rocket-skates-'||'00ff'x,256)
G=.Ed25519~G
scalar=2**250+123456789
m=123456789
cipher=.RSA~encrypt('rocket',rsa['e'],rsa['n'])

/* Native one-shot baselines. */
.CryptoLibraryBuild~referenceSwitch=.nil
call timerReset
x=.Ed25519~keypair(seed); nEdKey=timerMs()
call timerReset
x=.Ed25519~sign('',seed); nEdSign=timerMs()
call timerReset
x=.Ed25519~verify('',sig,pub); nEdVerify=timerMs()
call timerReset
x=.X25519~sharedSecret(alice,bobPub); nX=timerMs()
call timerReset
x=.Ed448~keypair(ed448Seed); nEd448=timerMs()
call timerReset
x=G~multiply(scalar); nMul=timerMs()
call timerReset
x=.HMACSHA512~digest(hkey,hmsg); nHmac=timerMs()
call timerReset
x=.ChaCha20~crypt(cdata,ckey,nonce); nCha=timerMs()
call timerReset
x=.RSA~sign(m,rsa['d'],rsa['n']); nRsaSign=timerMs()
call timerReset
x=.RSA~decrypt(cipher,rsa['d'],rsa['n']); nRsaDec=timerMs()

/* Foreign averages, 5 iterations. */
.CryptoLibraryBuild~referenceSwitch=.RuntimeImplementationSwitch
loops=5
fEdKey=0;fEdSign=0;fEdVerify=0;fX=0;fEd448=0;fMul=0;fHmac=0;fCha=0;fRsaSign=0;fRsaDec=0
do i=1 to loops
  call timerReset; x=.Ed25519~keypair(seed); fEdKey+=timerMs()
  call timerReset; x=.Ed25519~sign('',seed); fEdSign+=timerMs()
  call timerReset; x=.Ed25519~verify('',sig,pub); fEdVerify+=timerMs()
  call timerReset; x=.X25519~sharedSecret(alice,bobPub); fX+=timerMs()
  call timerReset; x=.Ed448~keypair(ed448Seed); fEd448+=timerMs()
  call timerReset; x=G~multiply(scalar); fMul+=timerMs()
  call timerReset; x=.HMACSHA512~digest(hkey,hmsg); fHmac+=timerMs()
  call timerReset; x=.ChaCha20~crypt(cdata,ckey,nonce); fCha+=timerMs()
  call timerReset; x=.RSA~sign(m,rsa['d'],rsa['n']); fRsaSign+=timerMs()
  call timerReset; x=.RSA~decrypt(cipher,rsa['d'],rsa['n']); fRsaDec+=timerMs()
end
fEdKey/=loops;fEdSign/=loops;fEdVerify/=loops;fX/=loops;fEd448/=loops;fMul/=loops;fHmac/=loops;fCha/=loops;fRsaSign/=loops;fRsaDec/=loops
say 'operation|native_ms|foreign_ms|speedup'
call row 'Ed25519 keypair',nEdKey,fEdKey
call row 'Ed25519 sign',nEdSign,fEdSign
call row 'Ed25519 verify',nEdVerify,fEdVerify
call row 'X25519 sharedSecret',nX,fX
call row 'Ed448 keypair',nEd448,fEd448
call row 'EdwardsPoint multiply',nMul,fMul
call row 'HMAC-SHA-512 1KiB',nHmac,fHmac
call row 'ChaCha20 payload',nCha,fCha
call row 'RSA-2048 private sign',nRsaSign,fRsaSign
call row 'RSA-2048 private decrypt',nRsaDec,fRsaDec
say 'provider=' broker~lastEvidence~providerId 'outcome=' broker~lastEvidence~outcomeCode
installed['target']~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch=.nil
exit 0

timerReset: procedure
  call time 'R'; return
timerMs: procedure
  return time('E')*1000
row: procedure
  use arg name,native,foreign
  say name'|'format(native,,3)'|'format(foreign,,3)'|'format(native/foreign,,2)'x'
  return
::requires 'CryptoForeignRuntimeProvider.cls'
