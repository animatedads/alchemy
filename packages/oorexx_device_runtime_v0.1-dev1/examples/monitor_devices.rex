/* Print Linux device changes and fire a trigger when a USB device is added. */
provider=.LinuxUdevProvider~new
monitor=.DeviceMonitor~new(provider,'LOCAL-DEVICE-MONITOR')
monitor~eventBus~subscribe(.Printer~new)
usbAdd=.DeviceEventFilter~new(.array~of('ADD'),'USB')
monitor~eventBus~registerTrigger(.DeviceTrigger~new('USB-ARRIVAL',.UsbArrivalAction~new,usbAdd))

say 'Known USB devices:' monitor~enumerate('usb')~items
say 'Monitoring udev. Ctrl+C to stop.'
monitor~start
do forever
  event=monitor~poll(5000)
end

::class Printer public
::method onDeviceEvent
  use arg event
  say event~string

::class UsbArrivalAction public
::method onDeviceTrigger
  use arg trigger,event
  say 'TRIGGER' trigger~triggerId ':' event~device~string

::requires 'LinuxUdevProvider.cls'
