/* Development-only virtual FIDO2 authenticator demonstration. */
parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
auth=.Fido2Authenticator~new(device)
observer=.AuthenticatorObserver~new
auth~on(.Fido2Events~CHANNEL_ALLOCATED,observer,'channelAllocated','SYNC')
auth~on(.Fido2Events~CREDENTIAL_CREATED,observer,'credentialCreated','SYNC')
auth~on(.Fido2Events~ASSERTION_CREATED,observer,'assertionCreated','SYNC')
ignored=device~present
host=.FidoTestHost~new(provider)
cid=host~allocate
infoPayload=host~cbor(cid,.Ctap2~GET_INFO)
info=.CborCodec~decode(infoPayload~substr(2))
say 'FIDO2 version:' info~getInt(1)[1]~text
say 'Transport:' info~getInt(9)[1]~text
say 'Algorithm:' info~getInt(10)[1]~getText('alg')
exit 0
::class AuthenticatorObserver
::method channelAllocated
  use strict arg event
  say 'CTAPHID channel allocated:' event~data
::method credentialCreated
  use strict arg event
  say 'Credential created for:' event~data~rpId
::method assertionCreated
  use strict arg event
  say 'Assertion signed for:' event~data~rpId
::requires 'FidoTestHost.cls'
