/* Architecture: Tom Dyer. Coding: ChatGPT. */
numeric digits 25
scope=.Log~internalScope('MU-PRIORITY')
svc=.LogService~new('priority-test')
reg=.LogSubscriptions~new(svc,scope,8)
critical=reg~register('auth','g1','KernelLogBridge','PUBLISHPAM',.Array~of('USER_AUTH'),'CRITICAL',2)
oper=reg~register('oper','g2','KernelLogBridge','PUBLISH',.Array~of('FS_CLOSE_WRITE'),'OPERATIONS',2)
diagnostic=reg~register('debug','g3','KernelLogBridge','PUBLISH',.Array~of('METRIC_RISE','TIMER'),'DIAGNOSTIC',2)
mirror=reg~register('mirror','g4','KernelLogBridge','PUBLISHPAM',.Array~of('USER_AUTH'),'DIAGNOSTIC',2)
call check svc~rulesSnapshot~items=4 & svc~targetsSnapshot~items=4, 'priority registrations create real LogService rules and targets'
call check overBudget(reg), 'priority aggregate capacity budget enforced'
-- Separate registry with spare capacity verifies collision rather than budget refusal.
regCollision=.LogSubscriptions~new(svc,scope)
call check duplicate(regCollision), 'priority existing rule/target name cannot be replaced'
call check wrongScope(reg,svc), 'priority wrong scope binding refused'
bridge=.KernelLogBridge~new(svc,scope,'mu','boot','inc1')
bridge~bindSubscriptions(reg)
call check duplicate(reg), 'priority frozen subscription registration after binding'
other=.KernelLogBridge~new(svc,scope,'mu','boot','other')
r=other~publish('m','TIMER')
call check \r['OK'] & diagnostic~pending=0, 'priority unbound producer cannot inject into subscribed lane'
spoof=.Directory~new; spoof['INGRESS_ID']='fake'
log=svc~loggerFor(other,'PUBLISH',.Array~new,scope)
call check \log~log(.Log~INFO,spoof,'TIMER') & diagnostic~pending=0, 'priority matching point from wrong receiver refused'
-- A flood in one lane cannot consume another lane's capacity.
do i=1 to 5; r=bridge~publish('m','TIMER','',i); call check r['OK'], 'priority diagnostic publication' i; end
call check diagnostic~pending=2 & diagnostic~status['LOST']=3 & critical~pending=0, 'priority diagnostic overflow stays in own lane'
r=bridge~publish('files','FS_CLOSE_WRITE')
call check r['OK'] & oper~pending=1, 'priority operations independently retained'
r=bridge~publish('other','UNREGISTERED')
call check \r['OK'] & r['INGRESS_ID']=='' & oper~pending=1 & diagnostic~pending=2, 'priority unregistered kind not allocated or routed'
row=.Directory~new; row['BOOT_ID']='boot'; row['ORIGIN']='PAM'; row['TYPE']='USER_AUTH'; row['SERIAL']='1'; row['EPOCH_MS']='123'; row['PID']='12'; row['UID']='1'; row['AUID']='1'; row['SESSION']='1'; row['RESULT']='failed'
r=bridge~publishPam(row); first=r['INGRESS_ID']
call check r['OK'] & critical~pending=1 & mirror~pending=1, 'priority critical and diagnostic subscriptions both receive actual PAM object'
row['SERIAL']='2'; r=bridge~publishPam(row)
call check r['OK'] & critical~pending=2, 'priority critical reserve usable'
row['SERIAL']='3'; r=bridge~publishPam(row)
call check \r['OK'] & critical~pending=2 & critical~status['LOST']=1 & mirror~pending=2, 'priority full critical lane fails even when mirror accepts'
call check badAck(critical,2), 'priority cannot acknowledge unseen events'
p=reg~next(1)
call check p['SUBSCRIPTION']=='auth' & p['PRIORITY']=='CRITICAL' & p['GAP'] & p['LOST']=1, 'priority critical consumption first and sticky gap'
call check p['EVENTS'][1]~isA(.LogEvent) & p['EVENTS'][1]~payload['INGRESS_ID']==first, 'priority oldest critical evidence retained not evicted'
call check badGeneration(critical), 'priority wrong generation acknowledgement refused'
call check critical~ack('g1',p['NEXT'])=1 & critical~pending=1, 'priority explicit acknowledgement releases capacity'
row['SERIAL']='4'; r=bridge~publishPam(row)
call check \r['OK'] & critical~pending=2, 'priority new evidence retained but critical gap remains fail closed'
p=reg~next; call check p['EVENTS']~items=2 & p['GAP'], 'priority critical gap persists after capacity recovery'
critical~ack('g1',p['NEXT'])
p=reg~next; call check p['SUBSCRIPTION']=='oper' & p['EVENTS']~items=1, 'priority operations ahead of diagnostic'
oper~ack('g2',p['NEXT'])
p=reg~next; call check p['PRIORITY']=='DIAGNOSTIC' & p['GAP'] & p['EVENTS']~items=2, 'priority diagnostic gap visible to reader'
diagnostic~ack('g3',diagnostic~read['NEXT'])
mirror~ack('g4',mirror~read['NEXT'])
call check reg~next['EVENTS']~items=0, 'priority all acknowledged lanes drained'
call check reg~status['auth']['LOST']=1, 'priority loss remains visible even after drain'
svc~disableRule('LS-auth','test','owner')
row['SERIAL']='5'; r=bridge~publishPam(row)
call check \r['OK'] & critical~status['LOST']=2 & critical~pending=0, 'priority disabled critical rule records missed required delivery'
svc~enableRule('LS-auth','test','owner')
svc~disableRule('LS-oper','test','owner')
r=bridge~publish('files','FS_CLOSE_WRITE')
call check \r['OK'] & oper~pending=0, 'priority existing logging control can disable selected rule'
svc~enableRule('LS-oper','test','owner')
r=bridge~publish('files','FS_CLOSE_WRITE')
call check r['OK'] & oper~pending=1, 'priority existing logging control can reenable selected rule'
-- Separate runtime shows a real native event cannot launch a job after critical pressure.
parse arg path
svc2=.LogService~new('runtime-priority')
reg2=.LogSubscriptions~new(svc2,scope)
ct=reg2~register('files','g5','KernelLogBridge','PUBLISH',.Array~of('FS_CREATE','FS_MODIFY','FS_CLOSE_WRITE'),'CRITICAL',1)
dt=reg2~register('mirror','g6','KernelLogBridge','PUBLISH',.Array~of('FS_CREATE','FS_MODIFY','FS_CLOSE_WRITE'),'DIAGNOSTIC',16)
b2=.KernelLogBridge~new(svc2,scope,'mu','boot','inc2'); b2~bindSubscriptions(reg2)
rt=.ShellEventRuntime~new('priority-fixture',.Owner~new); rt~setObservationLogger(b2)
root=.POSIXProvider~new~openRoot(path)['ROOT']; w=root~watch('.')['WATCH']; ignore=rt~attach('files',w)
plan=rt~board~plan('review'); step=plan~step('echo'); step~does(.Workspace~new(path),'run',.Array~of('echo','OK')); step~passIf('outputHas','OK')
rule=rt~arm('file','files','FS_CLOSE_WRITE',plan,'x:'||'event'~c2x)
f=.Stream~new(path'/event'); f~charOut('a'); f~close
ignore=rt~pump(1000)
call check rule~state=='DISARMED' & rt~board~jobs~makeArray~items=0 & ct~status['LOST']>0, 'priority actual inotify overload disarms governed trigger despite diagnostic delivery'
rt~close; w~close; root~close
say 'PRIORITY LOGGING SUITE PASSED'
exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::routine overBudget
 use strict arg reg
 signal on syntax name failed
 x=reg~register('extra','g','KernelLogBridge','PUBLISH',.Array~of('TIMER'),'DIAGNOSTIC',1)
 return .false
failed:
 return .true
::routine duplicate
 use strict arg reg
 signal on syntax name failed
 x=reg~register('auth','g','KernelLogBridge','PUBLISHPAM',.Array~of('USER_AUTH'),'CRITICAL',1)
 return .false
failed:
 return .true
::routine wrongScope
 use strict arg reg,svc
 signal on syntax name failed
 b=.KernelLogBridge~new(svc,.Log~internalScope('OTHER'),'mu','boot','bad'); b~bindSubscriptions(reg)
 return .false
failed:
 return .true
::routine badAck
 use strict arg t,n
 signal on syntax name failed
 x=t~ack(t~generation,n)
 return .false
failed:
 return .true
::routine badGeneration
 use strict arg t
 signal on syntax name failed
 x=t~ack('wrong',1)
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
