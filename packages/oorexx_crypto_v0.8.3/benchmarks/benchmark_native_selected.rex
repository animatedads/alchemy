.CryptoLibraryBuild~referenceSwitch=.nil
seed='9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
pub='d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
sig='e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555'||,
    'fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
alice=123456789012345678901234567890;bob=98765432109876543210987654321;bobPub=.X25519~publicKey(bob)
G=.Ed25519~G; scalar=2**250+123456789
hkey='0b'~copies(20);hmsg=copies('H',4096)
ckey='000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';nonce='000000000000004a00000000';cdata=copies('rocket-skates-'||'00ff'x,256)
call one 'Ed25519 keypair','EDKEY'
call one 'Ed25519 sign','EDSIGN'
call one 'Ed25519 verify','EDVERIFY'
call one 'X25519 sharedSecret','XSHARED'
call one 'EdwardsPoint multiply','EDMUL'
call one 'HMAC-SHA-512 4KiB','HMAC'
call one 'ChaCha20 ~4KiB','CHACHA'
exit 0
one: procedure expose seed pub sig alice bobPub G scalar hkey hmsg ckey nonce cdata
  use arg name,kind
  call time 'R'
  select
    when kind='EDKEY' then x=.Ed25519~keypair(seed)
    when kind='EDSIGN' then x=.Ed25519~sign('',seed)
    when kind='EDVERIFY' then x=.Ed25519~verify('',sig,pub)
    when kind='XSHARED' then x=.X25519~sharedSecret(alice,bobPub)
    when kind='EDMUL' then x=G~multiply(scalar)
    when kind='HMAC' then x=.HMACSHA512~digest(hkey,hmsg)
    when kind='CHACHA' then x=.ChaCha20~crypt(cdata,ckey,nonce)
    otherwise raise syntax 88.900 array('unknown')
  end
  say name'|'format(time('E')*1000,,3)'|ms'
  return
::requires 'crypto.cls'
