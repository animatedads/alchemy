/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted host integration only.
   Compound evidence, not breach proof. No mutation or direct job submission. */
::requires 'ShellSecurityObservation.cls'

/* Rates of TCP payload counters for an unchanged set of established local-port
   sockets. A new or vanished socket, a reset or missed interval is a gap. */
::class SecurityTcpRateProbe public
::method init
  expose port maxGap previous
  use strict arg port, maxGap = 10000
  if \port~datatype('W') | port < 1 | port > 65535 | \maxGap~datatype('W') | maxGap < 1 | maxGap > 60000 then raise syntax 93.900 array ('Invalid TCP rate probe')
  previous = .nil
::method snapshot
  expose port
  return self~evaluate(.POSIXProvider~new~tcpCounters(port))
::method evaluate
  expose previous maxGap port
  use strict arg row
  numeric digits 30
  if \row['OK'] then do; previous = .nil; return rateGap('counter observation unavailable'); end
  if row['PORT'] \== port | row['IDENTITY'] == .nil | \row['MONO_MS']~datatype('W') | \row['SOCKETS']~isA(.Array) then do
    previous = .nil; return rateGap('invalid counter observation')
  end
  current = .Directory~new; sockets = .Directory~new
  current['IDENTITY']=row['IDENTITY']; current['MONO_MS']=row['MONO_MS']; current['SOCKETS']=sockets
  if row['SOCKETS']~items > 1024 then do; previous=.nil; return rateGap('counter scope too large'); end
  do s over row['SOCKETS']
    k=s['COOKIE']
    if k == .nil | k == '' | sockets~hasIndex(k) then do; previous=.nil; return rateGap('invalid socket identity'); end
    do f over .Array~of('ACKED_BYTES','RECEIVED_BYTES')
      if \s[f]~datatype('W') | s[f]<0 | s[f]>18446744073709551615 then do; previous=.nil; return rateGap('invalid counter'); end
    end
    sockets[k]=s~copy
  end
  old=previous; previous=current
  if old == .nil then return rateGap('baseline required')
  elapsed=current['MONO_MS']-old['MONO_MS']
  if elapsed <= 0 | elapsed > maxGap | old['IDENTITY'] \== current['IDENTITY'] then return rateGap('identity or time gap')
  if sockets~items \= old['SOCKETS']~items then return rateGap('socket membership changed')
  ack=0; rx=0
  do k over sockets~allIndexes
    if \old['SOCKETS']~hasIndex(k) then return rateGap('socket membership changed')
    s=sockets[k]; o=old['SOCKETS'][k]
    if s['ACKED_BYTES'] < o['ACKED_BYTES'] | s['RECEIVED_BYTES'] < o['RECEIVED_BYTES'] then return rateGap('counter reset')
    ack+=s['ACKED_BYTES']-o['ACKED_BYTES']; rx+=s['RECEIVED_BYTES']-o['RECEIVED_BYTES']
  end
  out=.Directory~new; out['OK']=1; out['IDENTITY']=row['IDENTITY']; out['MONO_MS']=row['MONO_MS']; out['ELAPSED_MS']=elapsed
  do f over .Array~of('BOOT_ID','NET_NAMESPACE','PORT','EPOCH_MS','SCOPE'); if row~hasIndex(f) then out[f]=row[f]; end
  out['ACKED_DELTA_BYTES']=ack; out['RECEIVED_DELTA_BYTES']=rx
  out['TCP_ACKED_BPS']=trunc(ack*1000/elapsed); out['TCP_RECEIVED_BPS']=trunc(rx*1000/elapsed)
  out['SOCKET_COUNT']=sockets~items
  return out

::routine rateGap
  use strict arg reason
  out=.Directory~new; out['OK']=0; out['ERROR']=reason; return out

/* One bounded rule for a known session and one exact observed process identity.
   Authentication is session-level evidence; the other three observations must
   identify the same process. Never infer a historical process from PAM's PID. */
::class SecurityIncidentCorrelation public
::method init
  expose name auditSource metricSource privilegeSubject memorySubject portSubject window boot auid session process state cursor journal candidates clockAnchor
  use strict arg name,auditSource,metricSource,privilegeSubject,memorySubject,portSubject,boot,auid,session,process,window=30000
  numeric digits 25
  do v over .Array~of(name,auditSource,metricSource,privilegeSubject,memorySubject,portSubject)
    if \v~isA(.String) | v~length<1 | v~length>64 | v~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-')\=0 then raise syntax 93.900 array ('Invalid correlation label')
  end
  if auditSource==metricSource | privilegeSubject==memorySubject | privilegeSubject==portSubject | memorySubject==portSubject then raise syntax 93.900 array ('Distinct source/subject required')
  if boot~length\=36 | boot~verify('0123456789abcdef-')\=0 | process~left(37)\==boot':' then raise syntax 93.900 array ('Exact boot/process identity required')
  parse var process . ':' pid ':' tick
  if \pid~datatype('W') | pid<1 | pid>2147483647 | \tick~datatype('W') | tick<0 then raise syntax 93.900 array ('Invalid process identity')
  do v over .Array~of(auid,session)
    if \v~datatype('W') | v<0 | v>=4294967295 then raise syntax 93.900 array ('Known audit identity required')
  end
  if \window~datatype('W') | window<1 | window>300000 then raise syntax 93.900 array ('Invalid correlation window')
  state='NEW'; cursor=0; journal=.nil; candidates=.Directory~new
::attribute name get
::attribute state get
::attribute auditSource get
::attribute metricSource get
::method subjects
  expose privilegeSubject memorySubject portSubject
  return .Array~of(privilegeSubject,memorySubject,portSubject)
::method bind
  expose state journal cursor clockAnchor
  use strict arg j
  if state\=='NEW' | \j~isA(.ShellEventJournal) then raise syntax 93.900 array ('Correlation already bound or invalid journal')
  journal=j;cursor=j~latest;clockAnchor=.POSIXProvider~new~clockSnapshot;state='ARMED'
::method consume
  expose journal cursor state candidates auditSource metricSource privilegeSubject memorySubject portSubject boot auid session process window name clockAnchor
  numeric digits 25
  if state\=='ARMED' then return .nil
  now=.POSIXProvider~new~clockSnapshot
  if abs((now['EPOCH_MS']-clockAnchor['EPOCH_MS'])-(now['MONO_MS']-clockAnchor['MONO_MS']))>2000 then return self~gap('wall clock discontinuity')
  do k over candidates~allIndexes
    if now['EPOCH_MS']-candidates[k]['TIME']>window then candidates~remove(k)
  end
  page=journal~replay(cursor,1024)
  if page['GAP'] | page['NEXT'] < page['LATEST'] then return self~gap('journal retention or processing gap')
  cursor=page['NEXT']
  /* Validate entire batch for losses before evaluating any match. */
  do e over page['EVENTS']
    if e~source\==auditSource & e~source\==metricSource then iterate
    if .Array~of('AUDIT_GAP','RESCAN_REQUIRED','SOURCE_LOST','SOURCE_DETACHED')~hasItem(e~kind) then return self~gap('source invalidated: 'e~source)
    if e~kind=='SAMPLE_GAP' & (e~subject==privilegeSubject | e~subject==memorySubject | e~subject==portSubject) then return self~gap('sample gap: 'e~subject)
  end
  do e over page['EVENTS']
    key=''
    if e~source==auditSource & (e~kind=='PAM_AUTH_SUCCESS' | e~kind=='PAM_SESSION_OPEN') then key='AUTH'
    else if e~source==metricSource then do
      if e~subject==privilegeSubject & e~kind=='IDENTITY_CHANGE' then key='PRIVILEGE'
      if e~subject==memorySubject & e~kind=='METRIC_RISE' then key='MEMORY'
      if e~subject==portSubject & (e~kind=='METRIC_RISE' | e~kind=='METRIC_HIGH') then key='NETWORK'
    end
    if key=='' then iterate
    d=correlationDetail(e)
    if d==.nil then return self~gap('malformed evidence')
    if d['BOOT_ID']\==boot then iterate
    if \d['EPOCH_MS']~datatype('W') | d['EPOCH_MS']<0 then return self~gap('missing observation time')
    if d['EPOCH_MS']>now['EPOCH_MS']+1000 then return self~gap('observation timestamp in future')
    if now['EPOCH_MS']-d['EPOCH_MS']>window then iterate
    if key=='AUTH' then do
      if d['AUID']\=auid | d['SESSION']\=session then iterate
    end
    else if key=='NETWORK' then do
      if d['PROCESS_IDENTITY']\==process then iterate
      if d['SCOPE']\=='PROCESS_REFERENCES' then iterate
    end
    else do
      if d['IDENTITY']\==process | d['AUID']\=auid | d['AUDIT_SESSION']\=session then iterate
      if key=='PRIVILEGE' then do
        c=d['CHANGES']; if \c~isA(.Directory) then return self~gap('invalid privilege evidence')
        ids=c['EUID']; if ids==.nil then iterate
        if \ids~isA(.Array) then return self~gap('invalid privilege transition')
        if ids~items\=2 then return self~gap('invalid privilege transition')
        if \ids[1]~datatype('W') | ids[1]<=0 | ids[2]\=0 then iterate
        if d['EUID']\=0 then iterate
      end
      else if d['METRIC']\=='RSS_KIB' then iterate
    end
    /* Keep one newest observation per kind; out-of-order records cannot
       replace newer evidence. Conservative, not exhaustive event matching. */
    if candidates~hasIndex(key) then if candidates[key]['TIME']>d['EPOCH_MS'] then iterate
    c=.Directory~new;c['TIME']=d['EPOCH_MS'];c['EVENT']=e~identity;candidates[key]=c
  end
  if candidates~items\=4 then return .nil
  a=candidates['AUTH']['TIME'];p=candidates['PRIVILEGE']['TIME'];m=candidates['MEMORY']['TIME'];n=candidates['NETWORK']['TIME']
  if a>min(p,m,n) | max(p,m,n)-a>window then return .nil
  out=.Directory~new;out['BOOT_ID']=boot;out['AUID']=auid;out['AUDIT_SESSION']=session;out['PROCESS_IDENTITY']=process;out['WINDOW_MS']=window;out['SPAN_MS']=max(p,m,n)-a;out['AUTH_LINK']='SESSION_ONLY';out['CLASSIFICATION']='REVIEW_REQUIRED'
  do k over .Array~of('AUTH','PRIVILEGE','MEMORY','NETWORK');out[k'_EVENT']=candidates[k]['EVENT'];end
  state='FIRED';candidates~empty
  return correlationEvent('INCIDENT_MATCH',name,.JSON~toJSON(out))
::method gap private
  expose state candidates name
  use strict arg reason
  state='GAP';candidates~empty
  return correlationEvent('CORRELATION_GAP',name,reason)

::routine correlationDetail
  use strict arg e
  signal on syntax name bad
  d=.JSON~fromJSON(e~detail)
  if d~isA(.Directory) then return d
bad: return .nil
::routine correlationEvent
  use strict arg kind,subject,detail
  out=.Directory~new;out['KIND']=kind;out['SUBJECT']=subject;out['DETAIL']=detail;return out
