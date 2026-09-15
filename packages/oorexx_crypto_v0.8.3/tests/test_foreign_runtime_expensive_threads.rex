/* Shared-provider concurrency stress for the expensive foreign crypto paths. */
parse arg bridge
if bridge = "" then bridge = "../native/openssl_direct.bridge.json"
installed=.CryptoForeignRuntimeInstaller~install(bridge)
broker=installed["broker"]

seed="9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
pub="d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
sig="e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555"||,
    "fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
hkey="0b"~copies(20)
hmac="87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde"||,
     "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854"
key="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
nonce="000000000000004a00000000"
data=copies("threaded-crypto-"||'00ff'x,256)
cipher=.ChaCha20~crypt(data,key,nonce)
rsa=.RSA~generateKeypair
messageInt=42424242

threads=8
loops=20
workers=.Array~new;messages=.Array~new
do i=1 to threads
  w=.CryptoExpensiveThreadWorker~new(seed,pub,sig,hkey,hmac,key,nonce,data,cipher,rsa,messageInt,loops)
  workers~append(w);messages~append(w~start("run"))
end
do i=1 to threads
  if messages[i]~result \= 1 then raise syntax 88.900 array("foreign crypto worker failed "||i)
end

e=broker~lastEvidence
if e~outcomeCode \= "COMPLETED" | e~providerId \= "foreign.openssl.crypto" then raise syntax 88.900 array("invalid concurrent evidence")
installed["target"]~close
.RuntimeImplementationSwitch~reset
.CryptoLibraryBuild~referenceSwitch=.nil
say "PASS thread-safe Foreign Runtime expensive crypto"
exit 0

::class CryptoExpensiveThreadWorker
::method init
  expose seed pub sig hkey hmac key nonce data cipher rsa messageInt loops
  use strict arg seed,pub,sig,hkey,hmac,key,nonce,data,cipher,rsa,messageInt,loops
::method run
  expose seed pub sig hkey hmac key nonce data cipher rsa messageInt loops
  do i=1 to loops
    if .Ed25519~sign("",seed) \= sig then return 0
    if \.Ed25519~verify("",sig,pub) then return 0
    if .HMACSHA512~digest(hkey,"Hi There") \= hmac then return 0
    if .ChaCha20~crypt(data,key,nonce) \= cipher then return 0
    s=.RSA~sign(messageInt,rsa["d"],rsa["n"])
    if .RSA~verify(s,rsa["e"],rsa["n"]) \= messageInt then return 0
  end
  return 1

::requires "CryptoForeignRuntimeProvider.cls"
