/* Architecture: Tom Dyer. Coding: ChatGPT. */
parse arg path
numeric digits 25
scope=.Log~internalScope('MU-TEST')
svc=.LogService~new('kernel-test')
target=.KernelLogTarget~new('kernel',scope,'target-1',16)
svc~addTarget(target)
svc~addRule(.LogRule~new('kernel-observe','kernel','KernelLogBridge','publish',scope,scope,.Log~INFO,.nil,.Array~of('kernel')))
svc~addRule(.LogRule~new('pam-ingress','pam','KernelLogBridge','publishPam',scope,scope,.Log~INFO,.nil,.Array~of('kernel')))
pr=.ProcessProvider~new
snap=pr~observe(SysQueryProcess('PID'))~securitySnapshot
boot=snap['BOOT_ID']
bridge=.KernelLogBridge~new(svc,scope,'mu-test',boot,'run-1')
r=bridge~publish('proc','METRIC_RISE','rss',1,'{"RSS_KIB":123}')
call check r['OK'], 'logging real LogService delivery'
p=target~page('target-1',0)
e=p['EVENTS'][1]
call check e~isA(.LogEvent) & e~ruleId=='kernel-observe' & e~payload['DETAIL']['RSS_KIB']=123, 'logging structured original LogEvent payload'
call check e~payload['INGRESS_ID']==r['INGRESS_ID'] & e~sourceScopeId==scope~scopeId, 'logging scoped causal identity'
other=.KernelLogTarget~new('other',.Log~internalScope('MU-OTHER'),'g',2)
call check \other~accept(e), 'logging cross domain rejected'
call check badCursor(target), 'logging target incarnation refused'
-- Actual native filesystem observation is logged before plan dispatch.
rt=.ShellEventRuntime~new('log-fixture',.Owner~new)
rt~setObservationLogger(bridge)
root=.POSIXProvider~new~openRoot(path)['ROOT']; w=root~watch('.')['WATCH']; id=rt~attach('files',w)['REGISTRATION']
plan=rt~board~plan('review'); step=plan~step('echo'); step~does(.Workspace~new(path),'run',.Array~of('echo','LOG_OK')); step~passIf('outputHas','LOG_OK')
rule=rt~arm('file','files','FS_CLOSE_WRITE',plan,'x:'||'observed'~c2x)
f=.Stream~new(path'/observed'); f~charOut('x'); f~close
ignore=rt~pump(1000)
call check rule~state=='FIRED' & rt~board~jobs~makeArray~items=1, 'logging live kernel event drives governed job'
job=rt~board~jobs~makeArray[1]
do i=1 to 100; if job~settled then leave; call SysSleep .02; end
rt~collectJobs
call check job~state=='PASSED', 'logging governed job passed'
found=.nil
 do e over target~page('target-1',0)['EVENTS']; if e~payload['KIND']=='FS_CLOSE_WRITE' then found=e; end
call check found\==.nil, 'logging real inotify object retained'
matched=.false
 do x over rt~journal~replay(0)['EVENTS']; if x~kind=='FS_CLOSE_WRITE' & x~cause==found~payload['INGRESS_ID'] then matched=.true; end
call check matched, 'logging job observation has ingress reference'
created=.false
 do e over target~page('target-1',0)['EVENTS']; if e~payload['KIND']=='FS_CREATE' then created=.true; end
call check created, 'logging nontrigger kernel observation also retained'
-- Pull actual LogEvent PAM fixture through the existing normalizer (not live PAM).
rt~attachAudit('pam',.PamAuditAdapter~new(boot))
row=.Directory~new; row['BOOT_ID']=boot; row['ORIGIN']='PAM'; row['TYPE']='USER_AUTH'; row['SERIAL']='1'; row['EPOCH_MS']=snap['EPOCH_MS']; row['PID']=snap['PID']; row['UID']=snap['UID']; row['AUID']='UNSET'; row['SESSION']='UNSET'; row['RESULT']='failed'; row['PASSWORD']='not-for-logging'
old=bridge~publishPam(row)
consumer=.KernelPamLogConsumer~new(target,'pam-ingress','mu-test',boot,rt,'pam')
call check consumer~pull=0, 'logging consumer starts live tail without replay'
row['SERIAL']='2'; pamReceipt=bridge~publishPam(row)
call check pamReceipt['OK'] & consumer~pull=1, 'logging pulls structured PAM fixture'
call check consumer~pull=0, 'logging pull cursor prevents repeated ingestion'
found=.nil
 do x over rt~journal~replay(0)['EVENTS']; if x~kind=='PAM_AUTH_FAILURE' then found=x; end
call check found\==.nil & found~cause==pamReceipt['INGRESS_ID'], 'logging PAM event keeps original ingress id'
page=target~page('target-1',0); e=page['EVENTS'][page['EVENTS']~items]
call check \e~payload['RECORD']~hasIndex('PASSWORD'), 'logging PAM projection strips unapproved fields'
-- Mandatory delivery failure prevents trigger; loss disarms.
rule2=rt~arm('file2','files','FS_CLOSE_WRITE',plan,'x:'||'again'~c2x)
svc~disableRule('kernel-observe','test','owner')
f=.Stream~new(path'/again'); f~charOut('x'); f~close; ignore=rt~pump(1000)
call check rule2~state=='DISARMED' & rt~board~jobs~makeArray~items=1, 'logging disabled rule prevents event job'
svc~enableRule('kernel-observe','test','owner')
do i=1 to 20; ignore=bridge~publish('test','TIMER'); end
call check target~page('target-1',0)['GAP'], 'logging bounded cursor detects retention gap'
call check consumer~pull=0 & consumer~quarantined, 'logging PAM consumer quarantines gap'
rt~close; w~close; root~close
-- Direct kernel ABI decoder and actual kernel device probe.
decoder=.KernelPrintkDecoder~new
r=decoder~decode('14,123,987654,-;example message')
call check r['FACILITY']=1 & r['SEVERITY']=6 & r['KERNEL_SEQUENCE']=123, 'logging kernel ABI header decoded'
call check \r~hasIndex('MESSAGE_HEX'), 'logging printk defaults metadata only'
r=decoder~decode('6,124,999,-;hello',.true)
call check r['MESSAGE_HEX']=='68656C6C6F', 'logging explicit message byte projection'
call check badHeader(decoder), 'logging malformed kernel ABI rejected'
r=.POSIXProvider~new~openKernelLog
if r['OK'] then do
  k=r['KERNEL_LOG']; mux=.POSIXProvider~new~openEventMux['MUX']; r=mux~register(k)
  call check r['OK'], 'logging kernel device registers in epoll'
  k~close; mux~close
  say 'NOTE live printk data not induced; device registration only'
end
else do
  call check r['ERRNO']>0, 'logging kernel device unavailable explicitly'
  say 'SKIP live printk device:' r['ERRNO'] r['ERROR']
end
say 'KERNEL LOGGING SUITE PASSED'
exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::routine badCursor
 use strict arg target
 signal on syntax name failed
 x=target~page('wrong')
 return .false
failed:
 return .true
::routine badHeader
 use strict arg decoder
 signal on syntax name failed
 x=decoder~decode('invalid')
 return .false
failed:
 return .true
::class Owner
::method principal
 return 'llm'
::method kind
 return 'llm'
::method jobFinished
 use strict arg job
 return .true
::requires 'ShellSecurityObservation.cls'
::requires 'KernelLogging.cls'
