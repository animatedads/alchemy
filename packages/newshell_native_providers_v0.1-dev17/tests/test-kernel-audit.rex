/* Architecture: Tom Dyer. Coding: ChatGPT. Synthetic printk ABI records, actual LogService. */
numeric digits 25
boot=.ProcessProvider~new~observe(SysQueryProcess('PID'))~securitySnapshot['BOOT_ID']
d=.KernelAuditDecoder~new(boot)
line="6,12,12345,-;audit: type=1105 audit(1780000000.123:42): pid=123 uid=0 auid=1000 ses=9 msg='op=PAM:session_open acct=private addr=private res=success'"
r=d~decode(line)
call check r['KIND']=='PAM' & \r['GAP'] & r['RECORD']['TYPE']=='USER_START','kernel audit numeric session record decoded'
call check \.KernelPrintkDecoder~new~decode(line,.true)~hasIndex('MESSAGE_HEX'),'kernel audit raw message excluded even with explicit text option'
row=r['RECORD']
call check row['SERIAL']=42 & row['EPOCH_MS']=1780000000123 & row['OPERATION']=='PAM:session_open','kernel audit structured projection'
call check \row~hasIndex('acct') & \row~hasIndex('addr') & row~items=11,'kernel audit drops unapproved fields'
call check .PamAuditAdapter~new(boot)~normalize(row)['KIND']=='PAM_SESSION_OPEN','kernel audit compatible normalized record'
call check d~decode(changestr('6,12',line,'14,12'))['KIND']=='IGNORE','kernel audit nonkernel facility ignored'
r=d~decode(changestr(':42)',line,':44)'));call check r['GAP'] & r['KIND']=='PAM','kernel audit serial gap reported and record retained'
call check d~decode('4,15,100,-;audit: audit_lost=7 audit_rate_limit=0')['GAP'],'kernel audit explicit kernel loss detected'
call check d~decode(changestr('PAM:session_open',line,'PAM:authentication'))['GAP'],'kernel audit type mismatch gap'
-- Actual generic priority LogService lane and PAM consumer, fixture input only.
scope=.Log~internalScope('MU-AUDIT');svc=.LogService~new('audit-test');reg=.LogSubscriptions~new(svc,scope)
t=reg~register('pam','g','KernelLogBridge','PUBLISHPAM',.Array~of('USER_START','GAP'),'CRITICAL',8)
b=.KernelLogBridge~new(svc,scope,'mu',boot,'fixture');b~bindSubscriptions(reg)
rt=.ShellEventRuntime~new('audit-pump',.Owner~new);rt~attachAudit('pam',.PamAuditAdapter~new(boot))
c=.KernelPamLogConsumer~new(t,t~ruleId,'mu',boot,rt,'pam')
receipt=b~publishPam(row)
call check receipt['OK'] & c~pull=1 & t~pending=0,'kernel audit priority PAM object consumed and acknowledged'
row['TYPE']='GAP';call check b~publishPam(row)['OK'] & c~pull=0 & c~quarantined,'kernel audit gap quarantines PAM consumer'
rt~close
say 'KERNEL AUDIT SUITE PASSED';exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label; return
::class Owner
::method principal
 return 'llm'
::method kind
 return 'llm'
::requires 'ShellSecurityObservation.cls'
::requires 'KernelLogging.cls'
