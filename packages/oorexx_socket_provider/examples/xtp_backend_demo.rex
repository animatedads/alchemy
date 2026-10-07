a=.RegisteredSocketAddressProvider~new
a~register("fabric.control",.SocketAddresses~xtp("02:AA:BB:CC:DD:EE"))
a~register("fabric.discovery",.SocketAddresses~xtp("group:rexxos-discovery",.true))
p=.SocketProvider~new(a)
p~registerBinding("XTP",.RexxXtpSocketBinding~new(.ExampleXtpBackend~new))
say p~sender("fabric.control")
say p~listener("fabric.discovery",64)
exit 0
::class ExampleXtpBackend
::method sender
  use strict arg address
  return "XTP sender ->" address~xtpAddress
::method listener
  use strict arg address, backlog=32
  return "XTP listener ->" address~xtpAddress "multicast="address~multicast "backlog="backlog
::requires "../src/SocketProvider.cls"
