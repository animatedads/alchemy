/* Architecture: Tom Dyer. Coding: ChatGPT. No real state changes. */
numeric digits 25
p=.POSIXProvider~new
call check \p~auditSetEnabled(2)['OK'] & \p~auditSetEnabled('bad')['OK'], 'audit wrapper invalid/lock flag refused'
s=p~auditStatus
if s['OK'] then do
  call check s~hasIndex('ENABLED') & s~hasIndex('LOST') & s~hasIndex('PID'), 'audit status native read or explicit unavailable'
end
else do
  call check s['ERRNO']>0, 'audit status native read or explicit unavailable'
  say 'NOTE audit status unavailable errno='s['ERRNO']
end
r=p~openAuditReader
if r['OK'] then do
  reader=r['AUDIT_READER']; mux=p~openEventMux['MUX']; reg=mux~register(reader)
  ok=reg['OK']; reader~close; mux~close
  call check ok,'audit readlog native registration or explicit unavailable'
end
else do
  call check r['ERRNO']>0,'audit readlog native registration or explicit unavailable'
  say 'NOTE audit readlog unavailable errno='r['ERRNO']
end
boot=.ProcessProvider~new~observe(SysQueryProcess('PID'))~securitySnapshot['BOOT_ID']
d=.KernelAuditDecoder~new(boot)
line="audit(1780000000.123:42): pid=123 uid=0 auid=1000 ses=9 msg='op=PAM:session_open acct=private addr=private res=success'"
r=d~decodeNetlink(1105,line)
call check r['KIND']=='PAM' & \r['GAP'] & r['RECORD']['TYPE']=='USER_START','audit netlink numeric type drives PAM projection'
row=r['RECORD'];call check row~items=11 & \row~hasIndex('acct') & \row~hasIndex('addr') & row['AUID']=1000,'audit netlink approved fields only'
call check d~decodeNetlink(1100,line)['GAP'],'audit netlink type mismatch rejected'
call check d~decodeNetlink(1300,'audit(1780000000.123:43): example')['KIND']=='IGNORE','audit other record tracks serial without logging payload'
r=d~decodeNetlink(1105,changestr(':42)',line,':44)'));call check \r['GAP'],'audit other record prevents false serial gap'
r=d~decodeNetlink(1105,changestr(':42)',line,':46)'));call check r['GAP'] & r['KIND']=='PAM','audit netlink missing serial gap'
call check d~decodeNetlink(1105,'garbage')['GAP'],'audit malformed PAM record gap'
mon=.AuditLossMonitor~new;st=.Directory~new;st['OK']=1;st['LOST']=0;st['ENABLED']=1
call check \mon~observe(st)['GAP'],'audit loss monitor baseline'
st['LOST']=2;call check mon~observe(st)['GAP'] & \mon~observe(st)['GAP'],'audit lost rise once'
st['LOST']=1;call check mon~observe(st)['GAP'],'audit loss reset is gap'
st['ENABLED']=0;call check mon~observe(st)['GAP'],'audit disabled is gap'
st['OK']=0;call check mon~observe(st)['GAP'] & \mon~observe(st)['GAP'],'audit unavailable transition once'
st['OK']=1;st['ENABLED']=1;call check mon~observe(st)['GAP'],'audit status recovery preserves unknown interval'
-- Actual LogService and priority lane, controlled netlink fixture.
scope=.Log~internalScope('MU-AUDIT');svc=.LogService~new('audit-netlink');reg=.LogSubscriptions~new(svc,scope)
t=reg~register('pam','g','KernelLogBridge','PUBLISHPAM',.Array~of('USER_START','GAP'),'CRITICAL',8)
b=.KernelLogBridge~new(svc,scope,'mu',boot,'fixture');b~bindSubscriptions(reg)
rt=.ShellEventRuntime~new('audit-netlink-fixture',.Owner~new);rt~attachAudit('pam',.PamAuditAdapter~new(boot))
c=.KernelPamLogConsumer~new(t,t~ruleId,'mu',boot,rt,'pam')
receipt=b~publishPam(row)
call check receipt['OK'] & c~pull=1 & t~pending=0,'audit netlink fixture through actual LogService and PAM consumer'
rt~close
-- Switch uses injected fake provider, actual logging service.
svc=.LogService~new('switch');target=.LogMemoryTarget~new('test',scope);svc~addTarget(target)
svc~addRule(.LogRule~new('switch','audit','AuditSwitch','RUN',scope,scope,.Log~INFO,.nil,.Array~of('test')))
f=.FakeProvider~new;ctl=.AuditSwitch~new(f,svc,scope)
r=ctl~run('status');call check r['OK'] & f~calls=0 & target~count=2,'audit switch status logs before/after without SET'
r=ctl~run('on');call check r['OK'] & f~calls=1 & r['AFTER']['ENABLED']=1 & target~count=4,'audit switch on logs before/after and readback'
r=ctl~run('off');call check r['OK'] & f~calls=2 & r['AFTER']['ENABLED']=0 & target~count=6,'audit switch off readback with mock provider'
f~locked; r=ctl~run('off');call check \r['OK'] & f~calls=2 & target~count=8,'audit switch locked status refuses SET'
f~unlock;target~disable; r=ctl~run('off');call check \r['OK'] & f~calls=2,'audit switch unavailable request log refuses SET'
say 'AUDIT NETLINK SUITE PASSED';exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label; return
::class FakeProvider
::method init
 expose enabled calls
 enabled=0;calls=0
::attribute calls get
::method locked
 expose enabled
 enabled=2
::method unlock
 expose enabled
 enabled=1
::method auditStatus
 expose enabled
 r=.Directory~new;r['OK']=1;r['ENABLED']=enabled;r['ERROR']='';r['FAILURE']=0;r['PID']=0;r['BACKLOG_LIMIT']=64;r['LOST']=0;r['BACKLOG']=0;return r
::method auditSetEnabled
 expose enabled calls
 use strict arg flag
 enabled=flag;calls+=1;return self~auditStatus
::class Owner
::method principal
 return 'llm'
::method kind
 return 'llm'
::requires 'ShellSecurityObservation.cls'
::requires 'KernelLogging.cls'
::requires 'AuditSwitch.cls'
