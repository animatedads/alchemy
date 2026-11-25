/* Architecture: Tom Dyer. Coding: ChatGPT.
   Trusted host bridge; uses existing LogService policy/targets. No daemon,
   new queue, direct target insertion or proposal capability. */
::requires 'LoggingCore.cls'
::requires 'POSIXProvider.cls'

/* Local bounded LogService target. Cursor is target-local, not LogService
   sequence (which can legitimately skip other rules). Exact scope only. */
::class KernelLogTarget public
::method init
  expose name scopeObject capacity records seq enabled generation
  use strict arg name, scopeObject, generation, capacity = 1024
  scopeObject = .Log~normalizeScope(scopeObject)
  if scopeObject~domainId == '' then raise syntax 93.900 array ('Exact logging domain required')
  if \capacity~datatype('W') | capacity < 1 | capacity > 65536 then raise syntax 93.900 array ('Invalid capacity')
  if generation == '' then raise syntax 93.900 array ('Explicit target generation required')
  records = .Directory~new; seq = 0; enabled = .true
::attribute name get
::attribute scopeObject get
::attribute enabled get
::attribute generation get
::method scope
  return self~scopeObject~disclosure
::method accept
  expose enabled records seq capacity scopeObject
  use strict arg event
  numeric digits 25
  if \enabled | \event~isA(.LogEvent) then return .false
  if \scopeObject~equivalent(event~deliveryScopeObject) then return .false
  seq += 1; records[seq] = event
  if seq > capacity then records~remove(seq-capacity)
  return .true
::method page
  expose records seq capacity generation enabled
  use strict arg expectedGeneration, after = 0, limit = 128
  numeric digits 25
  if expectedGeneration \== generation then raise syntax 93.900 array ('Target incarnation changed')
  if \after~datatype('W') | after < 0 | after > seq | \limit~datatype('W') | limit < 1 | limit > 1024 then raise syntax 93.900 array ('Invalid cursor or limit')
  first = max(1,seq-capacity+1); next = max(after,first-1); rows = .Array~new
  do i = next+1 to min(seq,next+limit); rows~append(records[i]); next = i; end
  r = .Directory~new; r['GENERATION']=generation; r['NEXT']=next; r['LATEST']=seq; r['FIRST']=first
  r['GAP']=after < first-1; r['ENABLED']=enabled; r['EVENTS']=rows
  return r
::method disable
  expose enabled
  enabled=.false
  return self
::method enable
  expose enabled
  enabled=.true
  return self

/* Use ordinary Directory values, supported by the existing object codec.
   Only reviewed scalar fields are projected; no arbitrary object traversal. */
::class KernelLogBridge public
::method init
  expose service scope node boot incarnation seq subscriptions
  use strict arg service, scope, node, boot, incarnation
  if \service~isA(.LogService) then raise syntax 93.900 array ('LogService required')
  scope = .Log~normalizeScope(scope)
  if scope~domainId == '' then raise syntax 93.900 array ('Exact logging domain required')
  do v over .Array~of(node,boot,incarnation)
    if \v~isA(.String) | v~length < 1 | v~length > 64 | v~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.') > 0 then raise syntax 93.900 array ('Invalid source identity')
  end
  seq=0; subscriptions=.nil
::method bindSubscriptions
  expose service scope subscriptions
  use strict arg registry
  if subscriptions\==.nil then raise syntax 93.900 array ('Subscriptions already bound')
  if \registry~isA(.LogSubscriptions) then raise syntax 93.900 array ('Subscription registry required')
  registry~bind(service,scope,self)
  subscriptions=registry
  return self
::method wants
  expose subscriptions
  use strict arg methodName, kind
  if subscriptions==.nil then return .true
  return subscriptions~wants(self~class~id,methodName,kind)
::method bootId
  expose boot
  return boot
::method scopeId
  expose scope
  return scope~scopeId
::method disclosure
  expose scope
  return scope~disclosure
::method publish
  expose service scope node boot incarnation seq subscriptions
  use strict arg source, kind, subject = '', count = 1, detail = ''
  numeric digits 25
  if source~length > 128 | kind~length > 64 | subject~length > 1024 | detail~length > 1024 then raise syntax 93.900 array ('Observation too large')
  do v over .Array~of(source,kind,subject,detail)
    if \v~isA(.String) then raise syntax 93.900 array ('Scalar observation required')
  end
  if subscriptions\==.nil then if \subscriptions~wants(self~class~id,'PUBLISH',kind) then do
    r=.Directory~new; r['OK']=.false; r['INGRESS_ID']=''; return r
  end
  seq+=1
  payload=.Directory~new
  payload['SCHEMA']='alchemy.kernel.observation/1'; payload['NODE']=node; payload['BOOT_ID']=boot
  payload['INGRESS_ID']=node':'boot':'incarnation':'seq
  payload['SOURCE']=source; payload['KIND']=kind; payload['SUBJECT']=subject; payload['COUNT']=count
  stamp=.POSIXProvider~new~clockSnapshot; payload['MONO_MS']=stamp['MONO_MS']; payload['EPOCH_MS']=stamp['EPOCH_MS']
  /* Structured detail for known JSON observations, bounded scalar otherwise. */
  if kind~left(7)=='METRIC_' | kind=='IDENTITY_CHANGE' | kind~left(4)=='PAM_' | kind=='KERNEL_PRINTK' then do
    if detail~left(1)=='{' then payload['DETAIL']=.JSON~fromJSON(detail)
    else payload['DETAIL']=detail
  end
  else payload['DETAIL']=detail
  if subscriptions==.nil then do
    log=service~loggerFor(self,'PUBLISH',.Array~new,scope)
    ok=log~log(.Log~INFO,payload,'BODY')
  end
  else ok=subscriptions~publish(self,'PUBLISH',kind,payload)
  r=.Directory~new; r['OK']=ok; r['INGRESS_ID']=payload['INGRESS_ID']
  return r

/* PAM producers are trusted and separately reviewed; no native PAM module
   is installed by this package. Only the existing audit-normalizer fields
   cross the boundary. The consumer verifies the route before normalization. */
::method publishPam
  expose service scope node boot incarnation seq subscriptions
  use strict arg row
  numeric digits 25
  if \row~isA(.Directory) then raise syntax 93.900 array ('Structured PAM record required')
  if row['BOOT_ID']\==boot | row['ORIGIN']\=='PAM' then raise syntax 93.900 array ('Wrong PAM provenance')
  clean=.Directory~new
  do k over .Array~of('BOOT_ID','ORIGIN','TYPE','SERIAL','EPOCH_MS','PID','UID','AUID','SESSION','RESULT')
    v=row[k]
    if \v~isA(.String) | v~length>64 then raise syntax 93.900 array ('Invalid PAM field' k)
    clean[k]=v
  end
  if row~hasIndex('OPERATION') then do
    op=row['OPERATION']
    if \op~isA(.String) | op~length>64 then raise syntax 93.900 array ('Invalid operation')
    clean['OPERATION']=op
  end
  if subscriptions\==.nil then if \subscriptions~wants(self~class~id,'PUBLISHPAM',clean['TYPE']) then do
    r=.Directory~new; r['OK']=.false; r['INGRESS_ID']=''; return r
  end
  seq+=1
  p=.Directory~new; p['SCHEMA']='alchemy.pam.observation/1'; p['NODE']=node; p['BOOT_ID']=boot
  p['INGRESS_ID']=node':'boot':'incarnation':'seq; p['RECORD']=clean
  if subscriptions==.nil then do
    log=service~loggerFor(self,'PUBLISHPAM',.Array~new,scope)
    ok=log~log(.Log~INFO,p,'BODY')
  end
  else ok=subscriptions~publish(self,'PUBLISHPAM',clean['TYPE'],p)
  r=.Directory~new; r['OK']=ok; r['INGRESS_ID']=p['INGRESS_ID']
  return r

/* Single owner pull adapter. Starts at live tail, never executes a replay.
   Existing audit adapter retains normalization/dedup and JobBoard policy. */
::class KernelPamLogConsumer public
::method init
  expose target gen cursor ruleId node boot rt label quarantined
  use strict arg target, ruleId, node, boot, rt, label
  if \target~isA(.KernelLogTarget) & \target~isA(.PriorityLogTarget) then raise syntax 93.900 array ('Bounded logging target required')
  gen=target~generation; quarantined=.false
  if target~isA(.PriorityLogTarget) then do
    st=target~status
    if st['PENDING']>0 | st['QUARANTINED'] then raise syntax 93.900 array ('Priority PAM consumer requires reconciled empty lane')
    cursor=st['ACKED']
  end
  else cursor=target~page(gen)['LATEST']
::attribute quarantined get
::method pull
  expose target gen cursor ruleId node boot rt label quarantined
  use strict arg limit=128
  if quarantined then return 0
  p=target~page(gen,cursor,limit)
  gap=p['GAP']
  if target~isA(.PriorityLogTarget) then gap=p['QUARANTINED'] | cursor<p['FIRST']-1
  if gap | \p['ENABLED'] then do; self~gap; return 0; end
  n=0
  do e over p['EVENTS']
    if e~ruleId\==ruleId then iterate
    if e~receiverClass\=='KERNELLOGBRIDGE' | e~methodName\=='PUBLISHPAM' | e~sourceScopeId\==target~scopeObject~scopeId | e~deliveryScopeId\==target~scopeObject~scopeId then do; self~gap; return n; end
    row=e~payload
    if \row~isA(.Directory) then do; self~gap; return n; end
    if row['SCHEMA']\=='alchemy.pam.observation/1' | row['NODE']\==node | row['BOOT_ID']\==boot then do; self~gap; return n; end
    if \row['RECORD']~isA(.Directory) | \row['INGRESS_ID']~isA(.String) then do; self~gap; return n; end
    result=consumePamLog(rt,label,row['RECORD'],row['INGRESS_ID'])
    if result=='INVALID' then do; self~gap; return n; end
    if result=='AUDIT_GAP' then do; quarantined=.true; return n; end
    n+=1
  end
  cursor=p['NEXT']
  if target~isA(.PriorityLogTarget) then ignore=target~ack(gen,cursor)
  return n
::method gap private
  expose rt label quarantined
  quarantined=.true
  r=.Directory~new; r['TYPE']='GAP'
  ignore=consumePamLog(rt,label,r,'')
::routine consumePamLog
  use strict arg rt,label,row,origin
  signal on syntax name failed
  return rt~ingestAudit(label,row,origin)
failed:
  return 'INVALID'

/* Parse the Linux /dev/kmsg ABI: priority,sequence,monotonic usec,flags;message.
   Default metadata-only. Message bytes (if explicitly allowed) remain hex and
   may contain sensitive material; never interpret as command text. */
::class KernelPrintkDecoder public
::method decode
  use strict arg raw, includeText = .false
  numeric digits 25
  if \raw~isA(.String) | raw~length > 16384 then raise syntax 93.900 array ('Invalid kernel record')
  sep=raw~pos(';')
  if sep=0 then raise syntax 93.900 array ('Missing kernel record delimiter')
  parse value raw~left(sep-1) with pri ',' seq ',' micros ',' flags
  do v over .Array~of(pri,seq,micros)
    if v=='' | v~length > 20 | v~verify('0123456789')>0 | v>18446744073709551615 then raise syntax 93.900 array ('Invalid kernel header')
  end
  if pri>191 | flags=='' | flags~length>16 | flags~verify('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-')>0 then raise syntax 93.900 array ('Invalid kernel priority or flags')
  d=.Directory~new; d['PRIORITY']=pri+0; d['FACILITY']=pri%8; d['SEVERITY']=pri//8
  d['KERNEL_SEQUENCE']=seq+0; d['KERNEL_MONO_US']=micros+0; d['FLAGS']=flags
  /* Deliberately no message by default; opt-in capped projection. */
  if includeText then do
    body=raw~substr(sep+1)
    if d['FACILITY']=0 & body~strip~left(7)=='audit: ' then return d
    d['MESSAGE_HEX']=body~left(min(256,body~length))~c2x; d['TRUNCATED']=body~length>256
  end
  return d
::requires 'json.cls'


::requires "LoggingSubscriptions.cls"

/* Only the kernel facility is accepted as the source of kernel audit messages.
   This is a strict projection of the canonical printk audit subset, not auparse. */
::class KernelAuditDecoder public
::method init
  expose boot last
  use strict arg boot
  last=.nil
::method decodeNetlink
  use strict arg typ, raw
  if \typ~datatype('W') | typ<1000 | typ>65535 | \raw~isA(.String) | raw~length>16000 then do
    out=.Directory~new; out['KIND']='GAP'; out['GAP']=.true; return out
  end
  /* Netlink supplies the type, not an untrusted text prefix. Only audit
     timestamp-bearing records affect serial continuity. */
  if raw~strip~left(6)\=='audit(' & raw~pos('audit_lost=')=0 then do
    out=.Directory~new; out['KIND']='IGNORE'; out['GAP']=.false
    if .Array~of(1100,1101,1103,1104,1105,1106)~hasItem(typ) then do
      out['KIND']='GAP'; out['GAP']=.true
    end
    return out
  end
  return self~decode('6,0,0,-;audit: type='typ' 'raw~strip)
::method decode
  expose boot last
  use strict arg raw
  numeric digits 25
  h=.KernelPrintkDecoder~new~decode(raw)
  out=.Directory~new; out['KIND']='IGNORE'; out['GAP']=.false
  if h['FACILITY']\=0 then return out
  body=raw~substr(raw~pos(';')+1)~strip
  if body~left(7)\=='audit: ' then return out
  if body~pos('audit_lost=')>0 then do; out['KIND']='GAP'; out['GAP']=.true; return out; end
  if body~left(12)\=='audit: type=' then return out
  parse var body 'audit: type=' typ ' audit(' epoch ':' serial '): ' tail
  parse var epoch sec '.' milli
  if sec=='' | sec~length>15 | sec~verify('0123456789')>0 | milli~length\=3 | milli~verify('0123456789')>0 | serial=='' | serial~length>10 | serial~verify('0123456789')>0 | serial>4294967295 then do
    out['KIND']='GAP'; out['GAP']=.true; return out
  end
  if last\==.nil then if serial\=last & serial\=last+1 then out['GAP']=.true
  last=serial+0
  select
    when typ=='1100' then do; name='USER_AUTH'; expected='authentication'; end
    when typ=='1101' then do; name='USER_ACCT'; expected='accounting'; end
    when typ=='1103' then do; name='CRED_ACQ'; expected='setcred'; end
    when typ=='1104' then do; name='CRED_DISP'; expected='setcred'; end
    when typ=='1105' then do; name='USER_START'; expected='session_open'; end
    when typ=='1106' then do; name='USER_END'; expected='session_close'; end
    otherwise return out
  end
  parse var tail 'pid=' pid ' uid=' uid ' auid=' auid ' ses=' ses " msg='" payload
  if payload~right(1)\=="'" then do; out['KIND']='GAP'; out['GAP']=.true; return out; end
  payload=payload~left(payload~length-1)
  op=payload~word(1); res=payload~word(payload~words)
  if op\=='op=PAM:'expected | (res\=='res=success' & res\=='res=failed') then do; out['KIND']='GAP'; out['GAP']=.true; return out; end
  do v over .Array~of(pid,uid,auid,ses)
    if v=='' | v~length>10 | v~verify('0123456789')>0 | v>4294967295 then do; out['KIND']='GAP'; out['GAP']=.true; return out; end
  end
  if pid<1 | pid>2147483647 then do; out['KIND']='GAP'; out['GAP']=.true; return out; end
  row=.Directory~new; row['BOOT_ID']=boot; row['ORIGIN']='PAM'; row['TYPE']=name; row['SERIAL']=serial; row['EPOCH_MS']=sec*1000+milli
  row['PID']=pid; row['UID']=uid; row['AUID']=auid; row['SESSION']=ses; row['RESULT']=res~substr(5); row['OPERATION']=op~substr(4)
  out['KIND']='PAM'; out['RECORD']=row
  return out

/* Status is supplied by the authorised control service, not assumed to be
   available to the CAP_AUDIT_READ-only collector. */
::class AuditLossMonitor public
::method init
  expose prior state
  prior=.nil; state='UNKNOWN'
::method observe
  expose prior state
  use strict arg status
  out=.Directory~new; out['GAP']=.false; out['REASON']=''
  if \status['OK'] then do
    if state\=='UNAVAILABLE' then do
      out['GAP']=.true; out['REASON']='audit status unavailable'
    end
    state='UNAVAILABLE'; return out
  end
  lost=status['LOST']; enabled=status['ENABLED']
  if \lost~datatype('W') | lost<0 | lost>4294967295 | \enabled~datatype('W') | enabled<0 | enabled>2 then do
    out['GAP']=.true; out['REASON']='invalid audit status'; return out
  end
  if prior\==.nil then if lost\=prior then do
    out['GAP']=.true; out['REASON']='audit lost counter changed:' prior '->' lost
  end
  if prior==.nil & lost>0 then do
    out['GAP']=.true; out['REASON']='audit status begins with recorded loss:' lost
  end
  if enabled=0 & state\=='DISABLED' then do
    out['GAP']=.true; out['REASON']='kernel audit disabled'
  end
  if state=='UNAVAILABLE' then do
    out['GAP']=.true; out['REASON']='audit status interval was unobserved'
  end
  prior=lost
  if enabled=0 then state='DISABLED'; else state='ACTIVE'
  return out
