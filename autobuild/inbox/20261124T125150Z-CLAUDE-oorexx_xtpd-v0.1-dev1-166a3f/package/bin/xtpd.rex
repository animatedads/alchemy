/* xtpd.rex -- start the XTP network service daemon.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
 * Usage: rexx xtpd.rex /etc/xtpd/xtpd.conf
 * Stops cleanly on SIGTERM or SIGINT (HALT): listeners closed, the request
 * socket removed, every peerage withdrawn from the firewall set. */
parse arg confPath
confPath = confPath~strip
if confPath == '' then do
  .error~lineout('usage: rexx xtpd.rex CONFIG')
  exit 2
end
signal on halt
signal on syntax name failed
daemon = .Xtpd~new(confPath)
daemon~run
do forever
  call SysSleep 0.5
  daemon~housekeep
end
halt:
  daemon~stop
  exit 0
failed:
  c = condition('O')
  .error~lineout('[xtpd] FATAL' c['CODE'] c['ERRORTEXT'] c['ADDITIONAL']~makeString)
  if symbol('daemon') == 'VAR' then daemon~stop
  exit 1
::requires 'Xtpd.cls'
