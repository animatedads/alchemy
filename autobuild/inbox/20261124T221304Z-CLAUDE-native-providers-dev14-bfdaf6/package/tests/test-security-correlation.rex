/* Architecture: Tom Dyer. Coding: ChatGPT. No real login or privilege changes. */
parse arg path
numeric digits 30
p=.ProcessProvider~new~observe(SysQueryProcess('PID')); prov=.POSIXProvider~new
snap=p~securitySnapshot; edge=p~parentEdge; boot=snap['BOOT_ID']; ident=snap['IDENTITY']
call check edge['OK'] & edge['CHILD_IDENTITY']==ident,'parent edge current child identity'
call check edge['PPID']==snap['PPID'] & edge['LINK_AVAILABLE'],'parent edge agrees with observed PPID'
parent=.ProcessProvider~new~observe(edge['PPID']); call check parent~securitySnapshot['IDENTITY']==edge['PARENT_IDENTITY'],'parent edge verified parent start identity'
call check \ShellParentEdge(p~pid,'0')['OK'],'parent edge stale child refused'
l=p~lineage(1);call check l['OK'] & l['TRUNCATED'] & l['EDGES'][1]['CHILD_IDENTITY']==ident,'parent lineage bounded and revalidated'
l=p~lineage(16);call check l['OK'] & l['EDGES']~items>=2 & l['EDGES'][2]['CHILD_IDENTITY']==l['EDGES'][1]['PARENT_IDENTITY'],'parent lineage adjacent identities agree'
call check \prov~tcpCounters(0)['OK'],'tcp counter invalid port refused'
/* Native capability depends on SOCK_DIAG. Never count unexecuted live case as PASS. */
r=prov~tcpCounters(443)
if \r['OK'] then do
  say 'SKIP live SOCK_DIAG counters unavailable:' r['ERRNO'] r['ERROR']
  call check .Array~of(1,2,13,38,93,95,97)~hasItem(r['ERRNO']) & \r~hasIndex('SOCKETS'),'tcp unavailable native dump has no partial rows'
end
else do
  call check r['SCOPE']=='ESTABLISHED_TCP_LOCAL_PORT' & r['SOCKETS']~isA(.Array),'tcp native dump schema'
end
probe=.SecurityTcpRateProbe~new(443,5000)
row=counter(100,1000,2000,'a')
call check \probe~evaluate(row)['OK'],'tcp first sample requires baseline'
row=counter(1100,3000,6000,'a');r=probe~evaluate(row)
call check r['OK'] & r['TCP_ACKED_BPS']=2000 & r['TCP_RECEIVED_BPS']=4000,'tcp counter rates use elapsed time'
row=counter(1600,4000,8000,'a');r=probe~evaluate(row)
call check r['TCP_ACKED_BPS']=2000 & r['TCP_RECEIVED_BPS']=4000,'tcp fractional-second rate'
row=counter(2100,3,8,'a');call check \probe~evaluate(row)['OK'],'tcp counter reset is gap'
row=counter(2600,200,300,'b');call check \probe~evaluate(row)['OK'],'tcp new socket membership is gap'
row=counter(10000,300,400,'b');call check \probe~evaluate(row)['OK'],'tcp excessive interval is gap'
row=counter(11000,400,600,'b');r=probe~evaluate(row);call check r['OK'] & r['TCP_RECEIVED_BPS']=200,'tcp rate resumes from fresh baseline'
row['SOCKETS']~append(row['SOCKETS'][1]);call check \probe~evaluate(row)['OK'],'tcp duplicate cookie refused'
row=counter(12000,500,700,'b');call check \probe~evaluate(row)['OK'],'tcp invalid sample clears baseline'
row=counter(13000,600,900,'b');row['IDENTITY']='other';call check \probe~evaluate(row)['OK'],'tcp namespace identity change is gap'
/* Register a rate gauge using calculated counter observations. */
rate=.SecurityTcpRateProbe~new(443,5000);gauge=.SecurityMetric~new('tcprate',rate,'TCP_RECEIVED_BPS',2000,500,1000,5000)
r=rate~evaluate(counter(100,0,0,'x'));r=gauge~evaluate(r)
call check r[1]['KIND']=='SAMPLE_GAP','tcp metric initial counter unavailable is explicit gap'
r=rate~evaluate(counter(1100,0,500,'x'));r=gauge~evaluate(r)
call check r[1]['KIND']=='METRIC_BASELINE','tcp registered rate initial valid baseline'
r=rate~evaluate(counter(2100,0,3500,'x'));r=gauge~evaluate(r)
call check r~items=2 & r[1]['KIND']=='METRIC_RISE' & r[2]['KIND']=='METRIC_HIGH','tcp registered rate spike and high crossing'
/* Direct correlation logic tests use normalized fixtures. */
base=prov~clockSnapshot['EPOCH_MS']-4000
j=.ShellEventJournal~new('direct',32)
call auth j,boot,1000,42,base+1000
c=.SecurityIncidentCorrelation~new('incident','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);c~bind(j)
call privilege j,boot,ident,1000,42,base+2000
call memory j,boot,ident,1000,42,base+3000
call network j,boot,ident,base+4000
call check c~consume==.nil,'correlation historical auth does not dispatch'
call auth j,boot,1000,43,base+1000
call check c~consume==.nil,'correlation different audit session rejected'
call auth j,boot,1000,42,base+1000
r=c~consume
call check r['KIND']=='INCIDENT_MATCH' & c~state=='FIRED','correlation out-of-arrival-order session evidence matches'
d=.JSON~fromJSON(r['DETAIL']);call check d['AUTH_LINK']=='SESSION_ONLY' & d['SPAN_MS']=3000 & d['CLASSIFICATION']=='REVIEW_REQUIRED','correlation explicit session attribution and span'
call check d['AUTH_EVENT']\==d['PRIVILEGE_EVENT'] & d['MEMORY_EVENT']\==d['NETWORK_EVENT'],'correlation four causal event ids'
call check c~consume==.nil,'correlation one shot'
c=.SecurityIncidentCorrelation~new('gap','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);c~bind(j)
call auth j,boot,1000,42,base+1000
call privilege j,boot,ident,1000,42,base+2000
call memory j,boot,ident,1000,42,base+3000
call network j,boot,ident,base+4000
j~append('metrics','SAMPLE_GAP','rss')
call check c~consume['KIND']=='CORRELATION_GAP' & c~state=='GAP','correlation gap quarantines even complete batch'
c=.SecurityIncidentCorrelation~new('window','pam','metrics','priv','rss','port',boot,1000,42,ident,1000);c~bind(j)
call auth j,boot,1000,42,base+1000
call privilege j,boot,ident,1000,42,base+2000
call memory j,boot,ident,1000,42,base+3000
call network j,boot,ident,base+4000
call check c~consume==.nil,'correlation expired time window no match'
c=.SecurityIncidentCorrelation~new('process','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);c~bind(j)
call auth j,boot,1000,42,base+1000
call privilege j,boot,ident,1000,42,base+2000
call memory j,boot,ident,1000,42,base+3000
call network j,boot,ident||'1',base+4000
call check c~consume==.nil,'correlation different process start identity rejected'
call network j,boot,ident,base+4000
call check c~consume['KIND']=='INCIDENT_MATCH','correlation exact scoped port identity required'
c=.SecurityIncidentCorrelation~new('old','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);c~bind(j)
call auth j,boot,1000,42,base-60000
call privilege j,boot,ident,1000,42,base-59000
call memory j,boot,ident,1000,42,base-58000
call network j,boot,ident,base-57000
call check c~consume==.nil,'correlation stale complete evidence cannot dispatch'
j=.ShellEventJournal~new('lost',2)
c=.SecurityIncidentCorrelation~new('lost','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);c~bind(j)
 do i=1 to 3; j~append('other','OTHER');end
call check c~consume['KIND']=='CORRELATION_GAP','correlation journal retention gap quarantines'
/* Governed job integration: PAM and privilege/metric inputs are controlled
   fixtures with native timer delivery, not generated privilege escalation. */
base=prov~clockSnapshot['EPOCH_MS']-1000
rt=.ShellEventRuntime~new('compound',.CorrelationOwner~new,4096)
ws=.Workspace~new(path);plan=rt~board~plan('review');st=plan~step('inspect');st~does(ws,'run',.Array~of('echo','INCIDENT_REVIEW'));st~passIf('outputHas','INCIDENT_REVIEW')
rt~attachAudit('pam',.PamAuditAdapter~new(boot))
q1=.MutableProbe~new(processRow(boot,ident,1000,42,1000,100,base+1000));q2=.MutableProbe~new(processRow(boot,ident,1000,42,1000,100,base+1000));q3=.MutableProbe~new(portRow(boot,ident,0,base+1000))
sampler=.SecuritySampler~new; sampler~register(.SecurityIdentityMetric~new('priv',q1));sampler~register(.SecurityMetric~new('rss',q2,'RSS_KIB',200,100,50,5000));sampler~register(.SecurityMetric~new('port',q3,'SOCKET_COUNT',2,0,1,5000))
t=prov~timer(20,1000)['TIMER'];rt~attachSampler('metrics',t,sampler)
c=.SecurityIncidentCorrelation~new('incident','pam','metrics','priv','rss','port',boot,1000,42,ident,10000);rt~attachCorrelation('compound',c);rule=rt~arm('review','compound','INCIDENT_MATCH',plan,'incident')
call check rt~pump(1500)['OK'] & c~state=='ARMED','compound initial timer baselines'
a=.Directory~new;a['BOOT_ID']=boot;a['ORIGIN']='PAM';a['TYPE']='USER_AUTH';a['SERIAL']=1;a['EPOCH_MS']=base+1000;a['PID']=1;a['UID']=0;a['AUID']=1000;a['SESSION']=42;a['RESULT']='success'
call check rt~ingestAudit('pam',a)=='PAM_AUTH_SUCCESS' & rule~state=='ARMED','compound PAM session alone not sufficient'
q1~row=processRow(boot,ident,1000,42,0,100,base+2000);q2~row=processRow(boot,ident,1000,42,0,400,base+2000);q3~row=portRow(boot,ident,3,base+2000)
 do i=1 to 3
   r=rt~pump(1500);if rule~state=='FIRED' then leave
 end
call check rule~state=='FIRED' & rt~board~jobs~makeArray~items=1,'compound four observations submit one governed job'
 do i=1 to 150
   if rt~collectJobs=0 then leave
   call SysSleep 0.02
 end
job=rt~board~jobs~makeArray[1];call check job~state=='PASSED' & job~decisions~makeArray~items>0,'compound governed review job passed'
n=0; cause=''; incident=''; do e over rt~journal~replay(0,1024)['EVENTS'];if e~kind=='INCIDENT_MATCH' then incident=e~identity;if e~kind=='SUBMITTED' then cause=e~cause;end
call check incident\=='' & cause==incident,'compound dispatch causal receipt links incident'
call check rt~collectCorrelations=0 & rt~board~jobs~makeArray~items=1,'compound repeated collection no duplicate'
rt~close;t~close
say 'SECURITY CORRELATION SUITE PASSED'
exit 0
check: use arg ok,label; if \ok then do; say 'FAIL' label;exit 1;end;say 'PASS' label;return
::routine counter
 use strict arg stamp,ack,rx,cookie
 r=.Directory~new;r['OK']=1;r['PORT']=443;r['IDENTITY']='scope';r['MONO_MS']=stamp;s=.Directory~new;s['COOKIE']=cookie;s['ACKED_BYTES']=ack;s['RECEIVED_BYTES']=rx;r['SOCKETS']=.Array~of(s);return r
::routine processRow
 use strict arg boot,ident,auid,session,euid,rss,stamp
 r=.Directory~new;r['OK']=1;r['BOOT_ID']=boot;r['IDENTITY']=ident;r['AUID']=auid;r['UID']=auid;r['EUID']=euid;r['AUDIT_SESSION']=session;r['NET_NAMESPACE']='fixture';r['RSS_KIB']=rss;r['MONO_MS']=stamp;r['EPOCH_MS']=stamp;return r
::routine portRow
 use strict arg boot,ident,count,stamp
 r=.Directory~new;r['OK']=1;r['BOOT_ID']=boot;r['IDENTITY']='scope:'ident;r['PROCESS_IDENTITY']=ident;r['SCOPE']='PROCESS_REFERENCES';r['SOCKET_COUNT']=count;r['MONO_MS']=stamp;r['EPOCH_MS']=stamp;return r
::routine auth
 use strict arg j,boot,auid,session,stamp
 d=.Directory~new;d['BOOT_ID']=boot;d['AUID']=auid;d['SESSION']=session;d['EPOCH_MS']=stamp;j~append('pam','PAM_AUTH_SUCCESS','a',1,'',.JSON~toJSON(d))
::routine privilege
 use strict arg j,boot,ident,auid,session,stamp
 d=processRow(boot,ident,auid,session,0,100,stamp);changes=.Directory~new;changes['EUID']=.Array~of(1000,0);d['CHANGES']=changes;j~append('metrics','IDENTITY_CHANGE','priv',1,'',.JSON~toJSON(d))
::routine memory
 use strict arg j,boot,ident,auid,session,stamp
 d=processRow(boot,ident,auid,session,0,100,stamp);d['METRIC']='RSS_KIB';j~append('metrics','METRIC_RISE','rss',1,'',.JSON~toJSON(d))
::routine network
 use strict arg j,boot,ident,stamp
 d=portRow(boot,ident,2,stamp);j~append('metrics','METRIC_RISE','port',1,'',.JSON~toJSON(d))
::class MutableProbe
::method init
 expose row
 use strict arg row
::attribute row
::method snapshot
 expose row
 return row~copy
::class CorrelationOwner
::method principal
 return 'llm'
::method kind
 return 'llm'
::method jobFinished
 use strict arg job
 return .true
::requires 'ShellSecurityCorrelation.cls'
