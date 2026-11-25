/* Architecture: Tom Dyer. Coding: ChatGPT. Trusted, single-owner observation layer. */
::requires 'ProcessProvider.cls'
::requires 'ShellEventRuntime.cls'

::class SecurityProcessProbe public
::method init
  expose proc
  use strict arg proc
  if \proc~isA(.NativeObservedProcess) then raise syntax 93.900 array ('Observed process required')
::method snapshot
  expose proc
  return proc~securitySnapshot

::class SecurityPortProbe public
::method init
  expose port protocol
  use strict arg port, protocol = 'tcp'
  if \port~datatype('W') | port < 1 | port > 65535 | (protocol \== 'tcp' & protocol \== 'udp') then raise syntax 93.900 array ('Invalid port or protocol')
::method snapshot
  expose port protocol
  return .POSIXProvider~new~portSnapshot(port,protocol)

/* One registered metric. No synthetic zero for missing metrics. Signed deltas
   are observations over elapsed time, not rates of packet transfer. */
::class SecurityProcessPortProbe public
::method init
  expose proc port protocol
  use strict arg proc, port, protocol = 'tcp'
  if \proc~isA(.NativeObservedProcess) then raise syntax 93.900 array ('Observed process required')
  if \port~datatype('W') | port < 1 | port > 65535 | (protocol \== 'tcp' & protocol \== 'udp') then raise syntax 93.900 array ('Invalid port or protocol')
::method snapshot
  expose proc port protocol
  return proc~portSnapshot(port,protocol)

::class SecurityMetric public
::method init
  expose name probe metric high low delta maxGap previous previousTime identity above samples seen
  use strict arg name, probe, metric, high, low, delta, maxGap = 10000
  numeric digits 25
  if \metricName(name) then raise syntax 93.900 array ('Invalid metric name')
  if \.Array~of('RSS_KIB','PEAK_RSS_KIB','VIRTUAL_KIB','SWAP_KIB','ANON_KIB','FILE_KIB','SHMEM_KIB','SOCKET_COUNT','ESTABLISHED_COUNT','LISTENER_COUNT','RX_QUEUE','TX_QUEUE','TCP_ACKED_BPS','TCP_RECEIVED_BPS')~hasItem(metric) then raise syntax 93.900 array ('Unsupported metric')
  do x over .Array~of(high,low,delta,maxGap)
    if \x~datatype('W') | x < 0 | x > 18446744073709551615 then raise syntax 93.900 array ('Invalid metric bound')
  end
  if low >= high | delta = 0 | maxGap = 0 then raise syntax 93.900 array ('Invalid hysteresis or delta')
  previous = .nil; previousTime = .nil; identity = .nil; above = .false
  samples = .Queue~new; seen = 0
::attribute name get
::method sample
  expose probe
  use strict arg expirations = 1
  return self~evaluate(probe~snapshot,expirations)
::method evaluate
  expose name metric high low delta maxGap previous previousTime identity above
  use strict arg row, expirations = 1
  numeric digits 25
  events = .Array~new
  if \row['OK'] | \row~hasIndex(metric) | \row~hasIndex('IDENTITY') | \row~hasIndex('MONO_MS') then do
    previous = .nil; above = .false
    events~append(metricEvent('SAMPLE_GAP',name,'unavailable'))
    self~remember(row,'GAP')
    return events
  end
  value = row[metric]; stamp = row['MONO_MS']; id = row['IDENTITY']
  if \value~datatype('W') | value < 0 | \stamp~datatype('W') | stamp < 0 then raise syntax 93.900 array ('Invalid sample')
  info = .Directory~new; info['METRIC'] = metric; info['IDENTITY'] = id; info['VALUE'] = value; info['MONO_MS'] = stamp; info['ABOVE_HIGH'] = value >= high
  do k over .Array~of('AUID','UID','EUID','AUDIT_SESSION','PID','PPID','BOOT_ID','NET_NAMESPACE','PROTOCOL','PORT','PROCESS_IDENTITY','SCOPE','EPOCH_MS')
    if row~hasIndex(k) then info[k] = row[k]
  end
  if previous == .nil | identity \== id | expirations > 1 then do
    if previous \== .nil | expirations > 1 then events~append(metricEvent('SAMPLE_GAP',name,'identity change or missed intervals'))
    previous = value; previousTime = stamp; identity = id; above = value >= high
    events~append(metricEvent('METRIC_BASELINE',name,.JSON~toJSON(info)))
    self~remember(row,'BASELINE')
    return events
  end
  elapsed = stamp - previousTime
  if elapsed <= 0 | elapsed > maxGap then do
    previous = value; previousTime = stamp; above = value >= high
    events~append(metricEvent('SAMPLE_GAP',name,'invalid or excessive sample interval'))
    self~remember(row,'GAP')
    return events
  end
  change = value - previous; info['PREVIOUS'] = previous; info['DELTA'] = change; info['ELAPSED_MS'] = elapsed
  text = .JSON~toJSON(info)
  if change >= delta then events~append(metricEvent('METRIC_RISE',name,text))
  if change <= -delta then events~append(metricEvent('METRIC_FALL',name,text))
  if \above & value >= high then do; above = .true; events~append(metricEvent('METRIC_HIGH',name,text)); end
  if above & value <= low then do; above = .false; events~append(metricEvent('METRIC_RECOVERED',name,text)); end
  self~remember(row,'OK',change,elapsed)
  previous = value; previousTime = stamp
  return events
::method remember private
  expose samples seen metric
  use strict arg row, status, delta = 'UNKNOWN', elapsed = 'UNKNOWN'
  numeric digits 25
  seen += 1
  data = .Directory~new; data['SEQUENCE']=seen; data['STATUS']=status; data['METRIC']=metric; data['DELTA']=delta; data['ELAPSED_MS']=elapsed
  do k over .Array~of('EPOCH_MS','MONO_MS','IDENTITY')
    if row~hasIndex(k) then data[k] = row[k]; else data[k] = 'UNKNOWN'
  end
  data['VALUE']='UNKNOWN'
  if row['OK'] & row~hasIndex(metric) then data['VALUE']=row[metric]
  samples~queue(.SecuritySample~new(data))
  if samples~items > 256 then samples~pull
::method history
  expose samples
  return .ShellCollection~new(samples~makeArray)
::method historyDropped
  expose seen samples
  numeric digits 25
  return seen - samples~items

::class SecuritySample public inherit ShellObject
::method init
  expose data
  use strict arg input
  data=input~copy
::method fields
  return .Array~of('SEQUENCE','STATUS','METRIC','EPOCH_MS','MONO_MS','VALUE','DELTA','ELAPSED_MS','IDENTITY')
::method field
  expose data
  use strict arg key
  return data[key]

/* Privilege/identity transitions are independent of memory growth. */
::class SecurityIdentityMetric public
::method init
  expose name probe previous
  use strict arg name, probe
  if \metricName(name) then raise syntax 93.900 array ('Invalid identity metric name')
  previous = .nil
::attribute name get
::method sample
  expose probe
  use strict arg expirations = 1
  return self~evaluate(probe~snapshot,expirations)
::method evaluate
  expose name previous
  use strict arg row, expirations = 1
  out = .Array~new
  if \row['OK'] | \row~hasIndex('IDENTITY') then do
    previous = .nil; out~append(metricEvent('SAMPLE_GAP',name,'identity unavailable')); return out
  end
  fields = .Array~of('UID','EUID','AUID','AUDIT_SESSION','NET_NAMESPACE')
  now = .Directory~new; now['IDENTITY'] = row['IDENTITY']; now['MONO_MS'] = row['MONO_MS']; if row~hasIndex('EPOCH_MS') then now['EPOCH_MS'] = row['EPOCH_MS']
  do k over .Array~of('BOOT_ID','PID','PPID')
    if row~hasIndex(k) then now[k] = row[k]
  end
  do k over fields
    if \row~hasIndex(k) then now[k] = 'UNKNOWN'
    else now[k] = row[k]
  end
  reset = previous == .nil | expirations > 1
  if previous \== .nil then if previous['IDENTITY'] \== now['IDENTITY'] then reset = .true
  if reset then do
    if previous \== .nil | expirations > 1 then out~append(metricEvent('SAMPLE_GAP',name,'identity change or missed intervals'))
    previous = now; out~append(metricEvent('METRIC_BASELINE',name,.JSON~toJSON(now))); return out
  end
  changed = .Directory~new
  do k over fields
    if previous[k] == now[k] then iterate
    if previous[k] == 'UNKNOWN' | now[k] == 'UNKNOWN' then do
      out~append(metricEvent('SAMPLE_GAP',name,'field availability changed: 'k)); iterate
    end
    changed[k] = .Array~of(previous[k],now[k])
  end
  if changed~items > 0 then do
    now['CHANGES'] = changed; out~append(metricEvent('IDENTITY_CHANGE',name,.JSON~toJSON(now))); now~remove('CHANGES')
  end
  previous = now
  return out

::class SecuritySampler public
::method init
  expose metrics
  metrics = .Directory~new
::method register
  expose metrics
  use strict arg metric
  if \metric~isA(.SecurityMetric) & \metric~isA(.SecurityIdentityMetric) then raise syntax 93.900 array ('Metric required')
  if metrics~items >= 32 | metrics~hasIndex(metric~name) then raise syntax 93.900 array ('Duplicate or full metric registry')
  metrics[metric~name] = metric
::method metric
  expose metrics
  use strict arg name
  return metrics~at(name)
::method hasMetric
  expose metrics
  use strict arg name
  return metrics~hasIndex(name)
::method sample
  expose metrics
  use strict arg expirations = 1
  out = .Array~new
  do m over metrics~allItems
    do e over m~sample(expirations); out~append(e); end
  end
  return out

/* Input is a normalized record from the owning trusted audit collector, not
   a line of application-supplied syslog. No passwords, tokens or raw payloads. */
::class PamAuditAdapter public
::method init
  expose boot seen order
  use strict arg boot
  if \boot~isA(.String) | boot~length \= 36 | boot~verify('0123456789abcdef-') \= 0 then raise syntax 93.900 array ('Invalid boot identity')
  seen = .Directory~new; order = .Queue~new
::method parseAuditLine
  expose boot
  use strict arg line
  numeric digits 25
  if \line~isA(.String) | line~length > 16384 | line~pos('0a'x) > 0 | line~pos('00'x) > 0 then raise syntax 93.900 array ('Invalid audit line')
  /* Strict canonical auditd USER_* layout, not a general auparse replacement. */
  if line~left(5) \== 'type=' then raise syntax 93.900 array ('Expected auditd type')
  parse var line 'type=' typ ' msg=audit(' epoch ':' serial '): pid=' pid ' uid=' uid ' auid=' auid ' ses=' ses " msg='" payload
  if payload~right(1) \== "'" then raise syntax 93.900 array ('Expected quoted PAM payload')
  payload = payload~left(payload~length-1)
  if payload~left(7) \== 'op=PAM:' then raise syntax 93.900 array ('Not a PAM operation')
  operation = payload~word(1)
  select
    when typ == 'USER_AUTH' then expected = 'op=PAM:authentication'
    when typ == 'USER_ACCT' then expected = 'op=PAM:accounting'
    when typ == 'USER_START' then expected = 'op=PAM:session_open'
    when typ == 'USER_END' then expected = 'op=PAM:session_close'
    when typ == 'CRED_ACQ' | typ == 'CRED_DISP' then expected = 'op=PAM:setcred'
    otherwise raise syntax 93.900 array ('Unsupported audit type')
  end
  if operation \== expected then raise syntax 93.900 array ('PAM type/operation mismatch')
  res = payload~word(payload~words)
  if res \== 'res=success' & res \== 'res=failed' then raise syntax 93.900 array ('Missing terminal PAM result')
  parse var epoch sec '.' milli
  if sec~length = 0 | sec~length > 15 | sec~verify('0123456789') \= 0 | milli~length \= 3 | milli~verify('0123456789') \= 0 then raise syntax 93.900 array ('Invalid audit timestamp')
  r = .Directory~new; r['BOOT_ID']=boot; r['ORIGIN']='PAM'; r['TYPE']=typ; r['SERIAL']=serial; r['EPOCH_MS']=sec*1000+milli
  r['PID']=pid; r['UID']=uid; r['AUID']=auid; r['SESSION']=ses; r['RESULT']=res~substr(5)
  return r
::method normalize
  expose boot seen order
  use strict arg row
  numeric digits 25
  if row['TYPE'] == 'GAP' then return metricEvent('AUDIT_GAP','','collector reported loss')
  if row['BOOT_ID'] \== boot then raise syntax 93.900 array ('Audit boot identity mismatch')
  if row['ORIGIN'] \== 'PAM' then raise syntax 93.900 array ('Expected normalized PAM provenance')
  do k over .Array~of('SERIAL','EPOCH_MS','PID','UID','AUID','SESSION')
    v = row[k]
    if (k == 'AUID' | k == 'SESSION') & (v == 'UNSET' | v == 'UNKNOWN') then iterate
    if \v~isA(.String) | v~length = 0 | v~length > 20 | v~verify('0123456789') \= 0 | v < 0 | v > 18446744073709551615 then raise syntax 93.900 array ('Invalid audit field' k)
  end
  if row['PID'] < 1 | row['PID'] > 2147483647 | row['UID'] > 4294967295 then raise syntax 93.900 array ('Invalid audit process identity')
  if row['RESULT'] \== 'success' & row['RESULT'] \== 'failed' then raise syntax 93.900 array ('Invalid audit result')
  select
    when row['TYPE'] == 'USER_AUTH' then base = 'PAM_AUTH'
    when row['TYPE'] == 'USER_ACCT' then base = 'PAM_ACCOUNT'
    when row['TYPE'] == 'USER_START' then base = 'PAM_SESSION_OPEN'
    when row['TYPE'] == 'USER_END' then base = 'PAM_SESSION_CLOSE'
    when row['TYPE'] == 'CRED_ACQ' then base = 'PAM_CREDENTIAL_ACQUIRE'
    when row['TYPE'] == 'CRED_DISP' then base = 'PAM_CREDENTIAL_DISPOSE'
    otherwise raise syntax 93.900 array ('Unsupported PAM audit record')
  end
  if base == 'PAM_AUTH' | base == 'PAM_ACCOUNT' then do
    if row['RESULT'] == 'success' then base = base'_SUCCESS'
    else base = base'_FAILURE'
  end
  else if row['RESULT'] == 'failed' then base = 'PAM_OPERATION_FAILED'
  do k over .Array~of('AUID','SESSION')
    v = row[k]
    if v \== 'UNKNOWN' & v \== 'UNSET' then if v > 4294967295 then raise syntax 93.900 array ('Audit UID/session out of range')
  end
  id = boot||':'||(row['EPOCH_MS']+0)||':'||(row['SERIAL']+0)||':'||row['TYPE']
  if seen~hasIndex(id) then return metricEvent('AUDIT_DUPLICATE','','')
  seen[id] = 1; order~queue(id)
  if order~items > 1024 then seen~remove(order~pull)
  info = .Directory~new
  do k over .Array~of('BOOT_ID','SERIAL','EPOCH_MS','PID','UID','AUID','SESSION','TYPE','RESULT')
    v = row[k]
    if (k == 'AUID' | k == 'SESSION') then do
      if v \== 'UNKNOWN' & v \== 'UNSET' then do; if v = 4294967295 then v = 'UNSET'; else v = v+0; end
    end
    else if .Array~of('SERIAL','EPOCH_MS','PID','UID')~hasItem(k) then v = v+0
    info[k] = v
  end
  info['AUDIT_ID'] = id; info['PROCESS_LINK'] = 'UNVERIFIED'
  return metricEvent(base,id,.JSON~toJSON(info))

/* Optional local append-only auditd text log adapter. Starts at EOF, no
   historical actions. Trusted collector/root only. Rotation/loss fails closed;
   explicit reattachment and reconciliation required. */
::class PamAuditLogTail public
::method init
  expose root name adapter watch reader offset pending inode device closed
  use strict arg root, name, adapter
  closed = .true; watch = .nil; reader = .nil
  if \name~isA(.String) | name == '' | name == '.' | name == '..' | name~pos('/') > 0 then raise syntax 93.900 array ('Single audit log filename required')
  if \root~isA(.POSIXRoot) | \adapter~isA(.PamAuditAdapter) then raise syntax 93.900 array ('Trusted root and PAM adapter required')
  w = root~watch('.'); if \w['OK'] then raise syntax 93.900 array ('Audit directory watch failed')
  watch = w['WATCH']
  r = root~openReader(name)
  if \r['OK'] then do; watch~close; raise syntax 93.900 array ('Audit log open failed'); end
  reader = r['READER']; r = reader~stat
  if \r['OK'] then do; reader~close; watch~close; raise syntax 93.900 array ('Audit log stat failed'); end
  offset = r['SIZE']; inode = r['INODE']; device = r['DEVICE']; pending = ''; closed = .false
  if offset > 0 then do
    r = reader~readAt(offset-1,1)
    if \r['OK'] | r['DATA'] \== '0a'x then do; self~close; raise syntax 93.900 array ('Audit log not at a complete record boundary'); end
  end
::attribute watch get
::method readBatch
  expose root name adapter reader offset pending inode device closed
  use strict arg events
  numeric digits 25
  if closed then return auditTailResult('closed')
  relevant = .false
  do e over events
    if e['NAME'] \== name then iterate
    do k over e['KINDS']
      if .Array~of('DELETE','MOVED_FROM','MOVED_TO','CREATE','ATTRIB')~hasItem(k) then return auditTailResult('audit log identity or metadata changed')
      if k == 'MODIFY' | k == 'CLOSE_WRITE' then relevant = .true
    end
  end
  if \relevant then return auditTailResult('')
  before = root~stat(name)
  if \before['OK'] | before['INODE'] \== inode | before['DEVICE'] \== device then return auditTailResult('audit log replaced')
  if before['SIZE'] < offset then return auditTailResult('audit log truncated')
  n = before['SIZE'] - offset
  if n = 0 then return auditTailResult('')
  if n > 65536 then return auditTailResult('audit log backlog exceeds bounded batch')
  r = reader~readAt(offset,n)
  if \r['OK'] | r['BYTES'] \= n then return auditTailResult('audit log short read')
  after = root~stat(name)
  if \after['OK'] | after['INODE'] \== inode | after['DEVICE'] \== device | after['SIZE'] < offset+n then return auditTailResult('audit log changed during read')
  offset += n; pending = pending||r['DATA']; out = auditTailResult('')
  signal on syntax name malformed
  do forever
    i = pending~pos('0a'x)
    if i = 0 then leave
    line = pending~left(i-1); pending = pending~substr(i+1)
    if line~length > 16384 then return auditTailResult('audit record exceeds bounded length')
    if line~left(12) == 'type=DAEMON_' then return auditTailResult('audit daemon lifecycle record')
    if line~pos('op=PAM:') = 0 then iterate
    row = adapter~normalize(adapter~parseAuditLine(line))
    out['RECORDS']~append(row)
    if out['RECORDS']~items > 256 then return auditTailResult('too many audit records in batch')
  end
  if pending~length > 16384 then return auditTailResult('partial record exceeds bounded length')
  return out
malformed: return auditTailResult('unsupported or malformed PAM record')
::method close
  expose reader watch closed
  if closed then return .false
  closed = .true; reader~close; watch~close; return .true
::method uninit
  expose closed
  if symbol('CLOSED') == 'VAR' then if \closed then self~close
::routine auditTailResult
  use strict arg error
  r = .Directory~new;r['GAP'] = error \== '';r['ERROR'] = error;r['RECORDS'] = .Array~new;return r

/* Read-only bounded journal projections. A session match is association, not
   proof of exact PAM process lifetime or causation. No dispatch from replay. */
::class SecurityEvidenceView public
::method init
  expose journal
  use strict arg journal
  if \journal~isA(.ShellEventJournal) then raise syntax 93.900 array ('Journal required')
::method sessionTrail
  expose journal
  use strict arg boot, auid, session, after = 0, limit = 128
  if auid == 'UNSET' | auid == 'UNKNOWN' | session == 'UNSET' | session == 'UNKNOWN' | auid = 4294967295 | session = 4294967295 then raise syntax 93.900 array ('Known audit identity and session required')
  if \auid~datatype('W') | \session~datatype('W') | auid < 0 | session < 0 then raise syntax 93.900 array ('Invalid audit identity')
  page = journal~replay(after,limit); rows = .Array~new
  do e over page['EVENTS']
    info = evidenceDetail(e)
    if info == .nil then iterate
    sid = info['SESSION']; if sid == .nil then sid = info['AUDIT_SESSION']
    if info['BOOT_ID'] == boot & info['AUID'] == auid & sid == session then rows~append(e)
  end
  page['EVENTS'] = rows; return page
::method processTrail
  expose journal
  use strict arg identity, after = 0, limit = 128
  if \identity~isA(.String) | identity == '' then raise syntax 93.900 array ('Process identity required')
  page = journal~replay(after,limit); rows = .Array~new
  do e over page['EVENTS']
    info = evidenceDetail(e)
    if info == .nil then iterate
    if info['IDENTITY'] == identity | info['PROCESS_IDENTITY'] == identity then rows~append(e)
  end
  page['EVENTS'] = rows; return page
::routine evidenceDetail
  use strict arg e
  if e~detail~left(1) \== '{' then return .nil
  signal on syntax name bad
  info = .JSON~fromJSON(e~detail)
  if \info~isA(.Directory) then return .nil
  return info
bad: return .nil

::routine metricName
  use strict arg name
  return name~isA(.String) & name~length > 0 & name~length <= 64 & name~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-') = 0
::routine metricEvent
  use strict arg kind, subject, detail
  r = .Directory~new; r['KIND'] = kind; r['SUBJECT'] = subject; r['DETAIL'] = detail
  return r
