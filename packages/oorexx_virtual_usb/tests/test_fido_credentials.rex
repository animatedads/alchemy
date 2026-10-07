parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
auth=.Fido2Authenticator~new(device)
listener=.Listener~new
auth~on(.Fido2Events~CREDENTIAL_CREATED,listener,'created','SYNC')
auth~on(.Fido2Events~ASSERTION_CREATED,listener,'asserted','SYNC')
ignored=device~present
host=.FidoTestHost~new(provider)
cid=host~allocate
clientHash=x2c(.SHA256~new('client-data')~digest)
userId='USER-0001'
make=.CborMap~new
make~putInt(1,.CborBytes~new(clientHash))
rp=.CborMap~new; rp~putText('id',.CborText~new('example.test')); rp~putText('name',.CborText~new('Example Test')); make~putInt(2,rp)
user=.CborMap~new; user~putText('id',.CborBytes~new(userId)); user~putText('name',.CborText~new('dev-user')); user~putText('displayName',.CborText~new('Development User')); make~putInt(3,user)
param=.CborMap~new; param~putText('type',.CborText~new('public-key')); param~putText('alg',-8); make~putInt(4,.array~of(param))
opts=.CborMap~new; opts~putText('rk',.CborBool~new(.true)); make~putInt(7,opts)
makePayload=host~cbor(cid,.Ctap2~MAKE_CREDENTIAL,make)
call ok c2d(makePayload~left(1))=.Ctap2~OK,'MakeCredential status'
makeResponse=.CborCodec~decode(makePayload~substr(2))
call ok makeResponse~getInt(1)~text='none','development none attestation'
call ok listener~createdCount=1,'credential-created event'
cred=auth~store~credentials[1]
call ok cred~rpId='example.test','credential RP identity'
call ok cred~discoverable,'discoverable credential stored'
assertReq=.CborMap~new
assertReq~putInt(1,.CborText~new('example.test'))
assertReq~putInt(2,.CborBytes~new(clientHash))
desc=.CborMap~new; desc~putText('type',.CborText~new('public-key')); desc~putText('id',.CborBytes~new(cred~credentialId)); assertReq~putInt(3,.array~of(desc))
assertPayload=host~cbor(cid,.Ctap2~GET_ASSERTION,assertReq)
call ok c2d(assertPayload~left(1))=.Ctap2~OK,'GetAssertion status'
assertResponse=.CborCodec~decode(assertPayload~substr(2))
authData=assertResponse~getInt(2)~bytes
signature=assertResponse~getInt(3)~bytes
call ok .Ed25519~verify(authData||clientHash,c2x(signature),cred~publicKeyHex),'assertion Ed25519 signature verifies'
call ok cred~signCount=1,'signature counter advanced'
call ok listener~assertedCount=1,'assertion-created event'
say 'VIRTUAL USB FIDO CTAP2 CREDENTIALS: OK'
exit 0
ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::class Listener
::attribute createdCount get
::attribute assertedCount get
::method init
  expose createdCount assertedCount
  createdCount=0; assertedCount=0
::method created
  expose createdCount
  use strict arg event
  createdCount+=1
::method asserted
  expose assertedCount
  use strict arg event
  assertedCount+=1
::requires 'FidoTestHost.cls'
