parse source . . me
root=filespec('location',me)||'..'
profile=.UsbDeviceProfileLoader~loadFile(root||'/maps/virtual_fido2_authenticator.json')
call ok profile~schema='oorexx.virtual.usb.device/0.3','profile schema /0.3'
intf=profile~definition~configuration(1)~interface(0)
call ok intf~interfaceClass=3,'HID interface class'
call ok intf~endpoint('hidIn')~transferType='INTERRUPT','HID IN interrupt endpoint'
call ok intf~endpoint('hidOut')~address=x2d('01'),'HID OUT endpoint'
report=intf~descriptor(x2d('22'),0)
call ok report~length=34,'FIDO HID report descriptor length'
call ok c2x(report~left(5))='06D0F10901','FIDO usage page and usage'
config=profile~definition~configuration(1)~encode
call ok pos('092111010001222200'x,config)>0,'HID descriptor embedded in configuration'
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~fromProfile(profile,provider)
ignored=device~present
r=provider~hostControl(.UsbControlRequest~new(x2d('81'),6,x2d('2200'),0,255))
call ok r~handled & \r~stall,'GET_DESCRIPTOR report handled'
call ok r~data=report,'GET_DESCRIPTOR returns report descriptor'
say 'VIRTUAL USB FIDO HID PROFILE: OK'
exit 0
ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
::requires 'VirtualUsbRuntime.cls'
