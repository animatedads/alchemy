/* Cloud Economics v0.1-dev4: detailed execution-cost comparisons.
 * This is PAPER ONLY. An observed tariff NEVER conveys available capacity.
 * All amounts are USD; GiB denotes 2**30 bytes; rates explicitly per unit.
 * Caller remains responsible for actual estate intention/allocator authority.
 */
::class CloudWholeJobEconomics public

::method validateSnapshot
  /* This is the admission check for a NEW economics configuration. Keep
   * the previous snapshot active on missing units, duplicates or bad prices. */
  use strict arg tariffs, profiles
  seen=.directory~new
  do t over tariffs
    id=t['id']
    if id='' | seen~hasIndex(id) then ,
      raise syntax 93.900 array('Duplicate or empty economic tariff')
    seen[id]=.true
    self~validateTerm(t)
  end
  if tariffs~items=0 then raise syntax 93.900 array('Empty economic tariff snapshot')
  seen=.directory~new
  do p over profiles
    id=p['id']
    if id='' | seen~hasIndex(id) then ,
      raise syntax 93.900 array('Duplicate or empty economic workload')
    seen[id]=.true
    self~validateProfile(p)
  end
  if profiles~items=0 then raise syntax 93.900 array('Empty workload economics snapshot')
  return .true

::method evaluate
  /* Entire candidate population is evaluated as a snapshot; inputs are not
   * mutated. Missing tariff/profile is not silently estimated as free. */
  use strict arg job, offers, now, tariffs, profiles
  numeric digits 20
  answer=.directory~new
  answer['job']=job['id']; answer['mode']='PAPER_ONLY'
  answer['status']='NO_ELIGIBLE_OPTION'; answer['reason']='NO_FULL_COST_OPTION'
  answer['selected']=''; answer['cost']=0; answer['baseline']='NA'
  answer['savings']='NA'; answer['source']=''; answer['count']=0
  answer['forecast']=''; answer['confidence']=0
  answer['start']=now; answer['end']=now+(job['hours']+0)*3600
  answer['next_check']=now+60; answer['breakdown']=.nil
  answer['candidates']=.array~new
  answer['model']='whole_job_v1'
  if job['hours']+0<=0 | job['cpu']+0<=0 | job['mem']+0<=0 then ,
    raise syntax 93.900 array('Invalid job requirements for whole-job economics')
  if job['nodes']+0<1 | job['nodes']+0>2 then ,
    raise syntax 93.900 array('Unsupported node count')
  if job['budget']+0<0 then raise syntax 93.900 array('Negative job budget')
  if job~hasIndex('earliest') then do
    if datatype(job['earliest'],'N') then do
      if now<job['earliest']+0 then do
        answer['status']='PAPER_HOLD'
        answer['reason']='earliest permitted start has not arrived'
        answer['next_check']=job['earliest']+0
        return answer
      end
    end
  end
  if profiles~hasIndex(job['id'])==.false then do
    answer['status']='PAPER_HOLD'
    answer['reason']='MISSING_WORKLOAD_ECONOMICS_PROFILE'
    return answer
  end
  p=profiles[job['id']]
  self~validateProfile(p)
  termById=.directory~new
  do t over tariffs
    id=t['id']
    if id='' | termById~hasIndex(id) then ,
      raise syntax 93.900 array('Duplicate or empty tariff identity')
    self~validateTerm(t)
    termById[id]=t
  end
  ids=.directory~new; eligible=.array~new
  planner=.CloudEconomicsPlanner~new
  do offer over offers
    id=offer['id']
    if id='' | id~pos('+')>0 | ids~hasIndex(id) then ,
      raise syntax 93.900 array('Duplicate or ambiguous capacity identity')
    ids[id]=.true
    if planner~eligible(job,offer,now) then do
      if termById~hasIndex(id) then eligible~append(offer)
    end
  end
  bestBaseline=.nil
  do offer over eligible
    if offer['mem']+0<job['mem']+0 then iterate
    c=self~single(job,p,offer,termById[offer['id']])
    if c==.nil then iterate
    answer['candidates']~append(c)
    if offer['purchase']='ONDEMAND' then do
      if job['baseline']=='' | job['baseline']==offer['id'] then do
        if bestBaseline==.nil then bestBaseline=c
        else if c['cost']<bestBaseline['cost'] then bestBaseline=c
      end
    end
  end
  /* Segmented logical RAM only. CPU remains on the first (execution) node.
   * This flag is already required to be backed by a real Memory Fabric plan
   * at the upstream authority bridge before costing is actionable. */
  if job['fabric_mode']=='SEGMENTED' & job['nodes']+0>=2 then do
    do i=1 to eligible~items
      a=eligible[i]
      if a['fabric_ok']<>'1' then iterate
      do j=1 to eligible~items
        if i=j then iterate
        b=eligible[j]
        if b['fabric_ok']<>'1' | a['site']=='' | a['site']<>b['site'] then iterate
        if a['mem']+0+b['mem']+0<job['mem']+0 then iterate
        c=self~pair(job,p,a,b,termById[a['id']],termById[b['id']])
        if c<>.nil then answer['candidates']~append(c)
      end
    end
  end
  answer['count']=answer['candidates']~items
  if bestBaseline<>.nil then answer['baseline']=bestBaseline['cost']
  best=.nil
  do c over answer['candidates']
    if job['budget']+0>0 & c['cost']>job['budget']+0 then iterate
    /* Expected extra execution time must fit the deadline; do not hide
     * billing or checkpoint overhead behind nominal job.hours. */
    if job['deadline']+0>0 & now+c['duration_seconds']>job['deadline']+0 then iterate
    if best==.nil then best=c
    else if c['cost']<best['cost'] then best=c
  end
  if best==.nil then do
    answer['reason']='NO_FULL_COST_PLAN_WITHIN_BUDGET_OR_DEADLINE'
    return answer
  end
  answer['selected']=best['ids']
  answer['source']=best['source']; answer['cost']=best['cost']
  answer['status']='PAPER_BUY'
  answer['reason']=self~receiptEvidence(best)
  answer['breakdown']=best
  answer['end']=now+best['duration_seconds']
  if bestBaseline<>.nil then answer['savings']=bestBaseline['cost']-best['cost']
  return answer

::method receiptEvidence private
  /* Persist numerical decomposition in the immutable decision receipt; no
   * dependency on a later, mutable price feed to explain a paper buy. */
  use strict arg c
  names='compute startup ingress egress storage io fabric_compute fabric_network'
  evidence='whole_job_v1'
  do while names<>''
    parse var names key names
    evidence=evidence||';'||key||'='||c[key]
  end
  evidence=evidence||';billed_seconds='||c['billed_seconds']
  evidence=evidence||';expected_interruptions='||c['expected_interruptions']
  return evidence

::method validateProfile private
  use strict arg p
  required='input_gib output_gib scratch_gib io_gib checkpoint_gib checkpoint_interval_s checkpoint_cpu_s restore_s max_recovery_s fabric_gib_hour spot_recovery'
  do while required<>''
    parse var required k required
    if k='spot_recovery' then do
      if p~hasIndex(k)==.false then raise syntax 93.900 array('Missing spot recovery policy')
      if p[k]<>'CHECKPOINT' & p[k]<>'FULL_RESTART' & p[k]<>'FORBID' then ,
        raise syntax 93.900 array('Unknown spot recovery policy')
    end
    else self~nonnegative(p,k)
  end
  if p['spot_recovery']=='CHECKPOINT' & p['checkpoint_interval_s']+0<=0 then ,
    raise syntax 93.900 array('Checkpoint recovery needs interval')

::method validateTerm private
  use strict arg t
  required='bill_quantum_s bill_min_s ingress_usd_gib egress_usd_gib storage_usd_gibh io_usd_gib fabric_transfer_usd_gib'
  do while required<>''
    parse var required k required
    self~nonnegative(t,k)
  end
  if t['bill_quantum_s']+0<=0 then ,
    raise syntax 93.900 array('Billing quantum must be positive')
  if t['bill_quantum_s']+0<>trunc(t['bill_quantum_s']+0) | ,
     t['bill_min_s']+0<>trunc(t['bill_min_s']+0) then ,
    raise syntax 93.900 array('Billing timing requires integral seconds')

::method nonnegative private
  use strict arg row, name
  if row~hasIndex(name)==.false then ,
    raise syntax 93.900 array('Missing economic term '||name)
  val=row[name]
  if datatype(val,'N')==.false then ,
    raise syntax 93.900 array('Nonnumeric economic term '||name)
  if val+0<0 then raise syntax 93.900 array('Negative economic term '||name)

::method billSeconds private
  use strict arg duration, term
  numeric digits 20
  quantum=term['bill_quantum_s']+0
  minimum=term['bill_min_s']+0
  seconds=duration
  if seconds<minimum then seconds=minimum
  units=seconds/quantum
  whole=trunc(units)
  if units>whole then whole+=1
  return whole*quantum

::method baseCost private
  use strict arg job, p, offer, term
  numeric digits 20
  runtime=(job['hours']+0)*3600
  risk=offer['risk']+0
  /* risk = modelled interruptions per runtime-hour. Expected lost work is
   * half an interval, or half a full run, plus an explicit restore time.
   * This expectation is NOT a guarantee of meeting a hard deadline. */
  if offer['purchase']=='SPOT' & p['spot_recovery']=='FORBID' then return .nil
  interval=p['checkpoint_interval_s']+0
  restart=p['restore_s']+0
  if p['spot_recovery']=='FULL_RESTART' then lost=runtime/2
  else do
    if interval>0 then do
      bound=interval
      if runtime<bound then bound=runtime
      lost=bound/2
    end
    else lost=runtime/2
  end
  perEvent=lost+restart
  if p['max_recovery_s']+0>0 & risk>0 & perEvent>p['max_recovery_s']+0 then return .nil
  expectedEvents=risk*job['hours']
  extraSeconds=expectedEvents*perEvent
  checkpoints=0
  if interval>0 then do
    checkpoints=trunc(runtime/interval)
    if checkpoints*interval>=runtime then checkpoints-=1
    if checkpoints<0 then checkpoints=0
  end
  checkpointTime=checkpoints*(p['checkpoint_cpu_s']+0)
  duration=runtime+checkpointTime+extraSeconds
  billed=self~billSeconds(duration,term)
  compute=(offer['rate']+0)*billed/3600
  startup=offer['startup']+0
  ingress=(p['input_gib']+0)*(term['ingress_usd_gib']+0)
  egress=(p['output_gib']+0)*(term['egress_usd_gib']+0)
  storage=(p['scratch_gib']+0+p['checkpoint_gib']+0)* ,
      (duration/3600)*(term['storage_usd_gibh']+0)
  io=(p['io_gib']+0+2*checkpoints*(p['checkpoint_gib']+0))* ,
      (term['io_usd_gib']+0)
  breakdown=.directory~new
  breakdown['ids']=offer['id']; breakdown['source']=offer['source']
  breakdown['compute']=compute; breakdown['startup']=startup
  breakdown['ingress']=ingress; breakdown['egress']=egress
  breakdown['storage']=storage; breakdown['io']=io
  breakdown['fabric_compute']=0; breakdown['fabric_network']=0
  breakdown['expected_interruptions']=expectedEvents
  breakdown['expected_recovery_seconds']=extraSeconds
  breakdown['checkpoints']=checkpoints
  breakdown['billed_seconds']=billed
  breakdown['duration_seconds']=duration
  breakdown['cost']=compute+startup+ingress+egress+storage+io
  return breakdown

::method single private
  use strict arg job, p, offer, term
  return self~baseCost(job,p,offer,term)

::method pair private
  use strict arg job,p,a,b,ta,tb
  numeric digits 20
  c=self~baseCost(job,p,a,ta)
  if c==.nil then return .nil
  if b['purchase']=='SPOT' & p['spot_recovery']=='FORBID' then return .nil
  /* Secondary contributes memory, not CPU. Charge its minimum billable time
   * and a conservative independent availability-risk provision. */
  seconds=c['duration_seconds']
  riskExtra=(b['risk']+0)*(job['hours']+0)*(p['restore_s']+0)
  bill=self~billSeconds(seconds+riskExtra,tb)
  secondary=(b['rate']+0)*bill/3600+(b['startup']+0)
  net=(p['fabric_gib_hour']+0)*(seconds/3600)* ,
      (ta['fabric_transfer_usd_gib']+0+tb['fabric_transfer_usd_gib']+0)
  baseFabric=(a['fabric']+0+b['fabric']+0)*(seconds/3600)
  c['ids']=a['id']||'+'||b['id']
  c['source']=a['source']||'+'||b['source']
  c['fabric_compute']=secondary+baseFabric
  c['fabric_network']=net
  c['cost']=c['cost']+secondary+baseFabric+net
  if seconds+riskExtra>c['duration_seconds'] then c['duration_seconds']=seconds+riskExtra
  return c
::requires 'CloudEconomics.cls'
