/* Architecture: Tom Dyer. Coding: ChatGPT. Actual native event and JobBoard test. */
parse arg path
numeric digits 20
j=.ShellEventJournal~new('audit',3)
a=j~append('a','TIMER')
b=j~append('a','TIMER')
c=j~append('a','TIMER')
d=j~append('a','TIMER')
call check a~identity == 'audit:1' & d~sequence=4, 'runtime sequence identity'
r=j~replay(0,2)
call check r['GAP'] & r['FIRST']=2 & r['LATEST']=4, 'runtime replay gap explicit'
call check r['EVENTS']~items=2 & r['EVENTS'][1]~identity=='audit:2' & r['NEXT']=3, 'runtime replay bounded'
r=j~replay(r['NEXT'],2)
call check \r['GAP'] & r['EVENTS']~items=1 & r['NEXT']=4, 'runtime replay continuation'
r=j~replay(4)
call check r['EVENTS']~items=0 & \r['GAP'], 'runtime replay end'
r=.JSON~fromJSON(j~exportPage(0,2))
call check r['EVENTS']~items=2 & r['NEXT']=3, 'runtime JSON export'
call check j~latest=4, 'runtime export nonmutating'

p=.POSIXProvider~new
owner=.RuntimeTestOwner~new
rt=.ShellEventRuntime~new('fixture',owner,4096)
ws=.Workspace~new(path)
plan=rt~board~plan('template')
s=plan~step('echo'); s~does(ws,'run',.Array~of('echo','EVENT_OK')); s~passIf('exitIs',0);s~passIf('outputHas','EVENT_OK')
root=p~openRoot(path)['ROOT']
w=root~watch('runtimedir')['WATCH']
fid=rt~attach('files',w)['REGISTRATION']
rule=rt~arm('incoming','files','FS_CLOSE_WRITE',plan,'x:'||'input.bin'~c2x)
call check rule~state=='ARMED', 'runtime rule armed'
-- Template mutation after arm must not affect the captured steps.
plan~step('extra')~passIf('outputHas','IMPOSSIBLE')
f=path'/runtimedir/unrelated';s=.Stream~new(f);s~charOut('x');s~close
dummy = rt~pump(1000)
call check rule~state=='ARMED' & rt~board~jobs~makeArray~items=0, 'runtime nonmatching event ignored'
f=path'/runtimedir/input.bin';s=.Stream~new(f);s~charOut('x');s~close
dummy = rt~pump(1000)
call check rule~state=='FIRED' & rt~board~jobs~makeArray~items=1, 'runtime native file event submits plan'
job=rt~board~jobs~makeArray[1]
call check job~stepCount=1, 'runtime isolated plan template'
call awaitJob rt,job
call check job~state=='PASSED', 'runtime actual authorised workspace execution'
call check job~decisions~makeArray~items>0, 'runtime execution policy decisions present'
call check countKind(rt~journal,'SUBMITTED')=1 & countKind(rt~journal,'JOB_SETTLED')=1, 'runtime submit and settled receipts'
a=findKind(rt~journal,'FS_CLOSE_WRITE','x:'||'input.bin'~c2x); b=findKind(rt~journal,'JOB_SETTLED','')
call check a\==.nil & b~cause==a~identity & b~detail=='PASSED', 'runtime event-to-job causation'
s=.Stream~new(f);s~charOut('y');s~close
dummy = rt~pump(1000)
call check rt~board~jobs~makeArray~items=1, 'runtime one-shot deduplication'
dummy = rt~journal~exportPage(0,128)
call check rt~board~jobs~makeArray~items=1, 'runtime replay never launches jobs'

-- Timer uses the same job mechanism. Policy denial at step is NOT a passed job.
t=p~timer(30)['TIMER']; tid=rt~attach('clock',t)['REGISTRATION']
plan=rt~board~plan('denied-step');s=plan~step('no');s~does(ws,'run',.Array~of('false'));s~passIf('exitIs',0)
r=rt~arm('timer-denied','clock','TIMER',plan)
dummy = rt~pump(1000)
call check r~state=='FIRED' & rt~board~jobs~makeArray~items=2, 'runtime timer submits through policy'
job=rt~board~jobs~makeArray[2];call awaitJob rt,job
call check job~state=='FAILED', 'runtime denied action fails plan'
found=0; do decision over job~decisions; if decision~verdict=='deny' then found=1; end
call check found, 'runtime denied action witnessed'
call check countKind(rt~journal,'JOB_SETTLED')=2, 'runtime failed job settled receipt'
call check rt~detach(tid), 'runtime explicit detach'
t~close

-- Actual disposable child exit.
pr=.ProcessProvider~new;runner=.ProcessRunner~new(pr)
spec=.ProcessSpec~new(.Array~of('/bin/sleep','10'));spec~detach=.true;spec~stdoutPolicy='DISCARD';spec~stderrPolicy='DISCARD'
child=runner~run(spec)
if \child~started then exit 2
h=pr~openProcessHandle(pr~observe(child~pid))['PROCESS_HANDLE']
if h==.nil then exit 2
pid=rt~attach('child',h)['REGISTRATION']
plan=rt~board~plan('exit-plan');s=plan~step('exit');s~does(ws,'run',.Array~of('echo','EXIT_OK'));s~passIf('outputHas','EXIT_OK')
r=rt~arm('exit-once','child','PROCESS_EXIT',plan)
h~signal(15)
dummy = rt~pump(5000)
call check r~state=='FIRED' & countKind(rt~journal,'PROCESS_EXIT')=1, 'runtime actual process exit fires'
job=rt~board~jobs~makeArray[3];call awaitJob rt,job
call check job~state=='PASSED', 'runtime process-triggered plan passed'
reaped=pr~reap(child~pid);h~close
call check reaped~termination=='SIGNAL', 'runtime runner retains reaping authority'
dummy = rt~pump(0)
call check countKind(rt~journal,'PROCESS_EXIT')=1, 'runtime process terminal event once'

-- Watch invalidation quarantines source and disarms its rule.
plan=rt~board~plan('unused');s=plan~step('never');s~does(ws,'run',.Array~of('echo','UNUSED'))
r=rt~arm('move-refusal','files','FS_CLOSE_WRITE',plan)
'mv --' path'/runtimedir' path'/runtime-moved'
if rc<>0 then exit 2
dummy = rt~pump(1000)
call check countKind(rt~journal,'RESCAN_REQUIRED')=1 & r~state=='DISARMED', 'runtime invalidation quarantines and disarms'
call check \rt~detach(fid), 'runtime quarantined registration removed'
w~close;root~close
call check rt~close & \rt~close, 'runtime idempotent close'
call check countKind(rt~journal,'RUNTIME_CLOSED')=1, 'runtime shutdown receipt'
-- Board submission itself must be refused under the owner's principal.
call value 'NEWSHELL_POLICY',path'/deny.policy','ENVIRONMENT'
.ShellPolicy~reload
rt=.ShellEventRuntime~new('denial',owner,32)
t=p~timer(10)['TIMER']; rt~attach('clock',t)
plan=rt~board~plan('denied');s=plan~step('echo');s~does(ws,'run',.Array~of('echo','NEVER'))
r=rt~arm('denied','clock','TIMER',plan)
dummy = rt~pump(1000)
call check countKind(rt~journal,'DENIED')=1 & rt~board~jobs~makeArray~items=0, 'runtime submit policy denial no job'
call check r~state=='FIRED', 'runtime denied rule not retried'
rt~close;t~close
-- Lifetime dispatch quota, source loss, and source reuse must not revive old rules.
call value 'NEWSHELL_POLICY',path'/allow.policy','ENVIRONMENT'
.ShellPolicy~reload
rt=.ShellEventRuntime~new('quota',owner,64,1)
t=p~timer(10,10)['TIMER']; id=rt~attach('clock',t)['REGISTRATION']
plan=rt~board~plan('ok');s=plan~step('echo');s~does(ws,'run',.Array~of('echo','QUOTA'));s~passIf('outputHas','QUOTA')
call check rejectedArm(rt,'bad-source','clock','PROCESS_EXIT',plan,''), 'runtime source kind mismatch refused'
call check rejectedArm(rt,'bad-subject','clock','TIMER',plan,'x:41'), 'runtime invalid timer subject refused'
call check rejectedArm(rt,'unknown','no-such-source','TIMER',plan,''), 'runtime unknown source refused'
call check rejectedArm(rt,'bad rule','clock','TIMER',plan,''), 'runtime invalid rule identity refused'
r=rt~arm('first','clock','TIMER',plan)
call check rejectedArm(rt,'first','clock','TIMER',plan,''), 'runtime duplicate rule refused'
dummy=rt~pump(1000)
job=rt~board~jobs~makeArray[1];call awaitJob rt,job
call check job~state=='PASSED', 'runtime quota first job passes'
r=rt~arm('quota-second','clock','TIMER',plan)
dummy=rt~pump(1000)
call check r~state=='DISARMED' & countKind(rt~journal,'DISPATCH_LIMIT')=1, 'runtime lifetime quota refusal recorded'
call check rt~board~jobs~makeArray~items=1, 'runtime quota prevents second job'
r=rt~arm('closure','clock','TIMER',plan)
t~close
dummy=rt~pump(1000)
call check countKind(rt~journal,'SOURCE_LOST')=1 & r~state=='DISARMED', 'runtime source closure disarms rule'
t=p~timer(10)['TIMER'];id=rt~attach('clock',t)['REGISTRATION'];dummy=rt~pump(1000)
call check r~state=='DISARMED' & rt~board~jobs~makeArray~items=1, 'runtime reused label cannot revive stale rule'
call check rt~disarm('closure') & \rt~disarm('closure'), 'runtime explicit rule removal'
call check rt~close & t~drain['OK'], 'runtime close does not close caller-owned source'
t~close
say 'EVENT RUNTIME SUITE PASSED'
exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::routine rejectedArm
 use strict arg rt,name,source,kind,plan,subject
 signal on syntax name rejected
 r=rt~arm(name,source,kind,plan,subject)
 return .false
rejected:
 return .true
::routine awaitJob
 use strict arg rt,job
 do i=1 to 100
   if job~settled then leave
   call SysSleep 0.02
 end
 rt~collectJobs
 if \job~settled then raise syntax 93.900 array ('Job did not settle')
::routine countKind
 use strict arg journal,kind
 return countRecords(journal,kind,'')
::routine countRecords
 use strict arg journal,kind,subject
 count=0
 do e over journal~replay(0,1024)['EVENTS']
   if e~kind==kind & (subject=='' | e~subject==subject) then count+=1
 end
 return count
::routine findKind
 use strict arg journal,kind,subject
 do e over journal~replay(0,1024)['EVENTS']
   if e~kind==kind & (subject=='' | e~subject==subject) then return e
 end
 return .nil
::class RuntimeTestOwner
::method principal
 return 'llm'
::method kind
 return 'llm'
::method jobFinished
 use strict arg job
 return .true
::requires 'ShellEventRuntime.cls'
::requires 'ProcessProvider.cls'
