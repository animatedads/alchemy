def=.UsbDeviceDefinition~new(.UsbDeviceDescriptor~new(x2d('CAFE'),x2d('4010')))
cfg=.UsbConfigurationDefinition~new(1,'default')
cfg~addInterface(.UsbInterfaceDefinition~new('io',0,255,0,0))
def~addConfiguration(cfg)
provider=.VirtualUsbMemoryProvider~new
device=.VirtualUsbDevice~new('usb:config-state',def,provider)
ignored=device~present

set1=.UsbControlRequest~new(x2d('00'),9,1,0,0)
controlRc=device~handleControl(set1)
call ok controlRc~handled & controlRc~configureValue=1,'SET_CONFIGURATION is decoded as requested transition'
call ok device~configurationValue=0,'protocol decode alone does not claim observed configuration'

controlRc=provider~hostControl(set1)
call ok \controlRc~stall & device~configurationValue=1,'provider confirmation commits observed configuration'

bad=.UsbControlRequest~new(x2d('00'),9,7,0,0)
controlRc=provider~hostControl(bad)
call ok controlRc~stall,'unknown configuration stalls'
call ok device~configurationValue=1,'failed configuration request does not corrupt observed state'

zero=.UsbControlRequest~new(x2d('00'),9,0,0,0)
controlRc=provider~hostControl(zero)
call ok \controlRc~stall & device~configurationValue=0,'configuration zero returns to addressed/unconfigured state'

ignored=provider~hostControl(set1)
call ok device~configurationValue=1,'device can reconfigure'
device~_providerEvent('RESET')
call ok device~configurationValue=0,'bus reset clears observed configuration'

ignored=provider~hostControl(set1)
device~_providerEvent('DISCONNECT')
call ok device~configurationValue=0 & \device~connected,'disconnect clears configuration and connection state'

say 'VIRTUAL USB CONFIGURATION STATE: OK'
exit 0

ok: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return

::requires 'VirtualUsbRuntime.cls'
