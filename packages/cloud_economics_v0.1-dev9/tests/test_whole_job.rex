/* Run with genuine ooRexx and the dev4 package, never a Python simulation. */
numeric digits 20
base=arg(1)
offers=.CloudEconomicIO~read(base||'/fixtures/offers.tsv')
jobs=.CloudEconomicIO~read(base||'/fixtures/jobs.tsv')
terms=.CloudEconomicIO~read(base||'/fixtures/economic_terms.tsv')
profiles=.CloudEconomicIO~read(base||'/fixtures/workload_economics.tsv')
byId=.directory~new
pById=.directory~new
do t over terms; byId[t['id']]=t; end
do p over profiles; pById[p['id']]=p; end
engine=.CloudWholeJobEconomics~new
first=engine~evaluate(jobs[1],offers,1791000000,terms,pById)
call assert first['status']=='PAPER_BUY', 'costed paper status'
call assert first['model']=='whole_job_v1', 'named cost model'
call assert first['baseline']<>'NA', 'explicit eligible baseline'
call assert first['count']>1, 'multiple costed plans'
call assert first['selected']=='aws-32+aws-32b','same-site memory fabric option'
call assert first['breakdown']['fabric_network']>0,'fabric traffic charged'
call assert first['breakdown']['compute']>0,'CPU charged'
call assert first['breakdown']['io']>0,'checkpoint writes charged'
call assert first['breakdown']['storage']>0,'scratch and checkpoints charged'
call assert first['breakdown']['expected_interruptions']>0,'spot failure provision'
call assert first['breakdown']['duration_seconds']>3600,'checkpoint and recovery time'
contig=engine~evaluate(jobs[2],offers,1791000000,terms,pById)
call assert contig['selected']=='gcp-64','contiguous only single node'
/* An hourly-billed low rate is not always cheapest for a 15-minute job. */
short=.directory~new
do key over jobs[2]~allIndexes; short[key]=jobs[2][key]; end
short['id']='short-job'; short['hours']=0.25; short['spot']='0'
short['baseline']='aws-64'
ps=.directory~new
do key over profiles[2]~allIndexes; ps[key]=profiles[2][key]; end
ps['id']='short-job'; ps['input_gib']=0; ps['output_gib']=0
ps['scratch_gib']=0; ps['io_gib']=0; ps['checkpoint_gib']=0
ps['checkpoint_interval_s']=0; ps['spot_recovery']='FORBID'
pById['short-job']=ps
s=engine~evaluate(short,offers,1791000000,terms,pById)
call assert s['selected']=='aws-64','billing quantization changes ranking'
call assert s['breakdown']['billed_seconds']==900,'per-second billing with minimum'
call assert s['baseline']==s['cost'],'pinned unmanaged baseline matches selected'
/* All candidates missing terms is a hold/no plan, not a zero-price buy. */
none=engine~evaluate(short,offers,1791000000,.array~new,pById)
call assert none['status']=='NO_ELIGIBLE_OPTION','missing tariffs not free'
/* Missing job economics never falls through to a cheaper legacy estimate. */
missing=engine~evaluate(short,offers,1791000000,terms,.directory~new)
call assert missing['status']=='PAPER_HOLD','missing profile held'
call assert missing['reason']=='MISSING_WORKLOAD_ECONOMICS_PROFILE','missing profile reason'
/* Checkpoint/recovery policy matters to spot eligibility. */
pById['memory-job']['spot_recovery']='FORBID'
restricted=engine~evaluate(jobs[1],offers,1791000000,terms,pById)
call assert restricted['selected']=='gcp-64','forbidden spot cannot win'
pById['memory-job']['spot_recovery']='CHECKPOINT'
/* No overlapping price/capacity rights are inferred by altering offer flags. */
offers[2]['fabric_ok']='0'
noFabric=engine~evaluate(jobs[1],offers,1791000000,terms,pById)
call assert noFabric['selected']=='gcp-64','fabric authority flag required'
offers[2]['fabric_ok']='1'
/* Deadline includes expected overhead, not just nominal job hours. */
jobs[1]['deadline']='1791003600'
deadlined=engine~evaluate(jobs[1],offers,1791000000,terms,pById)
call assert deadlined['status']=='NO_ELIGIBLE_OPTION','economic duration checked at deadline'
jobs[1]['deadline']='1800000000'
/* Malformed unit pricing fails closed. */
byId['aws-64']['egress_usd_gib']='NOT_A_NUMBER'
signal on syntax name badTariff
ignored=engine~evaluate(jobs[1],offers,1791000000,terms,pById)
say 'FAIL invalid tariff passed'; exit 1
badTariff:
  say 'PASS whole-job unit prices, checkpoint, risk, fabric, billing and deadlines'
  exit 0
assert:
  use arg predicate, explanation
  if \predicate then do
    say 'FAIL:' explanation
    exit 1
  end
  return
::requires 'CloudWholeJobEconomics.cls'
