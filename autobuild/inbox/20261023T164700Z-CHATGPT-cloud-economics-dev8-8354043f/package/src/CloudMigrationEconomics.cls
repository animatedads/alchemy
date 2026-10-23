/* Cloud Economics v0.1-dev5: marginal economics of a potential job move.
 * ADVISORY ONLY. Route/intention references are evidence pointers, not
 * verified job mobility, a destination lease, or authorization to migrate.
 * Sunk spend is excluded; already-prepaid source seconds are explicit.
 * Every cost is USD and every duration is seconds unless named otherwise.
 */
::class CloudMigrationEconomics public

::method compare
  /* Evaluate one running workload against a snapshot of alleged routes.
   * Returns an evidence-rich directory; never mutates job, quotes, or ledger.
   * Routes remain advisory until allocator, router, execution and financial
   * authorities revalidate the evidence at the moment of any hand-off. */
  use strict arg running, routes, offers, now, tariffs
  numeric digits 20
  self~validateRunning(running)
  byOffer=.directory~new; byTerm=.directory~new; seen=.directory~new
  do o over offers
    if o['id']=='' | byOffer~hasIndex(o['id']) then ,
      raise syntax 93.900 array('Duplicate or missing offer identity')
    byOffer[o['id']]=o
  end
  do t over tariffs
    if t['id']=='' | byTerm~hasIndex(t['id']) then ,
      raise syntax 93.900 array('Duplicate or missing tariff identity')
    self~validateTerm(t)
    byTerm[t['id']]=t
  end
  answer=.directory~new
  answer['job']=running['id']; answer['mode']='ADVISORY_PAPER_ONLY'
  answer['status']='PAPER_HOLD'; answer['selected']=running['source_id']
  answer['reason']='NO_CURRENT_SOURCE_OR_TARIFF'
  answer['baseline']='NA'; answer['cost']='NA'; answer['savings']='NA'
  answer['downtime_s']=0; answer['end']=0; answer['options']=.array~new
  if \byOffer~hasIndex(running['source_id']) then return answer
  source=byOffer[running['source_id']]
  if \byTerm~hasIndex(source['id']) then return answer
  if source['currency']<>'USD' then return answer
  if source['approved']<>'1' | source['capacity']<>'1' then do
    answer['reason']='SOURCE_CAPACITY_NOT_AUTHORIZED'
    return answer
  end
  if now>source['expiry']+0 | now<source['ts']+0 then do
    answer['reason']='STALE_SOURCE_OFFER'
    return answer
  end
  rem=running['remaining_s']+0
  prepaid=running['source_prepaid_s']+0
  sourceT=byTerm[source['id']]
  srcRisk=self~recovery(source, running, rem)
  srcDuration=rem+srcRisk
  srcCompute=(source['rate']+0)* ,
      self~billSeconds(self~positive(srcDuration-prepaid),sourceT)/3600
  srcStorage=(running['scratch_gib']+0)*(srcDuration/3600)* ,
      (sourceT['storage_usd_gibh']+0)
  stayCost=srcCompute+srcStorage+(running['unavoidable_future_usd']+0)
  answer['baseline']=stayCost; answer['cost']=stayCost
  answer['end']=now+srcDuration
  answer['reason']='STAY_IS_CHEAPEST_OR_NO_ATTESTED_ROUTE'
  answer['status']='PAPER_STAY'
  sourceFits=(running['deadline_epoch']+0=0 | now+srcDuration<=running['deadline_epoch']+0)
  if \sourceFits then do
    answer['status']='PAPER_HOLD'; answer['reason']='SOURCE_MISSES_DEADLINE'
  end
  best=.nil
  cooldown=.false
  if running['last_move_epoch']+0>0 then do
    if now<running['last_move_epoch']+0 then cooldown=.true
    else if now-running['last_move_epoch']+0<running['min_residence_s']+0 then cooldown=.true
  end
  if cooldown then do
    answer['reason']='MINIMUM_RESIDENCE_TIME_NOT_REACHED'
    return answer
  end
  do route over routes
    self~validateRoute(route)
    if seen~hasIndex(route['id']) then ,
      raise syntax 93.900 array('Duplicate route identity')
    seen[route['id']]=.true
    if route['job_id']<>running['id'] then iterate
    if route['source_id']<>source['id'] then iterate
    if route['dest_id']==source['id'] then iterate
    if route['status']<>'PLANNED' | route['policy']<>'ELIGIBLE' then iterate
    if route['intention_ref']=='' | route['route_ref']=='' then iterate
    if now<route['observed_at']+0 | now>route['expiry']+0 then iterate
    if now-route['observed_at']+0>300 then iterate
    if running['mobility']<>'CHECKPOINT' then iterate
    if \byOffer~hasIndex(route['dest_id']) then iterate
    dest=byOffer[route['dest_id']]
    if \byTerm~hasIndex(dest['id']) then iterate
    if dest['currency']<>'USD' | dest['approved']<>'1' | dest['capacity']<>'1' then iterate
    if now<dest['ts']+0 | now>dest['expiry']+0 then iterate
    if dest['runtime']<>source['runtime'] then iterate
    if dest['mem']+0<running['memory_gib']+0 | ,
       dest['cpu']+0<running['cpu']+0 then iterate
    if running['jurisdiction']<>'' & running['jurisdiction']<>dest['jurisdiction'] then iterate
    if dest['purchase']='SPOT' & running['allow_spot']<>'1' then iterate
    targetT=byTerm[dest['id']]
    if route['bandwidth_mbps']+0<=0 then iterate
    bytesGiB=running['state_gib']+0+route['staging_gib']+0
    /* GiB -> decimal megabits: 2^30 bytes * 8 / 10^6. */
    transferS=bytesGiB*8589.934592/(route['bandwidth_mbps']+0)
    downtime=(route['checkpoint_s']+0)+(route['latency_s']+0)+ ,
      transferS+(route['restore_s']+0)+(route['warmup_s']+0)
    if running['max_downtime_s']+0>0 & downtime>running['max_downtime_s']+0 then iterate
    targetRisk=self~recovery(dest,running,rem)
    targetDuration=rem+downtime+targetRisk
    if running['deadline_epoch']+0>0 & now+targetDuration>running['deadline_epoch']+0 then iterate
    /* Source compute is charged only for checkpoint construction, after
     * already-paid seconds; no source run-time is charged twice. */
    oldCompute=(source['rate']+0)* ,
      self~billSeconds(self~positive(route['checkpoint_s']+0-prepaid),sourceT)/3600
    newCompute=(dest['rate']+0)*self~billSeconds( ,
      rem+route['restore_s']+0+route['warmup_s']+0+targetRisk,targetT)/3600
    transferCost=bytesGiB*(sourceT['egress_usd_gib']+0+ ,
      targetT['ingress_usd_gib']+0+route['transfer_usd_gib']+0)
    ioCost=(running['state_gib']+0)* ,
      (sourceT['io_usd_gib']+0+targetT['io_usd_gib']+0)
    storageCost=(running['scratch_gib']+0)* ,
      ((rem+route['restore_s']+0+targetRisk)/3600)* ,
      (targetT['storage_usd_gibh']+0)
    cost=oldCompute+newCompute+transferCost+ioCost+storageCost+ ,
      (dest['startup']+0)+(route['source_stop_usd']+0)+ ,
      (route['dest_fixed_usd']+0)+(running['unavoidable_future_usd']+0)
    option=.directory~new
    option['id']=route['id']; option['dest']=dest['id']; option['cost']=cost
    option['compute_source']=oldCompute; option['compute_dest']=newCompute
    option['transfer']=transferCost; option['io']=ioCost
    option['storage']=storageCost
    option['startup']=dest['startup']+0
    option['termination']=route['source_stop_usd']+0
    option['fixed']=route['dest_fixed_usd']+0
    option['unavoidable']=running['unavoidable_future_usd']+0
    option['downtime_s']=downtime; option['end']=now+targetDuration
    option['route_ref']=route['route_ref']
    option['intention_ref']=route['intention_ref']
    option['policy']='PLANNED_NOT_VERIFIED_FOR_DISPATCH'
    option['saving']=stayCost-cost
    answer['options']~append(option)
    /* Do not move merely because of arithmetic noise. Require two explicit
     * hysteresis gates, except when staying cannot meet the hard deadline. */
    if sourceFits then do
      saving=stayCost-cost
      if saving<=0 | saving<running['min_saving_usd']+0 then iterate
      if stayCost<=0 then iterate
      if saving/stayCost*100<running['min_saving_percent']+0 then iterate
    end
    if running['budget_usd']+0>0 & cost>running['budget_usd']+0 then iterate
    if best==.nil then best=option
    else if option['cost']<best['cost'] then best=option
  end
  if best<>.nil then do
    answer['status']='PAPER_MOVE_FAVORED'
    answer['selected']=best['dest']; answer['route']=best['id']
    answer['cost']=best['cost']; answer['downtime_s']=best['downtime_s']
    answer['end']=best['end']; answer['saving']=best['saving']
    if sourceFits then answer['savings']=best['saving']
    else answer['savings']='NA'
    answer['reason']='ECONOMIC_ONLY_REQUIRES_FRESH_ESTATE_LEASE_AND_MOBILITY_APPROVAL'
    answer['breakdown']=best
  end
  return answer

::method recovery private
  /* Simple expectation for comparative modelling, not tail-risk assurance. */
  use strict arg offer, running, seconds
  if offer['purchase']<>'SPOT' then return 0
  interval=running['checkpoint_interval_s']+0
  if interval<=0 then interval=seconds
  if interval>seconds then interval=seconds
  return (offer['risk']+0)*seconds/3600* ,
       (interval/2+running['recovery_s']+0)

::method billSeconds private
  use strict arg seconds, term
  numeric digits 20
  if seconds<=0 then return 0
  if seconds<term['bill_min_s']+0 then seconds=term['bill_min_s']+0
  q=term['bill_quantum_s']+0
  blocks=trunc(seconds/q)
  if seconds>blocks*q then blocks+=1
  return blocks*q

::method positive private
  use strict arg n
  if n<0 then return 0
  return n

::method numericField private
  use strict arg record, key
  if \record~hasIndex(key) then raise syntax 93.900 array('Missing '||key)
  if \datatype(record[key],'N') then raise syntax 93.900 array('Invalid '||key)
  if record[key]+0<0 then raise syntax 93.900 array('Negative '||key)

::method validateRunning private
  use strict arg j
  if j['id']=='' | j['source_id']=='' then raise syntax 93.900 array('Missing running job identity')
  keys='remaining_s deadline_epoch checkpoint_age_s state_gib source_prepaid_s budget_usd memory_gib cpu scratch_gib max_downtime_s min_saving_usd min_saving_percent recovery_s checkpoint_interval_s unavoidable_future_usd last_move_epoch min_residence_s'
  do while keys<>''
    parse var keys k keys
    self~numericField(j,k)
  end
  if j['remaining_s']+0<=0 | j['cpu']+0<=0 | j['memory_gib']+0<=0 then ,
    raise syntax 93.900 array('Invalid active job requirement')
  if j['mobility']<>'CHECKPOINT' & j['mobility']<>'NONE' then ,
    raise syntax 93.900 array('Unsupported mobility mechanism')
  if j['allow_spot']<>'1' & j['allow_spot']<>'0' then ,
    raise syntax 93.900 array('Invalid spot permission')

::method validateRoute private
  use strict arg r
  if r['id']=='' | r['job_id']=='' | r['source_id']=='' | r['dest_id']=='' then ,
    raise syntax 93.900 array('Missing route identity')
  keys='observed_at expiry bandwidth_mbps latency_s checkpoint_s restore_s warmup_s staging_gib transfer_usd_gib source_stop_usd dest_fixed_usd'
  do while keys<>''
    parse var keys k keys
    self~numericField(r,k)
  end
  if r['expiry']+0<r['observed_at']+0 then ,
    raise syntax 93.900 array('Invalid route freshness interval')
  if r['status']<>'PLANNED' & r['status']<>'BLOCKED' then ,
    raise syntax 93.900 array('Unknown route planning status')
  if r['policy']<>'ELIGIBLE' & r['policy']<>'DENIED' then ,
    raise syntax 93.900 array('Unknown route policy status')

::method validateTerm private
  use strict arg t
  keys='bill_quantum_s bill_min_s ingress_usd_gib egress_usd_gib storage_usd_gibh io_usd_gib fabric_transfer_usd_gib'
  do while keys<>''
    parse var keys k keys
    self~numericField(t,k)
  end
  if t['bill_quantum_s']+0<=0 then raise syntax 93.900 array('Zero billing quantum')

::method validateMobilityInputs
  /* Configuration admission only; does NOT establish estate authority. */
  use strict arg running, routes
  jobs=.directory~new; routeIds=.directory~new
  if running~items=0 then raise syntax 93.900 array('Empty mobility job snapshot')
  do j over running
    self~validateRunning(j)
    if jobs~hasIndex(j['id']) then ,
      raise syntax 93.900 array('Duplicate running job')
    jobs[j['id']]=.true
  end
  do r over routes
    self~validateRoute(r)
    if routeIds~hasIndex(r['id']) then ,
      raise syntax 93.900 array('Duplicate route')
    routeIds[r['id']]=.true
    if \jobs~hasIndex(r['job_id']) then ,
      raise syntax 93.900 array('Route references unknown job')
  end
  return .true
