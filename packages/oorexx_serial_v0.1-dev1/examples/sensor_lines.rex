/* Application code: no termios, no pollfd, no ioctl numbers. */
provider=.SerialMemoryProvider~new
serial=.SerialRuntime~new(provider)
port=serial~open('sensor-board',.SerialConfiguration~new(115200))
frames=port~framed(.SerialLineFramer~new)
frames~on('FRAME',.Telemetry~new,'packet')
provider~inject('sensor-board','TEMP:22.5'||'0D0A'x||'HUM:55.2'||'0D0A'x)
ignored=port~poll
port~close
exit
::class Telemetry
::method packet
  use strict arg event
  say 'Sensor frame:' event~data~bytes
::requires 'SerialFraming.cls'
