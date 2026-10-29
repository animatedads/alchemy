/* Paper-only daemon entrypoint. At is injected by the launcher for repeatability.
 * The cost planner never leases nodes or provisions a VM.
 */
parse arg command root now
if root=='' then do
  say 'Usage: rexx cloud_cost.rex tick|report|audit|discover|providers STATE_DIRECTORY EPOCH_SECONDS'
  exit 2
end
if now=='' then now=0
numeric digits 20
select
when command=='tick' then do
  offers=.CloudEconomicIO~read(root||'/offers.tsv')
  jobs=.CloudEconomicIO~read(root||'/jobs.tsv')
  history=.CloudEconomicIO~read(root||'/history.tsv')
  ledger=.CloudPaperLedger~new(root||'/accounts.tsv')
  completed=.CloudEconomicIO~read(root||'/decisions.tsv')
  events=.CloudEconomicIO~read(root||'/events.tsv')
  economicConfig=root||'/economics/current/terms.tsv'
  wholeJob=stream(economicConfig,'c','query exists')<>''
  if wholeJob then do
    terms=.CloudEconomicIO~read(economicConfig)
    provenance=.CloudEconomicIO~read(root||'/economics/current/provenance.tsv')
    provenanceSuffix=''
    do fact over provenance
      name=fact['name']
      if name='snapshot' | name='tariff_sha256' | name='profile_sha256' then ,
        provenanceSuffix=provenanceSuffix||';'||name||'='||fact['value']
    end
    profiles=.CloudEconomicIO~read(root||'/economics/current/profiles.tsv')
    profileById=.directory~new
    do p over profiles
      if p['id']=='' | profileById~hasIndex(p['id']) then ,
        raise syntax 93.900 array('Duplicate or empty workload economics profile')
      profileById[p['id']]=p
    end
  end
  /* Recover receipts whose ledger append was interrupted, then audit every
   * posting before considering additional hypothetical commitments. */
  do past over completed
    if past['status']='PAPER_BUY' then dummy=ledger~reconcile(past['id'],past,now)
  end
  audit=ledger~audit(completed)
  if audit['ok']==.false then do
    say 'LEDGER_INVALID: paper commitments frozen'
    do issue over audit['issues']; say issue; end
    exit 3
  end
  /* Each paper-certified offer id represents one capacity slot, not an
   * unlimited fleet. A provider wishing to quote many units must enumerate
   * unique capacity-offer identities through the authoritative adapter. */
  reserved=.directory~new
  exposure=0
  do past over completed
    if past['status']\='PAPER_BUY' then iterate
    exposure+=past['cost']+0
    if past~hasIndex('end') then do
      if past['end']+0>now then do
        ids=past['selected']~makeArray('+')
        do id over ids; reserved[id]=.true; end
      end
    end
    else do
      /* Conservative behaviour for pre-scheduling-schema receipts. */
      ids=past['selected']~makeArray('+')
      do id over ids; reserved[id]=.true; end
    end
  end
  portfolioBudget=0
  budgetFile=root||'/budget.usd'
  if stream(budgetFile,'c','query exists')\='' then do
    portfolioBudget=linein(budgetFile)
    call stream budgetFile,'c','close'
    if \datatype(portfolioBudget,'N') | portfolioBudget+0<0 then do
      say 'Invalid paper-portfolio budget in' budgetFile
      exit 3
    end
  end
  do job over jobs
    previous=.nil
    do past over completed
      if past['id']==job['id'] then previous=past
    end
    if previous\==.nil then do
      if previous['status']=='PAPER_BUY' then do
        receipt=.directory~new
        receipt['status']='PAPER_BUY'; receipt['cost']=previous['cost']
        receipt['selected']=previous['selected']
        dummy=ledger~reconcile(job['id'],receipt,now)
        iterate
      end
    end
    available=.array~new
    do quote over offers
      if \reserved~hasIndex(quote['id']) then available~append(quote)
    end
    if wholeJob then ,
      decision=.CloudWholeJobEconomics~new~evaluate(job,available,now,terms,profileById)
    else ,
      decision=.CloudEconomicsPlanner~new~plan(job,available,now,history)
    if decision['status']=='PAPER_BUY' & portfolioBudget>0 then do
      if exposure+decision['cost']>portfolioBudget then do
        decision['status']='PAPER_HOLD'
        decision['reason']='portfolio PAPER budget cap would be exceeded'
      end
    end
    if decision['status']=='PAPER_BUY' & wholeJob then ,
      decision['reason']=decision['reason']||provenanceSuffix
    if decision['status']\='PAPER_BUY' then do
      call logAdvisory root,job['id'],decision,now,events
      say decision['status'] job['id'] decision['selected'] decision['reason']
      iterate
    end
    /* Immutable decision receipt, followed by replay-repairable postings.
     * A crash after decision but before ledger is repaired next tick. */
    row=job['id']||'09'x||decision['status']||'09'x||decision['selected']||'09'x|| ,
      decision['cost']||'09'x||decision['baseline']||'09'x||decision['savings']||'09'x|| ,
      decision['source']||'09'x||now||'09'x||decision['reason']||'09'x|| ,
      decision['confidence']||'09'x||decision['forecast']||'09'x||'PAPER_ONLY'||'09'x|| ,
      decision['start']||'09'x||decision['end']
    dummy=.CloudEconomicIO~append(root||'/decisions.tsv',row)
    dummy=ledger~reconcile(job['id'],decision,now)
    exposure+=decision['cost']
    ids=decision['selected']~makeArray('+')
    do id over ids; reserved[id]=.true; end
    say 'PAPER_BUY' job['id'] decision['selected'] 'cost USD' decision['cost'] ,
      'unmanaged USD' decision['baseline'] 'saving USD' decision['savings']
  end
end
when command=='report' then do
  decisions=.CloudEconomicIO~read(root||'/decisions.tsv')
  total=0; comparableCost=0; baseline=0; benchmarked=0; booked=0
  do d over decisions
    if d['status']\='PAPER_BUY' then iterate
    booked+=1
    total+=d['cost']+0
    if d['baseline']\='NA' then do
      benchmarked+=1
      comparableCost+=d['cost']+0
      baseline+=d['baseline']+0
    end
    say 'JOB' d['id'] 'PLAN' d['selected'] 'COST' d['cost'] ,
      'UNMANAGED' d['baseline'] 'SAVED' d['savings'] 'SOURCE' d['source']
  end
  say 'PAPER_BOOKINGS' booked 'PAPER_TOTAL_USD' total
  say 'COMPARABLE_JOBS' benchmarked 'UNMANAGED_TOTAL_USD' baseline
  if benchmarked>0 then do
    saving=baseline-comparableCost
    say 'COMPARABLE_SAVINGS_USD' saving
    if baseline>0 then say 'COMPARABLE_SAVINGS_PERCENT' (saving/baseline)*100
    else say 'COMPARABLE_SAVINGS_PERCENT N/A'
  end
  else say 'COMPARABLE_SAVINGS_USD N/A'
  /* Never compare non-benchmarked bookings to managed benchmark population. */
  if booked=benchmarked then say 'SAVINGS_USD' baseline-total
  else say 'SAVINGS_USD' 'N/A (missing unmanaged baselines)'
end
when command=='audit' then do
  decisions=.CloudEconomicIO~read(root||'/decisions.tsv')
  ledger=.CloudPaperLedger~new(root||'/accounts.tsv')
  auditReport=ledger~audit(decisions)
  say 'PAPER_ACCOUNT_AUDIT' auditReport['ok'] 'RECEIPTS' auditReport['receipts'] ,
    'POSTINGS' auditReport['rows'] 'BALANCE_USD' auditReport['balance']
  do issue over auditReport['issues']; say issue; end
  if auditReport['ok']==.false then exit 3
end
when command=='providers' then do
  observed=.CloudEconomicIO~read(root||'/providers.tsv')
  do r over observed
    say r['provider'] r['status'] r['note']
  end
end
when command=='discover' then do
  surface=.CloudEconomicsIntention~new~discover
  say 'API' surface['provider'] 'MODE' surface['mode'] 'MUTATING' surface['mutating']
  do v over surface['operations']; say 'INTENTION' v; end
  do v over surface['dependencies']; say 'DEPENDS' v; end
end
otherwise do
  say 'Unknown command:' command
  exit 2
end
end
exit 0

logAdvisory: procedure
  use strict arg root, jobid, decision, now, history
  /* Rate-limit equivalent holds to one event per hour for nonstop daemons. */
  do i=history~items to 1 by -1
    h=history[i]
    if h['id']\=jobid then iterate
    if h['status']==decision['status'] then do
      if now-(h['ts']+0)<3600 then return
    end
    leave
  end
  row=jobid||'09'x||decision['status']||'09'x||decision['selected']||'09'x|| ,
    decision['cost']||'09'x||decision['baseline']||'09'x||decision['savings']||'09'x|| ,
    decision['source']||'09'x||now||'09'x||decision['reason']||'09'x||decision['next_check']
  dummy=.CloudEconomicIO~append(root||'/events.tsv',row)
  return
::requires 'CloudEconomics.cls'

::requires 'CloudWholeJobEconomics.cls'
