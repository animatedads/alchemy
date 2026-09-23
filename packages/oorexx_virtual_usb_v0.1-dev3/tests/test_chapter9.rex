def=.UsbDeviceDefinition~new(.UsbDeviceDescriptor~new(x2d('CAFE'),x2d('4001')))
def~string(1,'Maker')~string(2,'Board Prototype')~string(3,'ABC123')
cfg=.UsbConfigurationDefinition~new
cfg~addInterface(.UsbInterfaceDefinition~new('control',0,255,0,0))
def~addConfiguration(cfg)
p=.VirtualUsbMemoryProvider~new
d=.VirtualUsbDevice~new('usb:test',def,p)
ignored=d~present

call ok def~descriptor(1,0)~length=18,'device descriptor'
call ok def~descriptor(2,0)~length=18,'config + one interface descriptor'
s=def~descriptor(3,2)
call ok c2d(s~left(1))=2+('Board Prototype'~length*2),'string descriptor length'
call ok c2d(s~substr(2,1))=3,'string descriptor type'

setup=.UsbControlRequest~new(x2d('80'),6,x2d('0200'),0,255)~encode
round=.UsbControlRequest~fromBytes(setup)
call ok round~request=6 & round~value=x2d('0200'),'setup packet little-endian roundtrip'

r=p~hostControl(.UsbControlRequest~new(x2d('80'),6,x2d('0200'),0,255))
call ok \r~stall & r~data~length=18,'GET_DESCRIPTOR configuration'
r=p~hostControl(.UsbControlRequest~new(x2d('80'),6,x2d('9900'),0,8))
call ok r~stall,'unknown descriptor stalls'

say 'VIRTUAL USB CHAPTER9: OK'
exit 0
ok: procedure
 use arg condition,label
 if \condition then do; say 'FAIL:' label; exit 1; end
 return
::requires 'VirtualUsbRuntime.cls'
