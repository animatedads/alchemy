/* Real-environment TN3270/TN3270E qualification probe.
 *
 * Usage:
 *   rexx tools/hercules_tn3270_probe.rex HOST [PORT] [TIMEOUT]
 *
 * This is observation-only: it opens a terminal connection, completes Telnet
 * negotiation, waits for the first 3270 presentation-space generation, prints
 * negotiated mode/device facts and the 24x80 screen, then closes.  It sends no
 * AID and stages no operator input. */
parse arg host port timeout
host=host~strip
if host=="" then do
  say 'usage: rexx tools/hercules_tn3270_probe.rex HOST [PORT] [TIMEOUT]'
  exit 2
end
if port~strip=="" then port=3270
if timeout~strip=="" then timeout=15

transport=.TcpTerminalTransport~new(host,port)
profile=.TN3270TelnetProfile~new("IBM-3278-2-E")
wire=.TN3270Wire~new(.nil,profile)
session=.TN3270LiveSession~new(transport,wire)

r=session~open
if \r~ok then do
  say 'FAIL OPEN code='r~code 'detail='r~detail
  exit 3
end

r=session~pumpUntilGeneration(0,timeout)
if \r~ok then do
  say 'FAIL FIRST_SCREEN code='r~code 'detail='r~detail
  dummy=session~close
  exit 4
end

say 'PASS FIRST_SCREEN generation='wire~model~generation
if profile~tn3270eActive then mode='TN3270E_BASIC'; else mode='TN3270'
say 'MODE='mode
say 'TERMINAL_TYPE='profile~terminalType
say 'DEVICE_ACCEPTED='profile~deviceAccepted
say 'DEVICE_NAME='profile~deviceName
say 'FUNCTIONS_ACCEPTED='profile~functionsAccepted
say 'ROWS='wire~model~rows 'COLUMNS='wire~model~columns
say '--- SCREEN BEGIN ---'
say wire~model~text(wire~stream~codepage)
say '--- SCREEN END ---'

c=session~close
if \c~ok then do
  say 'FAIL CLOSE code='c~code 'detail='c~detail
  exit 5
end
say 'PASS CLOSE'
exit 0

::requires "TN3270LiveSession.cls"
