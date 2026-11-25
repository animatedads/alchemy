/* Architecture: Tom Dyer. Coding: ChatGPT. Explicit local operator tool. */
parse arg action extra
if extra\=='' | \.Array~of('status','on','off')~hasItem(action~lower) then do
  say 'Usage: audit-switch.rex status|on|off'; exit 2
end
scope=.Log~internalScope('LOCAL-AUDIT-CONTROL')
service=.LogService~new('audit-switch')
/* Local console target renders accepted structured objects immediately. The
   deployment host may inject its own authorized LogService in AuditSwitch. */
service~addTarget(.AuditConsoleTarget~new('console',scope))
service~addRule(.LogRule~new('audit-control','audit','AuditSwitch','run',scope,scope,.Log~INFO,.nil,.Array~of('console')))
r=.AuditSwitch~new(.POSIXProvider~new,service,scope)~run(action)
if \r['OK'] then do; say 'FAILED:' r['REASON']; exit 1; end
exit 0
::class AuditConsoleTarget subclass LogMemoryTarget
::method accept
  use strict arg event
  if \self~accept:super(event) then return .false
  p=event~payload
  say 'LOG' p['KIND'] 'action='p['ACTION']
  return .true
::requires 'AuditSwitch.cls'
::requires 'LoggingCore.cls'
