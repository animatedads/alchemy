/* Architecture: Tom Dyer. Coding: ChatGPT. Disposable local process and socket. */
parse arg path fixture
numeric digits 25
pr=.ProcessProvider~new; prov=.POSIXProvider~new
selfp=pr~observe(SysQueryProcess('PID')); snap=selfp~securitySnapshot
call check snap['OK'] & snap['MEMORY_AVAILABLE'] & snap['RSS_KIB']>0,'security native RSS'
call check snap['PID']=SysQueryProcess('PID') & snap['BOOT_ID']~length=36,'security boot and process identity'
call check snap~hasIndex('AUID') & snap~hasIndex('AUDIT_SESSION') & snap~hasIndex('EUID'),'security login and effective identity'
call check \ShellSecurityProcess(selfp~pid,'0')['OK'],'security stale process refused'
call check \prov~portSnapshot(0)['OK'] & \prov~portSnapshot(65536)['OK'],'security invalid ports refused'
call check \prov~portSnapshot(80,'icmp')['OK'],'security unsupported protocol refused'
boot=snap['BOOT_ID']; ad=.PamAuditAdapter~new(boot)
line="type=USER_AUTH msg=audit(1780000000.123:42): pid="selfp~pid" uid=0 auid=1000 ses=9 msg='op=PAM:authentication acct="||'"test"'||" res=failed'"
a=ad~parseAuditLine(line)
call check a['EPOCH_MS']=1780000000123 & a['SERIAL']=42,'security audit envelope parsed'
r=ad~normalize(a); info=.JSON~fromJSON(r['DETAIL'])
call check r['KIND']=='PAM_AUTH_FAILURE' & info['AUID']=1000 & info['PROCESS_LINK']=='UNVERIFIED','security PAM failure and unverified attribution'
call check \info~hasIndex('acct') & \info~hasIndex('raw'),'security no raw PAM payload exported'
call check ad~normalize(a)['KIND']=='AUDIT_DUPLICATE','security duplicate audit record'
a['SERIAL']=43;a['TYPE']='USER_START';a['RESULT']='success';a['AUID']='4294967295';a['SESSION']='4294967295'
r=ad~normalize(a); info=.JSON~fromJSON(r['DETAIL'])
call check r['KIND']=='PAM_SESSION_OPEN' & info['AUID']=='UNSET' & info['SESSION']=='UNSET','security PAM session and unset identity'
a['SERIAL']=44;a['TYPE']='CRED_ACQ';a['RESULT']='failed'
call check ad~normalize(a)['KIND']=='PAM_OPERATION_FAILED','security failed credential acquisition not success'
call check badAudit(ad,a~copy,'BOOT_ID','invalid'),'security wrong boot rejected'
call check badAudit(ad,a~copy,'ORIGIN','syslog'),'security non-PAM origin rejected'
call check badAudit(ad,a~copy,'PID','bad'),'security bad PID rejected'
call check badLine(ad,changestr('op=PAM:authentication',line,'op=other')),'security non-PAM line refused'
-- Deterministic threshold and gap fixtures.
m=.SecurityMetric~new('rss',.SecurityProcessProbe~new(selfp),'RSS_KIB',100,80,20,500)
x=.Directory~new;x['OK']=1;x['IDENTITY']='a';x['RSS_KIB']=50;x['MONO_MS']=1
call check m~evaluate(x)[1]['KIND']=='METRIC_BASELINE','security initial baseline'
x['RSS_KIB']=120;x['MONO_MS']=101
r=m~evaluate(x);call check has(r,'METRIC_HIGH') & has(r,'METRIC_RISE'),'security upward threshold and spike'
x['RSS_KIB']=110;x['MONO_MS']=201;call check m~evaluate(x)~items=0,'security high hysteresis no repetition'
x['RSS_KIB']=80;x['MONO_MS']=301;r=m~evaluate(x);call check has(r,'METRIC_FALL') & has(r,'METRIC_RECOVERED'),'security fall and recovery'
x['RSS_KIB']=300;x['MONO_MS']=401;r=m~evaluate(x,2);call check has(r,'SAMPLE_GAP') & \has(r,'METRIC_RISE'),'security missed interval no false spike'
x['IDENTITY']='b';x['RSS_KIB']=10;x['MONO_MS']=501;r=m~evaluate(x);call check has(r,'SAMPLE_GAP') & \has(r,'METRIC_FALL'),'security identity change resets baseline'
x['RSS_KIB']=1000;x['MONO_MS']=1500;r=m~evaluate(x);call check has(r,'SAMPLE_GAP') & \has(r,'METRIC_RISE'),'security elapsed gap no false spike'
x~remove('RSS_KIB');call check has(m~evaluate(x),'SAMPLE_GAP'),'security unavailable metric not zero'
call check m~history~makeArray~items=8 & m~history~makeArray[8]~field('VALUE')=='UNKNOWN','security bounded history retains unavailable sample'
call check m~history~asTable~pos('VALUE')>0,'security sample history table'
call check .JSON~fromJSON(m~history~asJson)~items=8,'security sample history JSON'
 do i=1 to 260
   x['RSS_KIB']=i;x['MONO_MS']+=100;r=m~evaluate(x)
 end
call check m~history~makeArray~items=256 & m~historyDropped=12,'security sample history retention explicit'
im=.SecurityIdentityMetric~new('priv',.SecurityProcessProbe~new(selfp));x=snap~copy
call check has(im~evaluate(x),'METRIC_BASELINE'),'security privilege baseline'
x['EUID']=999; x['MONO_MS']+=1;r=im~evaluate(x); call check has(r,'IDENTITY_CHANGE'),'security effective UID change'
x['AUID']='1000';x['MONO_MS']+=1;r=im~evaluate(x)
x['AUID']='UNKNOWN';x['MONO_MS']+=1;r=im~evaluate(x);call check has(r,'SAMPLE_GAP') & \has(r,'IDENTITY_CHANGE'),'security unknown attribution not transition'
-- Actual native process and socket observations with same event runtime.
runner=.ProcessRunner~new(pr);spec=.ProcessSpec~new(.Array~of(fixture,path));spec~detach=.true;spec~stdoutPolicy='DISCARD';spec~stderrPolicy='DISCARD';child=runner~run(spec)
call check child~started,'security fixture spawned'
call waitFile path'/port'
f=.Stream~new(path'/port');port=f~lineIn;f~close
p=pr~observe(child~pid);base=p~securitySnapshot
portbase=prov~portSnapshot(port)
scopedbase=p~portSnapshot(port)
call check scopedbase['OK'] & scopedbase['SOCKET_COUNT']=0,'security scoped port baseline'
call check .Array~of('PRESENT','ABSENT')~hasItem(portbase['IPV6']) & scopedbase['IPV6']==portbase['IPV6'],'security IPv6 family explicit for scoped and unscoped TCP'
u=prov~portSnapshot(port,'udp'); call check u['OK'] & .Array~of('PRESENT','ABSENT')~hasItem(u['IPV6']),'security UDP family explicit'
if value('REQUIRE_NO_IPV6',,'ENVIRONMENT')=='1' then call check portbase['IPV6']=='ABSENT' & u['IPV6']=='ABSENT','security actual IPv4-only kernel tables'
else say 'NOTE actual no-IPv6 qualification requires REQUIRE_NO_IPV6=1 on IPv4-only host'
call check base['OK'] & portbase['OK'] & portbase['LISTENER_COUNT']=0,'security live memory and port baseline'
rt=.ShellEventRuntime~new('security',.SecurityOwner~new,4096)
ws=.Workspace~new(path);plan=rt~board~plan('review');step=plan~step('review');step~does(ws,'run',.Array~of('echo','SECURITY_REVIEW'));step~passIf('outputHas','SECURITY_REVIEW')
s=.SecuritySampler~new;s~register(.SecurityMetric~new('rss',.SecurityProcessProbe~new(p),'RSS_KIB',base['RSS_KIB']+16384,base['RSS_KIB']+8192,8192,5000));s~register(.SecurityMetric~new('port',.SecurityProcessPortProbe~new(p,port),'SOCKET_COUNT',2,0,1,5000))
t=prov~timer(10,500)['TIMER'];rt~attachSampler('metrics',t,s)
rr=rt~arm('rss-rise','metrics','METRIC_RISE',plan,'rss');rp=rt~arm('port-rise','metrics','METRIC_RISE',plan,'port')
r=rt~pump(1000)
call check count(rt~journal,'METRIC_BASELINE')=2,'security timer samples both baselines'
call touch path'/go';call waitFile path'/ready'
now=p~securitySnapshot; pn=prov~portSnapshot(port)
call check now['RSS_KIB']-base['RSS_KIB']>=16384 & now['PEAK_RSS_KIB']>=now['RSS_KIB'],'security actual allocation spike'
call check pn['OK'] & pn['LISTENER_COUNT']=1 & pn['ESTABLISHED_COUNT']>=1 & pn['SOCKET_COUNT']>=2,'security actual port listener and connection change'
scoped=p~portSnapshot(port); unrelated=selfp~portSnapshot(port)
call check scoped['OK'] & scoped['SOCKET_COUNT']>=2 & scoped['PROCESS_IDENTITY']==now['IDENTITY'],'security process socket references joined by inode'
call check unrelated['OK'] & unrelated['SOCKET_COUNT']=0,'security unrelated process not attributed port'
call check \ShellProcessPortSnapshot(p~pid,'0',port,'tcp')['OK'],'security scoped socket stale identity refused'
say 'MEASURE RSS_KIB' base['RSS_KIB'] now['RSS_KIB'] 'PORT' port 'SOCKET_COUNT' scopedbase['SOCKET_COUNT'] scoped['SOCKET_COUNT'] 'RX_QUEUE' scoped['RX_QUEUE']
call check pn['RX_QUEUE']>0 & pn['NET_NAMESPACE']==now['NET_NAMESPACE'],'security actual queued receive data and namespace'
r=rt~pump(1000)
call check rr~state=='FIRED' & rp~state=='FIRED' & rt~board~jobs~makeArray~items=2,'security native spikes submit two governed plans'
rt~attachAudit('pam',.PamAuditAdapter~new(boot));rule=rt~arm('pam-failure','pam','PAM_AUTH_FAILURE',plan)
a=ad~parseAuditLine(line);call check rt~ingestAudit('pam',a)=='PAM_AUTH_FAILURE' & rule~state=='FIRED','security trusted PAM record submits governed plan'
call check rt~ingestAudit('pam',a)=='AUDIT_DUPLICATE' & rt~board~jobs~makeArray~items=3,'security PAM duplicate cannot dispatch again'
rule=rt~arm('gap-rule','pam','PAM_AUTH_SUCCESS',plan);g=.Directory~new;g['TYPE']='GAP';call check rt~ingestAudit('pam',g)=='AUDIT_GAP' & rule~state=='DISARMED','security audit loss disarms rules'
 do i=1 to 150
   pending=rt~collectJobs
   if pending=0 then leave
   call SysSleep 0.02
 end
call check pending=0 & count(rt~journal,'JOB_SETTLED')=3,'security all governed jobs settled'
 do job over rt~board~jobs~makeArray
   call check job~state=='PASSED' & job~decisions~makeArray~items>0,'security authorised review plan receipt'
 end
call check count(rt~journal,'SUBMITTED')=3 & count(rt~journal,'METRIC_RISE')=2,'security journal causation and changes'
view=.SecurityEvidenceView~new(rt~journal)
trail=view~processTrail(now['IDENTITY'],0,128)
call check trail['EVENTS']~items>=4 & \trail['GAP'],'security process evidence trail includes scoped port and RSS'
trail=view~sessionTrail(boot,1000,9,0,128)
call check trail['EVENTS']~items=1 & trail['EVENTS'][1]~kind=='PAM_AUTH_FAILURE','security audit session evidence does not falsely join PID'
-- A real watched file drives the audit path; the text is a fixture, not a live login.
call touch path'/audit.log'
f=.Stream~new(path'/audit.log');f~open('WRITE REPLACE');f~charOut('type=TEST historical record'||'0a'x);f~close
aroot=prov~openRoot(path)['ROOT'];tail=.PamAuditLogTail~new(aroot,'audit.log',.PamAuditAdapter~new(boot));id=rt~attachAuditLog('auditfile',tail)['REGISTRATION']
rule=rt~arm('pam-log-failure','auditfile','PAM_AUTH_FAILURE',plan)
f=.Stream~new(path'/audit.log');f~open('WRITE APPEND');f~charOut(line||'0a'x);f~close
 do i=1 to 5
   dummy=rt~pump(500)
   if rule~state=='FIRED' then leave
 end
call check rule~state=='FIRED' & rt~board~jobs~makeArray~items=4,'security actual inotify audit log append dispatch'
rule=rt~arm('rotation','auditfile','PAM_AUTH_SUCCESS',plan)
'mv --' path'/audit.log' path'/audit.old'
if rc<>0 then exit 2
call touch path'/audit.log'
 do i=1 to 5
   dummy=rt~pump(500)
   if rule~state=='DISARMED' then leave
 end
call check rule~state=='DISARMED' & count(rt~journal,'AUDIT_GAP')=2,'security actual audit log rotation quarantined'
 do i=1 to 100
   if rt~collectJobs=0 then leave
   call SysSleep 0.02
 end
call check rt~board~jobs~makeArray[4]~state=='PASSED','security audit file review job passed'
tail~close;aroot~close
call check rt~close,'security shutdown';t~close;call touch path'/stop'
-- Fixture exits on its own; reaper remains the existing runner.
 do i=1 to 100
   if \p~isCurrent then leave
   call SysSleep 0.02
   r=pr~reap(child~pid)
 end
say 'SECURITY OBSERVATION SUITE PASSED'
exit 0
check:
 use arg ok,label
 if \ok then do; say 'FAIL' label; exit 1; end
 say 'PASS' label
 return
::routine has
 use strict arg arr,kind
 do row over arr; if row['KIND']==kind then return .true; end
 return .false
::routine count
 use strict arg journal,kind
 n=0;do e over journal~replay(0,1024)['EVENTS'];if e~kind==kind then n+=1;end;return n
::routine badAudit
 use strict arg ad,row,key,value
 row[key]=value
 signal on syntax name bad
 r=ad~normalize(row);return .false
 bad: return .true
::routine badLine
 use strict arg ad,line
 signal on syntax name bad
 r=ad~parseAuditLine(line);return .false
 bad: return .true
::routine waitFile
 use strict arg path
 do i=1 to 200
   if stream(path,'C','QUERY EXISTS')\=='' then return
   call SysSleep 0.02
 end
 raise syntax 93.900 array ('Fixture did not become ready' path)
::routine touch
 use strict arg path
 f=.Stream~new(path);f~charOut('1');f~close
::class SecurityOwner
::method principal
 return 'llm'
::method kind
 return 'llm'
::method jobFinished
 use strict arg job
 return .true
::requires 'ShellSecurityObservation.cls'
