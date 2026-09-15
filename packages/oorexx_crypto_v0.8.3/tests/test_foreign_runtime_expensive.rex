/* Whole-operation Foreign Runtime equivalence for expensive crypto calls. */
parse arg bridge
if bridge = "" then bridge = "../native/openssl_direct.bridge.json"

seed = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
pub = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
sig = "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555" ||,
      "fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
key = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
nonce = "000000000000004a00000000"
plain = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
hkey = "0b"~copies(20)
expectedHmac = "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde" ||,
               "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854"
ed448Seed = "01"~copies(57)
ed448Pub = "5332021a37b156ea08885fd0aeeddba432fb3923c393ba6504d0754b8f034191ac2fbcc8240875079ab2987ba6d183e88f0eec3d8def188d80"
ed448Scalar = 31548807214439121961266040181326279182185975769149097750215897435876822809016

/* Native canonical values for custom/non-standard arithmetic boundaries. */
.CryptoLibraryBuild~referenceSwitch = .nil
nativeCha = .ChaCha20~encrypt(plain,key,nonce)
nativeHmac = .HMACSHA512~digest(hkey,"Hi There")
alice = 123456789012345678901234567890
bob = 98765432109876543210987654321
nativeAlicePublic = .X25519~publicKey(alice)
nativeBobPublic = .X25519~publicKey(bob)
nativeSecret = .X25519~sharedSecret(alice,nativeBobPublic)
G = .Ed25519~G
nativeAdd = G~add(G)
nativeMul = G~multiply(123456789)

installed=.CryptoForeignRuntimeInstaller~install(bridge)
broker=installed["broker"]

kp255=.Ed25519~keypair(seed)
call assertEq pub,kp255["public"],"Ed25519 keypair"
call assertCompleted broker,"crypto.ed25519.keypair/1"
call assertEq sig,.Ed25519~sign("",seed),"Ed25519 sign"
call assertCompleted broker,"crypto.ed25519.sign/1"
call assertTrue .Ed25519~verify("",sig,pub),"Ed25519 verify true"
call assertCompleted broker,"crypto.ed25519.verify/1"
call assertFalse .Ed25519~verify("x",sig,pub),"Ed25519 verify false"
call assertCompleted broker,"crypto.ed25519.verify/1"

kp448=.Ed448~keypair(ed448Seed)
call assertEq ed448Pub,kp448["public"],"Ed448 keypair public"
call assertEq ed448Scalar,kp448["scalar"],"Ed448 keypair scalar"
call assertCompleted broker,"crypto.ed448.keypair/1"

call assertEq nativeCha,.ChaCha20~encrypt(plain,key,nonce),"ChaCha20 foreign equivalence"
call assertCompleted broker,"crypto.chacha20.crypt/1"
call assertEq nativeHmac,.HMACSHA512~digest(hkey,"Hi There"),"HMAC foreign equivalence"
call assertEq expectedHmac,nativeHmac,"HMAC known answer"
call assertCompleted broker,"crypto.hmac.sha512.digest/1"

call assertEq nativeAlicePublic,.X25519~publicKey(alice),"X25519 public foreign equivalence"
call assertCompleted broker,"crypto.x25519.public_key/1"
call assertEq nativeSecret,.X25519~sharedSecret(alice,nativeBobPublic),"X25519 secret foreign equivalence"
call assertCompleted broker,"crypto.x25519.shared_secret/1"

actualAdd=G~add(G)
call assertEq nativeAdd~x,actualAdd~x,"Edwards add x"
call assertEq nativeAdd~y,actualAdd~y,"Edwards add y"
call assertCompleted broker,"crypto.edwards25519.add/1"
actualMul=G~multiply(123456789)
call assertEq nativeMul~x,actualMul~x,"Edwards multiply x"
call assertEq nativeMul~y,actualMul~y,"Edwards multiply y"
call assertCompleted broker,"crypto.edwards25519.multiply/1"

kp=.RSA~keypair(61,53,17)
call assertEq 3233,kp["n"],"RSA n"
call assertCompleted broker,"crypto.rsa.keypair/1"
rs=.RSA~sign(65,kp["d"],kp["n"])
call assertCompleted broker,"crypto.rsa.sign/1"
call assertEq 65,.RSA~verify(rs,kp["e"],kp["n"]),"RSA verify"
call assertCompleted broker,"crypto.rsa.verify/1"
kp2=.RSA~keypair(3557,2579,17)
enc=.RSA~encrypt("A",kp2["e"],kp2["n"])
call assertCompleted broker,"crypto.rsa.encrypt/1"
call assertEq "A",.RSA~decrypt(enc,kp2["d"],kp2["n"]),"RSA decrypt"
call assertCompleted broker,"crypto.rsa.decrypt/1"

/* The expensive generation path must really be foreign and produce a usable 2048-bit key. */
big=.RSA~generateKeypair
call assertCompleted broker,"crypto.rsa.generate_keypair/1"
m=123456789
bigSig=.RSA~sign(m,big["d"],big["n"])
call assertCompleted broker,"crypto.rsa.sign/1"
call assertEq m,.RSA~verify(bigSig,big["e"],big["n"]),"RSA-2048 sign/verify"
call assertCompleted broker,"crypto.rsa.verify/1"
text="foreign runtime rocket skates"
bigCipher=.RSA~encrypt(text,big["e"],big["n"])
call assertCompleted broker,"crypto.rsa.encrypt/1"
call assertEq text,.RSA~decrypt(bigCipher,big["d"],big["n"]),"RSA-2048 encrypt/decrypt"
call assertCompleted broker,"crypto.rsa.decrypt/1"

installed["target"]~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch=.nil
say "PASS Foreign Runtime expensive crypto equivalence"
exit 0

assertCompleted: procedure
  use arg b,op
  e=b~lastEvidence
  if e~outcomeCode \= "COMPLETED" then raise syntax 88.900 array(op||" not completed: "||e~outcomeCode||" "||e~detail)
  if e~providerId \= "foreign.openssl.crypto" then raise syntax 88.900 array(op||" wrong provider: "||e~providerId)
  if e~operationId \= op then raise syntax 88.900 array(op||" wrong evidence operation: "||e~operationId)
  return
assertEq: procedure; use arg e,a,l; if e \== a then raise syntax 88.900 array(l||" expected="||e||" actual="||a); return
assertTrue: procedure; use arg v,l; if \v then raise syntax 88.900 array(l); return
assertFalse: procedure; use arg v,l; if v then raise syntax 88.900 array(l); return
::requires "CryptoForeignRuntimeProvider.cls"
