/* AudioV9VoiceCampaign.cls
 * Deterministic campaign, worker ownership and filename-wall-clock source planning.
 * Audio evidence is never distributed semantically: workers own core time only.
 */

::options numeric inherit

::class AudioV9VoiceClock public
::method parse class
  use strict arg text
  s=text~string
  if s~length=19 & s~substr(5,1)='-' then do
    y=s~substr(1,4); mo=s~substr(6,2); d=s~substr(9,2); h=s~substr(12,2); mi=s~substr(15,2); se=s~substr(18,2)
  end
  else if s~length>=15 & s~substr(9,1)='_' then do
    y=s~substr(1,4); mo=s~substr(5,2); d=s~substr(7,2); h=s~substr(10,2); mi=s~substr(12,2); se=s~substr(14,2)
  end
  else raise syntax 88.900 array('unsupported wall-clock timestamp',s)
  if \datatype(y||mo||d||h||mi||se,'W') then raise syntax 88.900 array('non-numeric wall-clock timestamp',s)
  y=y+0; mo=mo+0; d=d+0; h=h+0; mi=mi+0; se=se+0
  if mo<1 | mo>12 | d<1 | d>self~daysInMonth(y,mo) | h>23 | mi>59 | se>59 then raise syntax 88.900 array('wall-clock timestamp out of range',s)
  days=365*(y-1)+((y-1)%4)-((y-1)%100)+((y-1)%400)
  monthDays=.array~of(31,28,31,30,31,30,31,31,30,31,30,31)
  if self~isLeap(y) then monthDays[2]=29
  do m=1 to mo-1; days=days+monthDays[m]; end
  days=days+d-1
  return days*86400+h*3600+mi*60+se
::method fromSourceName class
  use strict arg name
  parse var name d '_' t '_' camera '_original.ogg' tail
  if tail<>'' | d~length<>8 | t~length<>6 then raise syntax 88.900 array('noncanonical original source name',name)
  return self~parse(d||'_'||t)
::method isLeap class private
  use strict arg y
  if y//400=0 then return .true
  if y//100=0 then return .false
  return y//4=0
::method daysInMonth class private
  use strict arg y,m
  a=.array~of(31,28,31,30,31,30,31,31,30,31,30,31)
  if m=2 & self~isLeap(y) then return 29
  return a[m]

::class AudioV9WorkerAssignment public
::method init
  expose worker coreStartText coreEndText coreStart coreEnd halo provider address login
  use strict arg workerValue,startValue,endValue,haloValue,providerValue,addressValue,loginValue=''
  worker=workerValue~string; coreStartText=startValue~string; coreEndText=endValue~string
  coreStart=.AudioV9VoiceClock~parse(coreStartText); coreEnd=.AudioV9VoiceClock~parse(coreEndText)
  halo=haloValue+0; provider=providerValue~string; address=addressValue~string; login=loginValue~string
  if coreEnd<=coreStart then raise syntax 88.900 array('worker core interval must be positive',worker)
  if halo<0 | halo\=trunc(halo) then raise syntax 88.900 array('worker halo must be non-negative integer',worker,halo)
::method worker; expose worker; return worker
::method coreStart; expose coreStart; return coreStart
::method coreEnd; expose coreEnd; return coreEnd
::method coreStartText; expose coreStartText; return coreStartText
::method coreEndText; expose coreEndText; return coreEndText
::method halo; expose halo; return halo
::method analysisStart; expose coreStart halo; return coreStart-halo
::method analysisEnd; expose coreEnd halo; return coreEnd+halo
::method provider; expose provider; return provider
::method address; expose address; return address
::method login; expose login; return login
::method owns
  expose coreStart coreEnd
  use strict arg serialSecond
  t=serialSecond+0
  return t>=coreStart & t<coreEnd
::method canonicalText
  expose worker coreStartText coreEndText halo provider address login
  return 'AUDIO_V9_WORKER/1|worker='||worker||'|core='||coreStartText||'..'||coreEndText||'|halo='||halo||'|provider='||provider||'|address='||address||'|login='||login

::class AudioV9SourceSlice public
::method init
  expose feed name sourceStart sliceStart sliceEnd offsetSeconds durationSeconds coreOwned
  use strict arg feedValue,nameValue,sourceStartValue,sliceStartValue,sliceEndValue,coreOwnedValue=.true
  feed=feedValue~string~lower; name=nameValue~string; sourceStart=sourceStartValue+0; sliceStart=sliceStartValue+0; sliceEnd=sliceEndValue+0; coreOwned=coreOwnedValue
  if sliceEnd<=sliceStart then raise syntax 88.900 array('source slice must be positive',feed,name)
  offsetSeconds=sliceStart-sourceStart; durationSeconds=sliceEnd-sliceStart
  if offsetSeconds<0 then raise syntax 88.900 array('source slice begins before source',feed,name)
::method feed; expose feed; return feed
::method name; expose name; return name
::method sourceStart; expose sourceStart; return sourceStart
::method sliceStart; expose sliceStart; return sliceStart
::method sliceEnd; expose sliceEnd; return sliceEnd
::method offsetSeconds; expose offsetSeconds; return offsetSeconds
::method durationSeconds; expose durationSeconds; return durationSeconds
::method coreOwned; expose coreOwned; return coreOwned
::method canonicalText
  expose feed name sourceStart sliceStart sliceEnd offsetSeconds durationSeconds coreOwned
  return 'AUDIO_V9_SOURCE_SLICE/1|feed='||feed||'|name='||name||'|sourceStart='||sourceStart||'|sliceStart='||sliceStart||'|sliceEnd='||sliceEnd||'|offset='||offsetSeconds||'|duration='||durationSeconds||'|coreOwned='||coreOwned

::class AudioV9SourceList public
::method fromFile class
  use strict arg feedValue,listPath
  names=.array~new
  do while lines(listPath)>0
    line=linein(listPath)~strip
    if line<>'' then names~append(line)
  end
  call stream listPath,'C','CLOSE'
  return self~new(feedValue,names)
::method init
  expose feed names starts
  use strict arg feedValue,nameValues
  feed=feedValue~string~lower
  if feed\='fc' & feed\='fd' then raise syntax 88.900 array('source-list feed must be fc or fd',feed)
  if \nameValues~isA(.Array) | nameValues~items<2 then raise syntax 88.900 array('source list requires at least two names',feed)
  names=nameValues~copy; starts=.array~new; last=.nil
  do i=1 to names~items
    t=.AudioV9VoiceClock~fromSourceName(names[i])
    if last\==.nil & t<=last then raise syntax 88.900 array('source filenames not strictly chronological',feed,names[i])
    starts~append(t); last=t
  end
::method feed; expose feed; return feed
::method size; expose names; return names~items
::method names; expose names; return names~copy
::method sourceFor
  expose names starts
  use strict arg serialSecond
  t=serialSecond+0; found=0
  do i=1 to starts~items
    if starts[i]<=t then found=i
    else leave
  end
  if found=0 then raise syntax 88.900 array('wall-clock precedes source list',t)
  if found=starts~items then raise syntax 88.900 array('cannot prove terminal source coverage without following file',names[found],t)
  if t>=starts[found+1] then raise syntax 88.900 array('source list search invariant failed',t)
  return names[found]
::method slices
  expose feed names starts
  use strict arg startSecond,endSecond,coreStart=.nil,coreEnd=.nil
  s=startSecond+0; e=endSecond+0
  if e<=s then raise syntax 88.900 array('source slice range must be positive',s,e)
  out=.array~new
  do i=1 to names~items-1
    fileStart=starts[i]; fileEnd=starts[i+1]
    if fileEnd<=s then iterate
    if fileStart>=e then leave
    a=s; if fileStart>a then a=fileStart
    b=e; if fileEnd<b then b=fileEnd
    if b>a then do
      owned=.true
      if coreStart\==.nil & coreEnd\==.nil then owned=(a>=coreStart & a<coreEnd)
      out~append(.AudioV9SourceSlice~new(feed,names[i],fileStart,a,b,owned))
    end
  end
  if out~items=0 then raise syntax 88.900 array('no source coverage for range',feed,s,e)
  if out[1]~sliceStart<>s | out[out~items]~sliceEnd<>e then raise syntax 88.900 array('source list does not fully cover range',feed,s,e,out[1]~sliceStart,out[out~items]~sliceEnd)
  return out

::class AudioV9VoiceCampaign public
::method load class
  use strict arg campaignPath,workersPath
  cfg=self~readKeyValue(campaignPath)
  required=.array~of('schema','campaign_id','start','end','expected_fc_files','expected_fd_files','expected_total_files','expected_total_bytes','analysis_sample_rate','analysis_window_ms','analysis_step_ms','halo_seconds')
  do k over required; if \cfg~hasIndex(k) then raise syntax 88.900 array('campaign key missing',k); end
  if cfg['schema']\='audio.v9.voice-recovery.campaign/1' then raise syntax 88.900 array('unsupported campaign schema',cfg['schema'])
  workers=self~readWorkers(workersPath)
  return self~new(cfg,workers)
::method init
  expose cfg workers byWorker start end
  use strict arg cfgValue,workersValue
  cfg=cfgValue; workers=workersValue~copy; byWorker=.directory~new
  start=.AudioV9VoiceClock~parse(cfg['start']); end=.AudioV9VoiceClock~parse(cfg['end'])
  do w over workers
    if byWorker~hasIndex(w~worker) then raise syntax 88.900 array('duplicate worker',w~worker)
    byWorker[w~worker]=w
  end
  self~validate
::method validate
  expose cfg workers start end
  if workers~items<>7 then raise syntax 88.900 array('campaign requires seven workers',workers~items)
  if cfg['expected_fc_files']+0<>95 | cfg['expected_fd_files']+0<>25 | cfg['expected_total_files']+0<>120 then raise syntax 88.900 array('campaign corpus file-count contract changed')
  if cfg['expected_total_bytes']~string\='4292920762' then raise syntax 88.900 array('campaign corpus byte contract changed',cfg['expected_total_bytes'])
  cursor=start
  do i=1 to workers~items
    w=workers[i]
    if w~coreStart<>cursor then raise syntax 88.900 array('worker partition gap/overlap before',w~worker,cursor,w~coreStart)
    if w~halo<>cfg['halo_seconds']+0 then raise syntax 88.900 array('worker halo disagreement',w~worker,w~halo,cfg['halo_seconds'])
    cursor=w~coreEnd
  end
  if cursor<>end then raise syntax 88.900 array('worker partition does not reach campaign end',cursor,end)
  return .true
::method setting
  expose cfg
  use strict arg key
  if \cfg~hasIndex(key~string) then return .nil
  return cfg[key~string]
::method workers; expose workers; return workers~copy
::method worker
  expose byWorker
  use strict arg workerName
  n=workerName~string
  if \byWorker~hasIndex(n) then raise syntax 88.900 array('unknown campaign worker',n)
  return byWorker[n]
::method start; expose start; return start
::method end; expose end; return end
::method canonicalText
  expose cfg workers
  return 'AUDIO_V9_VOICE_CAMPAIGN/1|id='||cfg['campaign_id']||'|start='||cfg['start']||'|end='||cfg['end']||'|workers='||workers~items||'|files='||cfg['expected_total_files']||'|bytes='||cfg['expected_total_bytes']
::method readKeyValue class private
  use strict arg path
  d=.directory~new; first=.true
  do while lines(path)>0
    line=linein(path)
    if first then do; first=.false; if line='key'||'09'x||'value' then iterate; end
    if line='' then iterate
    p=line~pos('09'x); if p=0 then raise syntax 88.900 array('campaign TSV line malformed',line)
    k=line~substr(1,p-1); v=line~substr(p+1)
    if d~hasIndex(k) then raise syntax 88.900 array('duplicate campaign key',k)
    d[k]=v
  end
  call stream path,'C','CLOSE'
  return d
::method readWorkers class private
  use strict arg path
  out=.array~new; first=.true
  do while lines(path)>0
    line=linein(path)
    if first then do; first=.false; if line~left(6)='worker' then iterate; end
    if line='' then iterate
    fields=self~splitTabs(line)
    if fields~items<>7 then raise syntax 88.900 array('worker TSV requires seven columns',line)
    out~append(.AudioV9WorkerAssignment~new(fields[1],fields[2],fields[3],fields[4],fields[5],fields[6],fields[7]))
  end
  call stream path,'C','CLOSE'
  return out
::method splitTabs class private
  use strict arg line
  out=.array~new; rest=line
  do forever
    p=rest~pos('09'x)
    if p=0 then do; out~append(rest); leave; end
    out~append(rest~substr(1,p-1)); rest=rest~substr(p+1)
  end
  return out
