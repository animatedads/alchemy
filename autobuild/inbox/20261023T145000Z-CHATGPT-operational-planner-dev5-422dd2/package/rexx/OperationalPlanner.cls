::class OperationalPlanner public
::method init
  expose command cache
  use arg command='opctl'
  cache=.directory~new
::attribute command get
::method invalidate
  expose cache
  cache=.directory~new
  return self
::method decide
  expose command cache
  use arg className, operatingState
  key=className||'1F'x||operatingState
  if cache~hasIndex(key) then return cache[key]
  out.=''; err.=''
  address command command 'decide' className operatingState with output stem out. error stem err.
  if rc<>0 then raise syntax 93.900 array('Operational planner decision failed',err.)
  d=.directory~new
  do i=1 to out.0
    line=out.i
    do j=1 to line~words
      token=line~word(j)
      p=token~pos('=')
      if p>1 then d[token~left(p-1)]=token~substr(p+1)
    end
  end
  cache[key]=d
  return d

::class OperationalClassRegistry public
::method init
  expose command
  use arg command='opctl'
::attribute command get
::method register
  expose command
  use arg name, normal='allow', degraded='allow', constrained='allow', emergency='allow', sort='', deadlineUs='' 
  cmd=command 'class add' name '--normal' normal '--degraded' degraded '--constrained' constrained '--emergency' emergency
  if sort<>'' then cmd=cmd '--sort' sort
  if deadlineUs<>'' then cmd=cmd '--deadline-us' deadlineUs
  address command cmd
  if rc<>0 then raise syntax 93.900 array('Operational class registration failed',name)
  return 0

::class OperationalCapacityRegistry public
::method init
  expose command cache
  use arg command='opctl'
  cache=.directory~new
::attribute command get
::method set
  expose command cache
  use strict arg domainName, nominalBytesPerSec, currentBytesPerSec=''
  cmd=command 'capacity set' domainName nominalBytesPerSec
  if currentBytesPerSec<>'' then cmd=cmd currentBytesPerSec
  address command cmd
  if rc<>0 then raise syntax 93.900 array('Operational capacity domain registration failed',domainName)
  d=.directory~new; d['NAME']=domainName; d['NOMINAL_BPS']=nominalBytesPerSec
  if currentBytesPerSec='' then d['CURRENT_BPS']=nominalBytesPerSec
  else d['CURRENT_BPS']=currentBytesPerSec
  cache[domainName]=d
  return 0
::method show
  expose command cache
  use strict arg domainName, forceRefresh=.false
  if \forceRefresh then if cache~hasIndex(domainName) then return cache[domainName]
  out.=''; err.=''
  address command command 'capacity show' domainName with output stem out. error stem err.
  if rc<>0 then return .nil
  d=.directory~new
  do i=1 to out.0
    line=out.i
    do j=1 to line~words
      token=line~word(j)
      p=token~pos('=')
      if p>1 then d[token~left(p-1)]=token~substr(p+1)
    end
  end
  cache[domainName]=d
  return d
::method refresh
  use strict arg domainName
  return self~show(domainName,.true)
::method invalidate
  expose cache
  use strict arg domainName=''
  if domainName='' then cache=.directory~new
  else if cache~hasIndex(domainName) then cache~remove(domainName)
  return self

::class OperationalCapacityGovernor public
::method init
  expose capacity planner counts shares tickets nextTicket
  use strict arg capacityRegistry, plannerObject
  capacity=capacityRegistry; planner=plannerObject
  counts=.directory~new; shares=.directory~new; tickets=.directory~new
  nextTicket=1
::method acquire
  expose capacity planner counts shares tickets nextTicket
  use strict arg className, operatingState, domainName
  domain=capacity~show(domainName)
  if domain==.nil then return .nil
  decision=planner~decide(className,operatingState)
  if decision==.nil then return .nil
  if decision['TRANSMIT']<>'1' | decision['TRANSFORM']='1' then return .nil
  per=decision['PER_CONTEXT_CAP_PERCENT']
  if per==.nil | \datatype(per,'W') | per<1 then per=100
  if decision['ACTION']='throttle' then do
    rp=decision['RATE_PERCENT']
    if rp<>.nil then if datatype(rp,'W') then if rp<per then per=rp
  end
  max=decision['MAX_PARALLEL_CONTEXTS']
  if max==.nil | \datatype(max,'W') | max<1 then max=65535
  agg=decision['AGGREGATE_CAP_PERCENT']
  if agg==.nil | \datatype(agg,'W') | agg<1 then agg=100
  key=className||'1F'x||domainName
  count=counts[key]; if count==.nil then count=0
  used=shares[key]; if used==.nil then used=0
  if count>=max | used+per>agg then return .nil
  current=domain['CURRENT_BPS']; if current==.nil | \datatype(current,'W') then return .nil
  id=nextTicket; nextTicket+=1
  t=.directory~new
  t['ID']=id; t['CLASS']=className; t['DOMAIN']=domainName; t['PERCENT']=per; t['ADMITTED']=1
  t['BYTES_PER_SEC']=(current*per)%100
  tickets[id]=t; counts[key]=count+1; shares[key]=used+per
  return t
::method release
  expose counts shares tickets
  use strict arg ticketId
  t=tickets[ticketId]
  if t==.nil then return .false
  key=t['CLASS']||'1F'x||t['DOMAIN']
  p=t['PERCENT']; if p==.nil then p=0
  admitted=t['ADMITTED']; if admitted==.nil then admitted=1
  if admitted=1 then do
    c=counts[key]-1; if c<0 then c=0
    s=shares[key]-p; if s<0 then s=0
    counts[key]=c; shares[key]=s
  end
  tickets~remove(ticketId)
  return .true
::method ticket
  expose tickets
  use strict arg ticketId
  return tickets[ticketId]
::method refreshDomain
  expose capacity tickets
  use strict arg domainName
  domain=capacity~show(domainName)
  if domain==.nil then return .false
  current=domain['CURRENT_BPS']; if current==.nil | \datatype(current,'W') then return .false
  do id over tickets
    t=tickets[id]
    if t['DOMAIN']=domainName then do
      admitted=t['ADMITTED']; if admitted==.nil then admitted=1
      p=t['PERCENT']; if p==.nil then p=0
      if admitted=1 then t['BYTES_PER_SEC']=(current*p)%100
      else t['BYTES_PER_SEC']=0
    end
  end
  return .true
::method reconcile
  expose capacity planner counts shares tickets
  use strict arg className, operatingState, domainName
  domain=capacity~show(domainName)
  if domain==.nil then return .array~new
  decision=planner~decide(className,operatingState)
  if decision==.nil then return .array~new
  per=decision['PER_CONTEXT_CAP_PERCENT']
  if per==.nil | \datatype(per,'W') | per<1 then per=100
  if decision['ACTION']='throttle' then do
    rp=decision['RATE_PERCENT']
    if rp<>.nil then if datatype(rp,'W') then if rp<per then per=rp
  end
  max=decision['MAX_PARALLEL_CONTEXTS']
  if max==.nil | \datatype(max,'W') | max<1 then max=65535
  agg=decision['AGGREGATE_CAP_PERCENT']
  if agg==.nil | \datatype(agg,'W') | agg<1 then agg=100
  transmit=(decision['TRANSMIT']='1' & decision['TRANSFORM']<>'1')
  current=domain['CURRENT_BPS']; if current==.nil | \datatype(current,'W') then current=0
  ids=.array~new
  do id over tickets
    t=tickets[id]
    if t['CLASS']=className then do
      if t['DOMAIN']=domainName then ids~append(id)
    end
  end
  ids~sort
  key=className||'1F'x||domainName
  count=0; used=0; out=.array~new
  do id over ids
    t=tickets[id]
    admit=transmit
    if admit then if count>=max then admit=.false
    if admit then if used+per>agg then admit=.false
    if admit then do
      t['ADMITTED']=1; t['PERCENT']=per; t['BYTES_PER_SEC']=(current*per)%100
      count+=1; used+=per
    end
    else do
      t['ADMITTED']=0; t['PERCENT']=0; t['BYTES_PER_SEC']=0
    end
    out~append(t)
  end
  counts[key]=count; shares[key]=used
  return out
::method activeContexts
  expose counts
  use strict arg className, domainName
  key=className||'1F'x||domainName
  n=counts[key]; if n==.nil then n=0
  return n
::method activePercent
  expose shares
  use strict arg className, domainName
  key=className||'1F'x||domainName
  n=shares[key]; if n==.nil then n=0
  return n
