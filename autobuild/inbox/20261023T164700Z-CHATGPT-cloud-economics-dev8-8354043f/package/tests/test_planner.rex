numeric digits 20
base=arg(1)
offers=.CloudEconomicIO~read(base||'/fixtures/offers.tsv')
jobs=.CloudEconomicIO~read(base||'/fixtures/jobs.tsv')
planner=.CloudEconomicsPlanner~new
split=planner~plan(jobs[1],offers,1791000000)
call assert split['status']=='PAPER_BUY','paper status'
call assert split['selected']=='aws-32+aws-32b','split 64 GiB into 32+32'
call assert split['cost']=0.6760,'split total includes both risk and fabric overhead'
call assert split['baseline']=1.00,'specific unmanaged baseline'
call assert split['savings']=0.3240,'baseline savings'
contiguous=planner~plan(jobs[2],offers,1791000000)
call assert contiguous['selected']=='oci-64','contiguous cannot split'
call assert contiguous['cost']=0.80,'cheapest eligible contiguous plan'
jobs[1]['spot']='0'
plain=planner~plan(jobs[1],offers,1791000000)
call assert plain['selected']=='oci-64','spot forbidden by job'
jobs[1]['spot']='1'
jobs[1]['fabric_mode']='CONTIGUOUS'
plain=planner~plan(jobs[1],offers,1791000000)
call assert plain['selected']=='oci-64','fabric semantics may not be inferred'
jobs[1]['fabric_mode']='SEGMENTED'
offers[3]['fabric_ok']='0'
plain=planner~plan(jobs[1],offers,1791000000)
call assert plain['selected']=='oci-64','fabric needs certified two-sided topology'
offers[3]['fabric_ok']='1'
offers[1]['approved']='0'
jobs[2]['spot']='0'
plain=planner~plan(jobs[2],offers,1791000000)
call assert plain['selected']=='oci-64','authority gate stops cheapest baseline'
offers[1]['approved']='1'
jobs[2]['budget']='0.50'
plain=planner~plan(jobs[2],offers,1791000000)
call assert plain['status']=='NO_ELIGIBLE_OPTION','budget hard cap'
jobs[2]['budget']='5'
offers[6]['expiry']='1790000000'
plain=planner~plan(jobs[2],offers,1791000000)
call assert plain['selected']=='gcp-64','expired quote rejected'
offers[6]['expiry']='1810000000'
jobs[1]['earliest']='1791005000'
plain=planner~plan(jobs[1],offers,1791000000)
call assert plain['status']=='PAPER_HOLD','earliest start is a hard scheduling constraint'
call assert plain['next_check']=1791005000,'earliest time produces a next-check time'
jobs[1]['earliest']='0'
jobs[1]['deadline']='1791001000'
plain=planner~plan(jobs[1],offers,1791000000)
call assert plain['status']=='NO_ELIGIBLE_OPTION','cannot miss hard completion deadline'
jobs[1]['deadline']='1800000000'
offers[6]['source']='LIVE'
plain=planner~plan(jobs[2],offers,1791000000)
call assert plain['selected']=='gcp-64','stale live quote is not used for pricing'
offers[6]['source']='FIXTURE'
jobs[2]['baseline']='missing-ondemand-baseline'
plain=planner~plan(jobs[2],offers,1791000000)
call assert plain['baseline']=='NA','missing baseline is never invented'
jobs[2]['baseline']='aws-64'
/* Regression for stale and future observations, no future training leakage. */
history=.CloudEconomicIO~read(base||'/fixtures/history.tsv')
forecast=.CloudPriceForecast~new
f=forecast~estimate('aws-32',history,3600,1790005000)
call assert f['confidence']==0,'future timestamps excluded from forecast'
f=forecast~estimate('aws-32',history,3600,1790020000)
call assert f['confidence']>0.7,'forecast confidence with four stable observations'
/* Real Generalized Compute Intention service's existing assessment filters
 * govern routes; economic rank never reverses veto. */
resources=.array~of(.TestResource~new('aws-64'),.TestResource~new('oci-64'))
gci=.GeneralizedComputeIntentionProvider~new(.TestCompute~new(resources), ,
  .TestAllow~new,.TestAllow~new,.TestAllow~new)
admitted=.CloudEconomicIntentionBridge~new~admissibleOffers(gci,'workload',.nil,offers)
call assert admitted~items=1,'advisory route admission only'
call assert admitted[1]['id']=='oci-64','hard veto preserved'
say 'PASS 22 planner, scheduler, forecast and intention integration checks'
exit 0
assert:
  use arg predicate, explanation
  if \predicate then do
    say 'FAIL:' explanation
    exit 1
  end
  return
::class TestResource
::method init
  expose id
  use arg id
::attribute id get
::class TestCompute subclass ComputeIntentionAdapter
::method init
  expose resources
  use arg resources
::method discoverCandidates
  expose resources
  return resources
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(resource~id=='oci-64','compute','capability veto')
::class TestAllow subclass AllocationIntentionAdapter
::method assess
  return .IntentionAssessment~new(.true,'test','pass')
::requires 'CloudEconomics.cls'
::requires 'GeneralizedComputeIntentions.cls'
