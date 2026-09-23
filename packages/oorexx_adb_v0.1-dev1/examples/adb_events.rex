
transport=.AdbMemoryTransport~new
auth=.nil
phone=.AdbSession~new(transport,auth,'adb:demo-phone')
observer=.DemoObserver~new
phone~on(.AdbEvents~CONNECTED,observer,'connected')
phone~connect
transport~enqueuePacket(.AdbPacket~new('CNXN',.AdbProtocol~VERSION,.AdbProtocol~MAX_PAYLOAD,'device::ro.product.model=Example;features=shell_v2;'),.false)
phone~pump

::class DemoObserver
::method connected
  use strict arg event
  phone=event~data
  say 'Connected device model:' phone~banner~property('ro.product.model','unknown')

::requires "AdbRuntime.cls"
