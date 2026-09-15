parse arg bridge
if bridge='' then bridge='../native/openssl_direct.bridge.json'
installed=.CryptoForeignRuntimeInstaller~install(bridge)
b=installed['broker']
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
pub='d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
sig='e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'||,
    'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
ed448Seed='01'~copies(57)
alice=123456789012345678901234567890
bob=98765432109876543210987654321
bobPub=.X25519~publicKey(bob)
hkey='0b'~copies(20); hmsg=copies('H',4096)
ckey='000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'; nonce='000000000000004a00000000'; cdata=copies('rocket-skates-'||'00ff'x,4096)
G=.Ed25519~G; scalar=2**250+123456789
call time 'R'; rsa=.RSA~generateKeypair; say 'RSA-2048 keygen|'format(time('E')*1000,,3)'|ms'; call check b,'crypto.rsa.generate_keypair/1'
m=123456789; cipher=.RSA~encrypt('rocket',rsa['e'],rsa['n'])
loops=10
call bench 'Ed25519 keypair',loops,'EDKEY'
call bench 'Ed25519 sign',loops,'EDSIGN'
call bench 'Ed25519 verify',loops,'EDVERIFY'
call bench 'X25519 sharedSecret',loops,'XSHARED'
call bench 'Ed448 keypair',loops,'ED448'
call bench 'EdwardsPoint multiply',loops,'EDMUL'
call bench 'HMAC-SHA-512 4KiB',loops,'HMAC'
call bench 'ChaCha20 ~64KiB',loops,'CHACHA'
call bench 'RSA-2048 private sign',loops,'RSASIGN'
call bench 'RSA-2048 private decrypt',loops,'RSADEC'
installed['target']~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch=.nil
exit 0

bench: procedure expose seed pub sig ed448Seed alice bobPub hkey hmsg ckey nonce cdata G scalar rsa m cipher b
  use arg name,loops,kind
  call time 'R'
  do i=1 to loops
    select
      when kind='EDKEY' then x=.Ed25519~keypair(seed)
      when kind='EDSIGN' then x=.Ed25519~sign('',seed)
      when kind='EDVERIFY' then x=.Ed25519~verify('',sig,pub)
      when kind='XSHARED' then x=.X25519~sharedSecret(alice,bobPub)
      when kind='ED448' then x=.Ed448~keypair(ed448Seed)
      when kind='EDMUL' then x=G~multiply(scalar)
      when kind='HMAC' then x=.HMACSHA512~digest(hkey,hmsg)
      when kind='CHACHA' then x=.ChaCha20~crypt(cdata,ckey,nonce)
      when kind='RSASIGN' then x=.RSA~sign(m,rsa['d'],rsa['n'])
      when kind='RSADEC' then x=.RSA~decrypt(cipher,rsa['d'],rsa['n'])
      otherwise raise syntax 88.900 array('unknown benchmark')
    end
  end
  ms=time('E')*1000/loops
  say name'|'format(ms,,3)'|ms avg'
  if b~lastEvidence~outcomeCode\='COMPLETED' | b~lastEvidence~providerId\='foreign.openssl.crypto' then raise syntax 88.900 array(name||' did not complete foreign')
  return
check: procedure; use arg b,op; if b~lastEvidence~outcomeCode\='COMPLETED'|b~lastEvidence~operationId\=op then raise syntax 88.900 array(op||' evidence failed'); return
::requires 'CryptoForeignRuntimeProvider.cls'
