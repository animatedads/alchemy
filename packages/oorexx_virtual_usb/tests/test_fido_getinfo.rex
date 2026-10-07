parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
auth=.Fido2Authenticator~new(device)
ignored=device~present
host=.FidoTestHost~new(provider)
cid=host~allocate
payload=host~cbor(cid,.Ctap2~GET_INFO)
call ok c2d(payload~left(1))=.Ctap2~OK,'GetInfo status'
info=.CborCodec~decode(payload~substr(2))
versions=info~getInt(1)
call ok versions[1]~text='FIDO_2_0','GetInfo version'
call ok info~getInt(3)~bytes~length=16,'GetInfo AAGUID'
call ok info~getInt(9)[1]~text='usb','GetInfo transport USB'
algs=info~getInt(10)
call ok algs[1]~getText('alg')=-8,'GetInfo advertises EdDSA'
call ok info~getInt(4)~getText('rk')~value,'GetInfo resident/discoverable support'
say 'VIRTUAL USB FIDO CTAP2 GETINFO: OK'
exit 0
ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'FidoTestHost.cls'
