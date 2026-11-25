/* Architecture: Tom Dyer. Coding: ChatGPT.
   Trusted host integration, NOT a proposal-facing capability.
   Single owner activity for dispatch; the native mux may be woken separately.
   Observations are not authorisation. Replay never executes actions. */
::requires 'POSIXProvider.cls'
::requires 'ShellJobs.cls'
::requires 'KernelLogging.cls'

::class ShellEventRecord public inherit ShellObject
::method init
  expose session sequence source kind subject count cause detail observed
  use strict arg session, sequence, source, kind, subject, count, cause, detail
  observed = date('S') time('L')
::attribute session get
::attribute sequence get
::attribute source get
::attribute kind get
::attribute subject get
::attribute count get
::attribute cause get
::attribute detail get
::attribute observed get
::method identity
  return self~session':'self~sequence
::method fields
  return .Array~of('session','sequence','source','kind','subject','count','cause','detail','observed')

/* Bounded observation journal. The cursor is the last sequence consumed.
   A lost retention interval is explicit, not silently replayed. */
::class ShellEventJournal public
::method init
  expose session capacity records seq
  use strict arg session, capacity = 4096
  if \eventIdValid(session) then raise syntax 93.900 array ('Invalid session identity')
  if \capacity~datatype('W') | capacity < 1 | capacity > 65536 then raise syntax 93.900 array ('Invalid journal capacity')
  records = .Directory~new; seq = 0
::method append
  expose session capacity records seq
  use strict arg source, kind, subject = '', count = 1, cause = '', detail = ''
  numeric digits 25
  if \source~isA(.String) | \kind~isA(.String) | \subject~isA(.String) | \cause~isA(.String) | \detail~isA(.String) then raise syntax 93.900 array ('Event fields must be scalar strings')
  if source~length > 128 | kind~length > 64 | subject~length > 1024 | cause~length > 256 | detail~length > 1024 then raise syntax 93.900 array ('Event field limit exceeded')
  if \count~datatype('W') | count < 0 | count > 18446744073709551615 then raise syntax 93.900 array ('Invalid event count')
  if seq >= 999999999999999 then raise syntax 93.900 array ('Event sequence exhausted')
  seq += 1
  rec = .ShellEventRecord~new(session, seq, source, kind, subject, count, cause, detail)
  records[seq] = rec
  if seq > capacity then records~remove(seq - capacity)
  return rec
::method latest
  expose seq
  return seq
::method replay
  expose session capacity records seq
  use strict arg after = 0, limit = 128
  numeric digits 25
  if \after~datatype('W') | after < 0 | after > seq then raise syntax 93.900 array ('Invalid replay cursor')
  if \limit~datatype('W') | limit < 1 | limit > 1024 then raise syntax 93.900 array ('Invalid replay limit')
  first = max(1, seq - capacity + 1)
  gap = after < first - 1
  next = max(after, first - 1)
  rows = .Array~new
  do i = next + 1 to min(seq, next + limit)
    rows~append(records[i]); next = i
  end
  out = .Directory~new
  out['SESSION'] = session; out['FIRST'] = first; out['LATEST'] = seq
  out['GAP'] = gap; out['NEXT'] = next; out['EVENTS'] = rows
  return out
::method exportPage
  use strict arg after = 0, limit = 128
  page = self~replay(after, limit)
  rows = .Array~new
  do rec over page['EVENTS']; rows~append(.JSON~fromJSON(rec~asJson)); end
  page['EVENTS'] = rows
  return .JSON~toJSON(page)

/* Internal rule, not constructed from event content. Holds a structural copy of a trusted plan template; single-use per registration. */
::class ShellEventRule public
::method init
  expose name source kind subject template state
  use strict arg name, source, kind, subject, template
  state = 'ARMED'
::attribute name get
::attribute source get
::attribute kind get
::attribute subject get
::attribute state get
::method matches
  use strict arg rec
  return self~state == 'ARMED' & self~source == rec~source & self~kind == rec~kind & (self~subject == '' | self~subject == rec~subject)
::method disarm
  expose state
  if state == 'ARMED' then state = 'DISARMED'
::method makePlan
  expose template state
  use strict arg board, jobName
  if state \== 'ARMED' then raise syntax 93.900 array ('Rule not armed')
  state = 'FIRED'
  plan = board~plan(jobName)
  do step over template~steps
    plan~adoptStep(step~copyStep)
  end
  return plan

::class ShellEventRuntime public
::method init
  expose mux journal board principal sources rules pending closed dispatched maxDispatch observationLogger
  use strict arg session, owner, capacity = 4096, maxDispatch = 128
  if owner == .nil then raise syntax 93.900 array ('Explicit job owner required')
  if \maxDispatch~datatype('W') | maxDispatch < 1 | maxDispatch > 128 then raise syntax 93.900 array ('Invalid dispatch limit')
  principal = owner~principal
  if \.Array~of('llm','codex','console')~hasItem(principal) then raise syntax 93.900 array ('Invalid principal')
  journal = .ShellEventJournal~new(session, capacity)
  board = .JobBoard~new(owner)
  sources = .Directory~new; rules = .Directory~new; pending = .Directory~new; dispatched = 0
  r = .POSIXProvider~new~openEventMux
  if \r['OK'] then raise syntax 93.900 array ('Cannot open event mux')
  mux = r['MUX']; closed = .false; observationLogger = .nil
/* Optional trusted deployment binding. Thin MU config must bind before arming. */
::method setObservationLogger
  expose observationLogger rules sources
  use strict arg bridge
  if rules~items > 0 | sources~items > 0 then raise syntax 93.900 array ('Bind logging before attaching sources')
  if \bridge~isA(.KernelLogBridge) then raise syntax 93.900 array ('Kernel log bridge required')
  observationLogger=bridge
  return self
::attribute journal get
::attribute board get
::method attach
  expose mux sources closed journal
  use strict arg label, source
  if closed then raise syntax 93.900 array ('Runtime closed')
  if sources~items >= 128 then raise syntax 93.900 array ('Source registry full')
  if \eventIdValid(label) then raise syntax 93.900 array ('Invalid source label')
  do item over sources~allItems
    if item['LABEL'] == label then raise syntax 93.900 array ('Duplicate source label')
  end
  r = mux~register(source)
  if \r['OK'] then return r
  entry = .Directory~new; entry['LABEL'] = label; entry['SOURCE'] = source
  sources[r['REGISTRATION']] = entry
  journal~append(label,'SOURCE_ATTACHED','',1,'',r['REGISTRATION'])
  return r
/* Trusted host only; never provide this runtime or the collector to proposals. */
::method attachKernelLog
  expose sources observationLogger
  use strict arg label, reader, includeText = .false
  if observationLogger==.nil then raise syntax 93.900 array ('Kernel logging binding required')
  if includeText & observationLogger~disclosure\==.Log~SECRET then raise syntax 93.900 array ('Kernel message bytes require SECRET scope')
  if \reader~isA(.POSIXKernelLog) then raise syntax 93.900 array ('Kernel reader required')
  r=self~attach(label,reader)
  if r['OK'] then do
    e=sources[r['REGISTRATION']]; e['CATEGORY']='KERNEL_LOG'; e['LAST_SEQUENCE']=.nil; e['INCLUDE_TEXT']=includeText; e['AUDIT_DECODER']=.KernelAuditDecoder~new(observationLogger~bootId)
  end
  return r
/* The reader is read-only. Optional status polling requires separate
   CAP_AUDIT_CONTROL; alternatively the trusted control owner supplies status. */
::method attachAuditNetlink
  expose sources observationLogger
  use strict arg label, reader, pollStatus=.false
  if observationLogger==.nil then raise syntax 93.900 array ('Logging binding required')
  if \reader~isA(.POSIXAuditReader) then raise syntax 93.900 array ('Audit multicast reader required')
  r=self~attach(label,reader)
  if r['OK'] then do
    e=sources[r['REGISTRATION']]; e['CATEGORY']='AUDIT_NETLINK'; e['AUDIT_DECODER']=.KernelAuditDecoder~new(observationLogger~bootId)
    e['LOSS_MONITOR']=.AuditLossMonitor~new; e['POLL_STATUS']=pollStatus; e['STATUS_DUE']=0
    if pollStatus then self~auditStatusObserved(label,.POSIXProvider~new~auditStatus)
  end
  return r
::method auditStatusObserved
  expose sources
  use strict arg label,status
  do e over sources~allItems
    if e['LABEL']==label & e['CATEGORY']=='AUDIT_NETLINK' then do
      r=e['LOSS_MONITOR']~observe(status)
      if r['GAP'] then self~kernelGap(label,r['REASON'])
      return r
    end
  end
  raise syntax 93.900 array ('Audit multicast source not registered')
::method attachSampler
  expose sources
  use strict arg label, timer, sampler
  if \timer~isA(.POSIXTimer) then raise syntax 93.900 array ('Timer required')
  r = self~attach(label,timer)
  if r['OK'] then do
    entry = sources[r['REGISTRATION']]
    entry['CATEGORY'] = 'METRIC'; entry['SAMPLER'] = sampler
  end
  return r
::method attachAudit
  expose sources closed journal
  use strict arg label, adapter
  if closed | \eventIdValid(label) | sources~items >= 128 then raise syntax 93.900 array ('Invalid audit registration')
  do item over sources~allItems
    if item['LABEL'] == label then raise syntax 93.900 array ('Duplicate source label')
  end
  entry = .Directory~new; entry['LABEL'] = label; entry['CATEGORY'] = 'AUDIT'; entry['SOURCE'] = adapter
  sources['ext:'label] = entry
  journal~append(label,'SOURCE_ATTACHED','','1','','trusted audit collector')
  return 'ext:'label
::method attachAuditLog
  expose sources
  use strict arg label, tail
  r = self~attach(label,tail~watch)
  if r['OK'] then do
    entry = sources[r['REGISTRATION']]
    entry['CATEGORY'] = 'AUDITLOG'; entry['TAIL'] = tail
  end
  return r
::method ingestAudit
  expose sources closed journal
  use strict arg label, record, logOrigin = ''
  if closed then raise syntax 93.900 array ('Runtime closed')
  entry = sources~at('ext:'label)
  if entry == .nil then raise syntax 93.900 array ('Unregistered audit collector')
  r = entry['SOURCE']~normalize(record)
  if r['KIND'] == 'AUDIT_GAP' then do
    journal~append(label,'AUDIT_GAP','','1','',r['DETAIL'])
    self~detach('ext:'label)
  end
  else if r['KIND'] == 'AUDIT_DUPLICATE' then journal~append(label,'AUDIT_DUPLICATE')
  else self~observe(label,r['KIND'],r['SUBJECT'],1,r['DETAIL'],logOrigin)
  self~collectCorrelations
  return r['KIND']
::method attachCorrelation
  expose sources closed journal
  use strict arg label, correlation
  if closed | \eventIdValid(label) | sources~items >= 128 then raise syntax 93.900 array ('Invalid correlation registration')
  a=.nil; m=.nil
  do entry over sources~allItems
    if entry['LABEL']==label then raise syntax 93.900 array ('Duplicate source label')
    if entry['LABEL']==correlation~auditSource then a=entry
    if entry['LABEL']==correlation~metricSource then m=entry
  end
  if a==.nil | m==.nil then raise syntax 93.900 array ('Missing correlation input')
  if (a['CATEGORY']\=='AUDIT' & a['CATEGORY']\=='AUDITLOG') | m['CATEGORY']\=='METRIC' then raise syntax 93.900 array ('Invalid correlation input type')
  do subject over correlation~subjects
    if \m['SAMPLER']~hasMetric(subject) then raise syntax 93.900 array ('Unknown correlation metric')
  end
  correlation~bind(journal)
  entry=.Directory~new;entry['LABEL']=label;entry['CATEGORY']='CORRELATION';entry['SOURCE']=correlation
  sources['ext:'label]=entry
  journal~append(label,'SOURCE_ATTACHED','',1,'','trusted correlation')
  return 'ext:'label
::method collectCorrelations
  expose sources closed journal
  if closed then return 0
  n=0
  do id over sources~allIndexes
    entry=sources[id]
    if entry['CATEGORY']\=='CORRELATION' then iterate
    r=entry['SOURCE']~consume
    if r==.nil then iterate
    if r['KIND']=='CORRELATION_GAP' then do
      journal~append(entry['LABEL'],r['KIND'],r['SUBJECT'],1,'',r['DETAIL']); self~detach(id)
    end
    else do
      self~observe(entry['LABEL'],r['KIND'],r['SUBJECT'],1,r['DETAIL']); n+=1; self~detach(id)
    end
  end
  return n
::method detach
  expose mux sources journal rules
  use strict arg id
  entry = sources~at(id)
  if entry == .nil then return .false
  if id~left(4) \== "ext:" then mux~unregister(id)
  sources~remove(id)
  do rule over rules~allItems
    if rule~source == entry['LABEL'] then rule~disarm
  end
  journal~append(entry['LABEL'],'SOURCE_DETACHED','',1,'',id)
  return .true
::method arm
  expose rules sources closed journal
  use strict arg name, source, kind, template, subject = ''
  if closed then raise syntax 93.900 array ('Runtime closed')
  if \eventIdValid(name) | rules~items >= 128 | rules~hasIndex(name) then raise syntax 93.900 array ('Invalid or duplicate rule, or rule registry full')
  found = .false
  do entry over sources~allItems
    if entry['LABEL'] == source then do
      found = .true
      obj = entry['SOURCE']
      category = entry['CATEGORY']
    end
  end
  if \found then raise syntax 93.900 array ('Unknown source')
  if category == 'METRIC' then do
    if \.Array~of('METRIC_RISE','METRIC_FALL','METRIC_HIGH','METRIC_RECOVERED','IDENTITY_CHANGE')~hasItem(kind) | subject == '' then raise syntax 93.900 array ('Expected metric event and exact metric subject')
    if \entryHasMetric(sources,source,subject) then raise syntax 93.900 array ('Unknown metric')
  end
  else if category == 'CORRELATION' then do
    if kind \== 'INCIDENT_MATCH' | subject \== obj~name then raise syntax 93.900 array ('Exact incident correlation required')
  end
  else if category == 'AUDIT' | category == 'AUDITLOG' then do
    if \.Array~of('PAM_AUTH_SUCCESS','PAM_AUTH_FAILURE','PAM_ACCOUNT_SUCCESS','PAM_ACCOUNT_FAILURE','PAM_SESSION_OPEN','PAM_SESSION_CLOSE','PAM_CREDENTIAL_ACQUIRE','PAM_CREDENTIAL_DISPOSE','PAM_OPERATION_FAILED')~hasItem(kind) then raise syntax 93.900 array ('Unsupported audit event')
    if subject \== '' then raise syntax 93.900 array ('Audit rule uses source and exact event kind')
  end
  else do
    select
      when kind == 'TIMER' then expected = .POSIXTimer
      when kind == 'PROCESS_EXIT' then expected = .POSIXProcessHandle
      when kind == 'FS_CLOSE_WRITE' | kind == 'FS_MOVED_TO' then expected = .POSIXWatch
      otherwise raise syntax 93.900 array ('Unsupported trigger kind')
    end
    if \obj~isA(expected) then raise syntax 93.900 array ('Trigger/source kind mismatch')
    if subject \== '' then do
      if expected \== .POSIXWatch | subject~left(2) \== 'x:' | subject~length < 4 | subject~length > 512 | subject~length // 2 \= 0 then raise syntax 93.900 array ('Expected filename byte identity x:HEX')
      if subject~substr(3)~verify('0123456789ABCDEF') \= 0 then raise syntax 93.900 array ('Expected uppercase hex filename')
    end
  end
  if \template~isA(.Plan) then raise syntax 93.900 array ('Plan template required')
  if template~stepCount = 0 then raise syntax 93.900 array ('Nonempty plan required')
  rule = .ShellEventRule~new(name,source,kind,subject,template~amend('template'))
  rules[name] = rule
  journal~append(source,'RULE_ARMED',name)
  return rule
::method disarm
  expose rules journal
  use strict arg name
  if \rules~hasIndex(name) then return .false
  rule = rules~remove(name); rule~disarm
  journal~append(rule~source,'RULE_DISARMED',name)
  return .true
::method pump
  expose mux sources journal closed observationLogger
  use strict arg milliseconds = 0
  numeric digits 25
  if closed then raise syntax 93.900 array ('Runtime closed')
  self~collectJobs
  do item over sources~allItems
    if item['CATEGORY']=='AUDIT_NETLINK' then if item['POLL_STATUS'] then do
      now=.POSIXProvider~new~clockSnapshot['MONO_MS']
      if now>=item['STATUS_DUE'] then do
        self~auditStatusObserved(item['LABEL'],.POSIXProvider~new~auditStatus)
        item['STATUS_DUE']=now+1000
      end
    end
  end
  out = mux~wait(milliseconds)
  if \out['OK'] then return out
  do e over out['EVENTS']
    id = e['REGISTRATION']; entry = sources~at(id)
    if entry == .nil then iterate
    label = entry['LABEL']; source = entry['SOURCE']
    if e['CLOSED'] | (e['ERROR_EVENT'] & e['KIND']\=='AUDIT_NETLINK') | (e['HANGUP'] & e['KIND']=='AUDIT_NETLINK') then do
      if entry['CATEGORY']=='AUDIT_NETLINK' then self~kernelGap(label,'audit multicast source lost')
      self~observe(label,'SOURCE_LOST','',1,'','',.false); self~detach(id); iterate
    end
    if \e['READY'] & \(e['KIND']=='AUDIT_NETLINK' & e['ERROR_EVENT']) then iterate
    select
      when e['KIND']=='AUDIT_NETLINK' then do
        do 32
          r=source~nextBatch
          if \r['OK'] then do
            self~kernelGap(label,'audit multicast read failure errno='r['ERRNO']); self~detach(id); leave
          end
          if r['GAP'] then do
            self~kernelGap(label,'audit multicast datagram loss'); iterate
          end
          if \r['READY'] then leave
          do row over r['RECORDS']
            a=entry['AUDIT_DECODER']~decodeNetlink(row['TYPE'],row['RECORD'])
            if a['GAP'] then self~kernelGap(label,'audit multicast evidence gap')
            if a['KIND']=='PAM' then if observationLogger~wants('PUBLISHPAM',a['RECORD']['TYPE']) then do
              receipt=observationLogger~publishPam(a['RECORD'])
              if \receipt['OK'] then self~kernelGap(label,'PAM delivery failed')
            end
          end
        end
      end
      when e['KIND'] == 'KERNEL_LOG' then do
        do 32
          if \sources~hasIndex(id) then leave
          r=source~nextRecord
          if \r['OK'] then do
            self~kernelGap(label,'read failure errno='r['ERRNO'])
            self~detach(id); leave
          end
          if r['GAP']==1 then do
            self~kernelGap(label,'kernel ring wrapped'); entry['LAST_SEQUENCE']=.nil; iterate
          end
          if \r['READY'] then leave
          d=decodeKernelRecord(r['RECORD'],entry['INCLUDE_TEXT'])
          if d==.nil then do
            self~kernelGap(label,'invalid printk header'); self~detach(id); leave
          end
          if entry['LAST_SEQUENCE']\==.nil then do
            if d['KERNEL_SEQUENCE']\=entry['LAST_SEQUENCE']+1 then do
              self~kernelGap(label,'sequence discontinuity')
            end
          end
          entry['LAST_SEQUENCE']=d['KERNEL_SEQUENCE']
          audit=entry['AUDIT_DECODER']~decode(r['RECORD'])
          if audit['GAP'] then self~kernelGap(label,'kernel audit evidence gap')
          if audit['KIND']=='PAM' then if observationLogger~wants('PUBLISHPAM',audit['RECORD']['TYPE']) then do
            ar=observationLogger~publishPam(audit['RECORD'])
            if \ar['OK'] then self~kernelGap(label,'PAM delivery failed')
          end
          if observationLogger~wants('PUBLISH','KERNEL_PRINTK') then self~observe(label,'KERNEL_PRINTK',d['KERNEL_SEQUENCE'],1,.JSON~toJSON(d))
        end
      end
      when e['KIND'] == 'TIMER' then do
        r = source~drain
        if \r['OK'] then do; self~observe(label,'SOURCE_LOST','',1,'','',.false); self~detach(id); iterate; end
        if r['EXPIRATIONS'] > 0 then do
          if entry['CATEGORY'] == 'METRIC' then do
            do m over entry['SAMPLER']~sample(r['EXPIRATIONS'])
              if \sources~hasIndex(id) then leave
              self~observe(label,m['KIND'],m['SUBJECT'],1,m['DETAIL'])
            end
          end
          else self~observe(label,'TIMER','',r['EXPIRATIONS'])
        end
      end
      when e['KIND'] == 'PROCESS' then do
        r = source~waitExit(0)
        if \r['OK'] then do; self~observe(label,'SOURCE_LOST','',1,'','',.false); self~detach(id); iterate; end
        if r['EXITED'] then do; self~observe(label,'PROCESS_EXIT'); self~detach(id); end
      end
      when e['KIND'] == 'FILESYSTEM' then do
        r = source~nextBatch(128)
        if \r['OK'] then do; self~observe(label,'SOURCE_LOST','',1,'','',.false); self~detach(id); iterate; end
        if r['RESCAN_REQUIRED'] then do
          if entry['CATEGORY'] == 'AUDITLOG' then self~observe(label,'AUDIT_GAP','',1,'audit watch invalidated','',.false)
          self~observe(label,'RESCAN_REQUIRED','',1,'Watch quarantined; reconcile before rearming','',.false)
          self~detach(id); iterate
        end
        if entry['CATEGORY'] == 'AUDITLOG' then do
          a = entry['TAIL']~readBatch(r['EVENTS'])
          if a['GAP'] then do
            self~observe(label,'AUDIT_GAP','',1,a['ERROR'],'',.false); self~detach(id); iterate
          end
          do row over a['RECORDS']
            if row['KIND'] == 'AUDIT_DUPLICATE' then journal~append(label,'AUDIT_DUPLICATE')
            else self~observe(label,row['KIND'],row['SUBJECT'],1,row['DETAIL'])
          end
          iterate
        end
        do f over r['EVENTS']
          if \sources~hasIndex(id) then leave
          /* Native names are bytes. Hex is lossless, including invalid UTF-8. */
          do k over f['KINDS']
            if \sources~hasIndex(id) then leave
            if k == 'CLOSE_WRITE' | k == 'MOVED_TO' then do
              if \f['IS_DIRECTORY'] then self~observe(label,'FS_'k,'x:'f['NAME']~c2x,1,f['COOKIE'])
              else self~observe(label,'DIR_'k,'x:'f['NAME']~c2x,1,f['COOKIE'],'',.false)
            end
            else self~observe(label,'FS_'k,'x:'f['NAME']~c2x,1,f['COOKIE'],'',.false)
          end
        end
      end
      otherwise journal~append(label,'UNKNOWN_SOURCE')
    end
  end
  self~collectCorrelations
  self~collectJobs
  return out
::method observe private
  expose journal rules pending board principal dispatched maxDispatch observationLogger sources
  use strict arg label, kind, subject = '', count = 1, detail = '', logOrigin = '', dispatch = .true
  cause=logOrigin
  if observationLogger\==.nil & logOrigin=='' then do
    logged=publishObservation(observationLogger,label,kind,subject,count,detail)
    cause=logged['INGRESS_ID']
    if \logged['OK'] then do
      rec=journal~append(label,'LOG_DELIVERY_GAP',subject,1,cause,'No active logging target accepted observation')
      do rule over rules~allItems; if rule~source==label then rule~disarm; end
      do id over sources~allIndexes
        if sources[id]['LABEL']\==label then iterate
        category=sources[id]['CATEGORY']
        if category=='METRIC' then journal~append(label,'SAMPLE_GAP',subject,1,cause,'Logging delivery failed')
        if category=='AUDIT' | category=='AUDITLOG' then journal~append(label,'AUDIT_GAP','',1,cause,'Logging delivery failed')
        if category\=='KERNEL_LOG' then self~detach(id)
      end
      return rec
    end
  end
  rec = journal~append(label,kind,subject,count,cause,detail)
  if \dispatch then return rec
  do rule over rules~allItems
    if \rule~matches(rec) then iterate
    /* No executable text, method name or argument taken from the observation. */
    jobName = rec~identity':'rule~name
    if dispatched >= maxDispatch then do
      rule~disarm
      journal~append(label,'DISPATCH_LIMIT',rule~name,1,rec~identity,jobName)
      iterate
    end
    dispatched += 1
    plan = rule~makePlan(board,jobName)
    journal~append(label,'DISPATCH_ATTEMPT',rule~name,1,rec~identity,jobName)
    receipt = submitEventPlan(board,plan,principal)
    journal~append(label,receipt,rule~name,1,rec~identity,jobName)
    if receipt == 'SUBMITTED' then do
      item = .Directory~new; item['PLAN'] = plan; item['CAUSE'] = rec~identity; item['LABEL'] = label
      pending[jobName] = item
    end
  end
  return rec
::method kernelGap private
  expose journal rules observationLogger sources
  use strict arg label,reason
  journal~append(label,'KERNEL_LOG_GAP','',1,'',reason)
  if observationLogger~wants('PUBLISH','KERNEL_LOG_GAP') then ignore=observationLogger~publish(label,'KERNEL_LOG_GAP','',1,reason)
  do rule over rules~allItems; if rule~source==label then rule~disarm; end
  r=.Directory~new; r['BOOT_ID']=observationLogger~bootId; r['ORIGIN']='PAM'; r['TYPE']='GAP'
  do k over .Array~of('SERIAL','EPOCH_MS','PID','UID','AUID','SESSION','RESULT'); r[k]='0'; end
  if observationLogger~wants('PUBLISHPAM','GAP') then ignore=observationLogger~publishPam(r)
  /* An incomplete kernel stream must not silently enable same-runtime PAM triggers. */
  do id over sources~allIndexes
    if sources[id]['CATEGORY']\=='AUDIT' then iterate
    journal~append(sources[id]['LABEL'],'AUDIT_GAP','',1,'',reason)
    self~detach(id)
  end
  return self
::method collectJobs
  expose pending journal
  do key over pending~allIndexes
    item = pending[key]; plan = item['PLAN']
    if plan~settled then do
      journal~append(item['LABEL'],'JOB_SETTLED',key,1,item['CAUSE'],plan~state)
      pending~remove(key)
    end
  end
  return pending~items
::method close
  expose mux sources rules closed journal pending
  if closed then return .false
  closed = .true
  mux~close; sources~empty
  do rule over rules~allItems; rule~disarm; end
  rules~empty
  journal~append('runtime','RUNTIME_CLOSED','','1','',pending~items 'jobs still tracked')
  return .true

/* Re-enter the existing policy boundary. Never treat submit failure as
   automatically retryable; a failure can occur after the board appended it. */
::routine submitEventPlan
  use strict arg board, plan, principal
  manager = .ShellSecurityManager~new(principal)
  routine = .Routine~new('eventSubmit', 'use arg b,p; return b~submit(p)', .context~package)
  routine~setSecurityManager(manager)
  signal on syntax name failed
  out = routine~call(board,plan)
  return 'SUBMITTED'
failed:
  do decision over manager~decisions
    if decision~verdict == 'deny' then return 'DENIED'
  end
  return 'DISPATCH_UNKNOWN'

::routine entryHasMetric
  use strict arg sources,label,subject
  do item over sources~allItems
    if item['LABEL'] == label then return item['SAMPLER']~hasMetric(subject)
  end
  return .false

::routine eventIdValid
  use strict arg name
  return name~isA(.String) & name~length > 0 & name~length <= 128 & name~left(1)~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ') = 0 & name~verify('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-') = 0

::routine decodeKernelRecord
  use strict arg bytes, includeText
  signal on syntax name malformed
  return .KernelPrintkDecoder~new~decode(bytes,includeText)
malformed:
  return .nil

::routine publishObservation
  use strict arg bridge,label,kind,subject,count,detail
  signal on syntax name failed
  return bridge~publish(label,kind,subject,count,detail)
failed:
  r=.Directory~new; r['OK']=.false; r['INGRESS_ID']=''; return r
