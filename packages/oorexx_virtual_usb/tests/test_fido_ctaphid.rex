parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
auth=.Fido2Authenticator~new(device)
ignored=device~present
host=.FidoTestHost~new(provider)
cid=host~allocate
call ok cid<>.CtapHid~BROADCAST_CID,'allocated private CID'
payload=''
do i=1 to 140; payload=payload||d2c(i//251); end
response=host~send(cid,.CtapHid~PING,payload)
call ok response<>.nil,'PING response'
call ok response~command=.CtapHid~PING,'PING command echoed'
call ok response~payload=payload,'multi-packet PING payload echoed'
/* Typical HID class SET_IDLE should be accepted by semantic control handler. */
r=provider~hostControl(.UsbControlRequest~new(x2d('21'),x2d('0A'),0,0,0))
call ok r~handled & \r~stall,'HID SET_IDLE accepted'
say 'VIRTUAL USB FIDO CTAPHID: OK'
exit 0
ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'FidoTestHost.cls'
