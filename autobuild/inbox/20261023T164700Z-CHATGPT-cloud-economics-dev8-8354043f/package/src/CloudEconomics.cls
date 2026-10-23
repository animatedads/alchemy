/* Cloud Economics: independent PAPER-ONLY economic advisory authority.
 * Provider prices, forecasts and commitments are not node entitlement.
 * Do not replace allocator, Registered Job or Memory Fabric verification.
 */
::class CloudEconomicsVersion public
::constant API 'cloud.economics/0.1'
::constant MODE 'PAPER_ONLY'

::class CloudEconomicIO public
/* Parse strict, header-based TSV. The schema is deliberately normalised before
 * ooRexx sees provider-specific JSON; do not use line-by-line MCP requests. */
::method read class
  use strict arg file
  output=.array~new
  if stream(file,'c','query exists') == '' then return output
  header=linein(file)
  if header == '' then do
    call stream file,'c','close'
    return output
  end
  names=header~makeArray('09'x)
  do while lines(file)>0
    line=linein(file)
    if line~strip == '' then iterate
    if line~left(1) == '#' then iterate
    fields=line~makeArray('09'x)
    if fields~items <> names~items then do
      call stream file,'c','close'
      raise syntax 93.900 array('TSV field count mismatch: ' || file)
    end
    entry=.directory~new
    do i=1 to names~items
      entry[names[i]~strip] = fields[i]~strip
    end
    output~append(entry)
  end
  call stream file,'c','close'
  return output

::method append class
  use strict arg file, line
  call lineout file, line
  call stream file,'c','close'
  return 1

::method makeRecord class
  use strict arg line, header
  names=header~makeArray('09'x)
  vals=line~makeArray('09'x)
  if names~items<>vals~items then raise syntax 93.900 array('invalid record')
  entry=.directory~new
  do i=1 to names~items
    entry[names[i]]=vals[i]
  end
  return entry

::class CloudPriceForecast public
/* Conservative trend forecast, not an independent entitlement/price quote.
 * Time-series regression may be replaced with ooRexx ML without changing
 * the planner API; no trained model is falsely claimed here. */
::method estimate
  use strict arg offerId, history, horizonSeconds, now=9999999999
  numeric digits 20
  samples=.array~new
  do h over history
    if h['id']==offerId & h['ts']+0<=now then samples~append(h)
  end
  answer=.directory~new
  answer['model']='ewma_slope_v1'
  answer['count']=samples~items
  answer['confidence']=0
  answer['price']=0
  if samples~items<4 then return answer
  n=samples~items
  a=samples[n-3]; b=samples[n-2]; c=samples[n-1]; d=samples[n]
  ta=a['ts']+0; td=d['ts']+0
  if td<=ta then return answer
  pa=a['rate']+0; pb=b['rate']+0; pc=c['rate']+0; pd=d['rate']+0
  if pa<0 | pb<0 | pc<0 | pd<0 then return answer
  average=(pa+2*pb+3*pc+4*pd)/10
  slope=(pd-pa)/(td-ta)
  projection=average+slope*horizonSeconds
  if projection<0 then projection=0
  volatility=(abs(pa-average)+abs(pb-average)+abs(pc-average)+abs(pd-average))/4
  if average=0 then return answer
  confidence=0.80-volatility/average
  if confidence<0 then confidence=0
  if confidence>0.80 then confidence=0.80
  answer['price']=projection
  answer['confidence']=confidence
  return answer

::class CloudEconomicsPlanner public
/* Hard legal, authority and capacity gates precede economic ranking.
 * A split plan is segmented logical memory, NOT merged CPU/address space. */
::method eligible
  use strict arg job, offer, now
  numeric digits 20
  if offer['approved']\='1' | offer['capacity']\='1' then return .false
  if offer['expiry']+0<now then return .false
  if offer['ts']+0>now then return .false
  if offer['source']\='FIXTURE' then do
    if now-(offer['ts']+0)>3600 then return .false
  end
  if offer['currency']\='USD' then return .false
  if offer['region']\=job['region'] & job['region']\='ANY' then return .false
  if offer['cpu']+0<job['cpu']+0 then return .false
  if offer['gpu']+0<job['gpu']+0 then return .false
  if offer['purchase']=='SPOT' & job['spot']\='1' then return .false
  if offer['rate']+0<0 | offer['startup']+0<0 then return .false
  if offer['network']+0<0 | offer['fabric']+0<0 then return .false
  if offer['risk']+0<0 | offer['risk']+0>1 then return .false
  if job['jurisdiction']\='ANY' & offer['jurisdiction']\=job['jurisdiction'] then return .false
  if job['runtime']\='ANY' & offer['runtime']\=job['runtime'] then return .false
  return .true

::method singleCost private
  use strict arg job, offer
  numeric digits 20
  hours=job['hours']+0
  /* Risk expected loss is an explicitly stated risk provision, not an SLA. */
  return (offer['rate']+0)*hours + (offer['startup']+0) + ,
     (offer['network']+0)*(job['data']+0) + ,
     (offer['risk']+0)*(offer['rate']+0)*hours

::method pairCost private
  use strict arg job, a, b
  numeric digits 20
  /* Data ingress/egress counted once at the execution (first) node. */
  hours=job['hours']+0
  return (a['rate']+0+b['rate']+0)*hours + ,
      (a['startup']+0+b['startup']+0) + ,
      (a['network']+0)*(job['data']+0) + ,
      (a['risk']+0)*(a['rate']+0)*hours + ,
      (b['risk']+0)*(b['rate']+0)*hours + ,
      (a['fabric']+0+b['fabric']+0)*hours

::method plan
  use strict arg job, offers, now, history=.nil
  numeric digits 20
  if job['hours']+0<=0 | job['mem']+0<=0 | job['cpu']+0<=0 then ,
    raise syntax 93.900 array('invalid positive job requirements')
  if job['nodes']+0<1 | job['nodes']+0>2 then ,
    raise syntax 93.900 array('supported nodes range is 1..2')
  if job['budget']+0<0 then raise syntax 93.900 array('negative budget')
  candidates=.array~new
  answer=.directory~new
  answer['job']=job['id']; answer['mode']='PAPER_ONLY'
  answer['status']='NO_ELIGIBLE_OPTION'; answer['reason']='hard eligibility / current capacity'
  answer['selected']=''; answer['cost']=0; answer['baseline']='NA'
  answer['savings']='NA'; answer['count']=0; answer['source']=''
  answer['forecast']=''; answer['confidence']=0
  answer['start']=now
  answer['end']=now+(job['hours']+0)*3600
  answer['next_check']=now+60
  /* A job may wait until its earliest time, but cannot silently miss its
   * required completion deadline in order to save money. */
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
  if job['deadline']+0>0 & answer['end']>job['deadline']+0 then do
    answer['reason']='deadline cannot accommodate the execution duration'
    return answer
  end
  /* A quote identity represents one capacity slot. Duplicate or ambiguous
   * identities make economic scheduling and the audit trail untrustworthy. */
  offerIds=.directory~new
  do offer over offers
    id=offer['id']
    if id='' | id~pos('+')>0 | offerIds~hasIndex(id) then ,
      raise syntax 93.900 array('Duplicate or ambiguous offer identity')
    offerIds[id]=.true
  end
  eligible=.array~new
  bestBaseline=.nil; baselineCost=0
  do offer over offers
    if \self~eligible(job,offer,now) then iterate
    eligible~append(offer)
    if offer['mem']+0>=job['mem']+0 then do
      cost=self~singleCost(job,offer)
      opt=self~option(offer['id'],cost,offer['source'],offer['purchase'],offer)
      candidates~append(opt)
      if offer['purchase']='ONDEMAND' then do
        if job['baseline'] == '' | job['baseline']==offer['id'] then do
          if bestBaseline==.nil then do
            bestBaseline=opt; baselineCost=cost
          end
          else if cost<baselineCost then do
            bestBaseline=opt; baselineCost=cost
          end
        end
      end
    end
  end
  /* A multi-provider Memory Fabric plan requires same-site certified provider
   * context and an explicit SEGMENTED workload. Hard CPU on execution node. */
  if job['fabric_mode']=='SEGMENTED' & job['nodes']+0>=2 then do
    do i=1 to eligible~items
      a=eligible[i]
      if a['fabric_ok']\='1' then iterate
      do j=1 to eligible~items
        if j=i then iterate
        b=eligible[j]
        if b['fabric_ok']\='1' then iterate
        if a['site']\=b['site'] | a['site']=='' then iterate
        if a['id']==b['id'] then iterate
        if a['mem']+0+b['mem']+0<job['mem']+0 then iterate
        /* No unattended distributed CPU equivalence: the first offer is the
         * compute owner and the second contributes segmented memory only. */
        cost=self~pairCost(job,a,b)
        pair=self~option(a['id']||'+'||b['id'],cost, ,
          a['source']||'+'||b['source'],a['purchase']||'+'||b['purchase'],a)
        candidates~append(pair)
      end
    end
  end
  answer['count']=candidates~items
  if bestBaseline\==.nil then answer['baseline']=baselineCost
  if candidates~items=0 then return answer
  best=.nil
  do c over candidates
    if job['budget']+0>0 & c['cost']>job['budget']+0 then iterate
    if best==.nil then best=c
    else if c['cost']<best['cost'] then best=c
  end
  if best==.nil then do
    answer['reason']='every admissible option exceeds budget'
    return answer
  end
  answer['cost']=best['cost']; answer['selected']=best['ids']
  answer['source']=best['source']; answer['status']='PAPER_BUY'
  answer['reason']='cheapest eligible full-cost plan; no live purchase'
  if bestBaseline\==.nil then answer['savings']=baselineCost-best['cost']
  /* Latest-start limits holding. Forecasts cannot override hard eligibility. */
  if history\==.nil & job['deadline']+0>now+3600+(job['hours']+0)*3600 & job['delay']+0>=3600 then do
    if best['ids']~pos('+')=0 then do
      forecast=.CloudPriceForecast~new~estimate(best['ids'],history,3600,now)
      answer['confidence']=forecast['confidence']
      if forecast['confidence']>=0.7 & forecast['price']>0 then do
        predicted=best['cost']-(best['primary']['rate']+0)* ,
          (job['hours']+0) + forecast['price']*(job['hours']+0)
        answer['forecast']=predicted
        if predicted < best['cost']*0.95 then do
          answer['status']='PAPER_HOLD'
          answer['reason']='price forecast suggests >5% reduction, within deadline'
          answer['next_check']=now+3600
        end
      end
    end
  end
  return answer

::method option private
  use strict arg ids, cost, source, purchase, primary
  answer=.directory~new
  answer['ids']=ids
  answer['cost']=cost
  answer['source']=source
  answer['purchase']=purchase
  answer['primary']=primary
  return answer

::class CloudEconomicsIntention public
/* Dynamic discovery. This is a cost/planning surface, never allocation. */
::method discover
  use strict arg context=.nil
  d=.directory~new
  d['provider']='cloud.economics/0.1'
  d['mode']='PAPER_ONLY'
  d['mutating']=.false
  d['operations']=.array~of('OBSERVE_PRICES','EXPLORE_CAPABILITIES', ,
    'PLAN_COST','COMPARE_UNMANAGED','FORECAST_OPPORTUNITY', ,
    'PAPER_BUY','PAPER_HOLD','ACCOUNT_LEDGER','EXPLAIN_PLAN', ,
    'EVALUATE_AUTHORITY_ROUTE','PREPARE_ADVISORY_HANDOFF','AUDIT_ACCOUNTS')
  d['dependencies']=.array~of('generalized.compute.intentions/0.1', ,
    'job.node.allocator/0.6','memory.fabric/0.1', ,
    'registered.job.economic/0.1','instrumentation.mesh/0.1')
  d['context']=context
  return d

::class CloudPaperLedger public
/* Every PAPER_BUY has a balanced two-posting journal. Replay by job id
 * can heal an interrupted ledger append without duplicate commitments. */
::method init
  expose path
  use strict arg path

::method booked
  expose path
  use strict arg jobid
  if stream(path,'c','query exists')=='' then return .false
  do while lines(path)>0
    row=linein(path)~makeArray('09'x)
    if row~items>=2 then do
      if row[1]==jobid & row[2]=='PAPER_EXPENSE' then do
        call stream path,'c','close'
        return .true
      end
    end
  end
  call stream path,'c','close'
  return .false

::method reconcile
  expose path
  use strict arg jobid, decision, now
  numeric digits 20
  if decision['status']\='PAPER_BUY' then return 0
  debit=.false; credit=.false
  if stream(path,'c','query exists')\='' then do
    do while lines(path)>0
      row=linein(path)~makeArray('09'x)
      if row~items>=2 then do
        if row[1]==jobid then do
          if row~items<5 then raise syntax 93.900 array('Malformed paper ledger entry')
          if datatype(row[3],'N')==.false then raise syntax 93.900 array('Nonnumeric paper ledger amount')
          expected=decision['cost']+0
          if row[2]=='PAPER_COMMITMENT' then expected=-expected
          if row[3]+0<>expected | row[5]<>decision['selected'] then ,
            raise syntax 93.900 array('Paper ledger differs from decision receipt: '||jobid)
          if row[2]=='PAPER_EXPENSE' then debit=.true
          if row[2]=='PAPER_COMMITMENT' then credit=.true
        end
      end
    end
    call stream path,'c','close'
  end
  amount=decision['cost']
  if \debit then do
    row=jobid||'09'x||'PAPER_EXPENSE'||'09'x||amount||'09'x||now||'09'x||decision['selected']
    dummy=.CloudEconomicIO~append(path,row)
  end
  if \credit then do
    row=jobid||'09'x||'PAPER_COMMITMENT'||'09'x||(-amount)||'09'x||now||'09'x||decision['selected']
    dummy=.CloudEconomicIO~append(path,row)
  end
  return 1

::method audit
  /* Read full decision/ledger snapshots in a single pass. Never silently
   * net duplicates, orphan postings or amounts inconsistent with receipts. */
  expose path
  use strict arg decisions
  numeric digits 20
  receipts=.directory~new
  seen=.directory~new
  issues=.array~new
  balance=0
  rows=0
  do d over decisions
    if d['status']<>'PAPER_BUY' then iterate
    id=d['id']
    if receipts~hasIndex(id) then issues~append('DUPLICATE_DECISION '||id)
    else receipts[id]=d
  end
  postings=.CloudEconomicIO~read(path)
  do row over postings
    rows+=1
    id=row['id']; account=row['account']
    if account<>'PAPER_EXPENSE' & account<>'PAPER_COMMITMENT' then do
      issues~append('UNEXPECTED_ACCOUNT '||id||' '||account)
      iterate
    end
    key=id||'/'||account
    if seen~hasIndex(key) then issues~append('DUPLICATE_POSTING '||key)
    seen[key]=.true
    if receipts~hasIndex(id)==.false then do
      issues~append('ORPHAN_POSTING '||key)
      iterate
    end
    if datatype(row['amount'],'N')==.false then do
      issues~append('INVALID_AMOUNT '||key)
      iterate
    end
    amount=row['amount']+0
    balance+=amount
    d=receipts[id]
    expected=d['cost']+0
    if account='PAPER_COMMITMENT' then expected=-expected
    if amount<>expected then issues~append('AMOUNT_MISMATCH '||key)
    if row['selected']<>d['selected'] then issues~append('SELECTION_MISMATCH '||key)
  end
  do id over receipts~allIndexes
    if seen~hasIndex(id||'/PAPER_EXPENSE')==.false then ,
      issues~append('MISSING_EXPENSE '||id)
    if seen~hasIndex(id||'/PAPER_COMMITMENT')==.false then ,
      issues~append('MISSING_COMMITMENT '||id)
  end
  /* dev4 receipt costs use 20-digit arithmetic. A two-sided journal must
   * preserve that precision rather than rounding the credit at 9 digits. */
  /* Per-job postings must match their receipt exactly; accumulations of
   * long decimals may still round when rows are appended in crash-replay
   * order. Apply a narrow aggregate tolerance, never to individual entries. */
  if abs(balance)<=0.000000000001 then balance=0
  else issues~append('UNBALANCED_POSTINGS')
  do id over receipts~allIndexes
    d=receipts[id]
    reason=d['reason']
    if reason~pos('whole_job_v1;')<>1 then iterate
    part=reason~makeArray(';')
    values=.directory~new
    do i=2 to part~items
      item=part[i]
      parse var item key '=' value
      if key='' | values~hasIndex(key) then do
        issues~append('INVALID_COMPONENT_EVIDENCE '||id)
        iterate
      end
      values[key]=value
    end
    keys='compute startup ingress egress storage io fabric_compute fabric_network'
    components=0
    do while keys<>''
      parse var keys key keys
      if values~hasIndex(key)==.false then do
        issues~append('MISSING_COMPONENT '||id||' '||key)
        iterate
      end
      if datatype(values[key],'N')==.false then do
        issues~append('INVALID_COMPONENT '||id||' '||key)
        iterate
      end
      if values[key]+0<0 then issues~append('NEGATIVE_COMPONENT '||id||' '||key)
      components+=values[key]+0
    end
    if abs(components-(d['cost']+0))>0.000000000001 then ,
      issues~append('COMPONENT_SUM_MISMATCH '||id)
  end
  auditReport=.directory~new
  auditReport['ok']=issues~items=0
  auditReport['issues']=issues
  auditReport['balance']=balance
  auditReport['rows']=rows
  auditReport['receipts']=receipts~items
  return auditReport

::class CloudEconomicIntentionBridge public
/* Consumes the actual Generalized Compute Intentions planning provider.
 * Candidate identities must be offered by the existing authoritative compute,
 * allocation, WLU and router assessments. No economics-induced entitlement. */
::method admissibleOffers
  use strict arg intentionProvider, workload, context, offers
  discovery=intentionProvider~discover(context)
  if discovery['provider']\='generalized.compute.intentions/0.1' then ,
    raise syntax 93.900 array('unsupported intention provider')
  route=intentionProvider~planAdmittance(workload,context)
  admitted=.directory~new
  do candidate over route~admissibleCandidates
    resource=candidate~resource
    if resource~hasMethod('offerId') then key=resource~offerId
    else if resource~hasMethod('id') then key=resource~id
    else iterate
    admitted[key]=.true
  end
  clean=.array~new
  do quote over offers
    if admitted~hasIndex(quote['id']) then clean~append(quote)
  end
  return clean
