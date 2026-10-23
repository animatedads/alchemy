/* Exercises actual Generalized Compute Intentions, JobNodeAllocator hard
 * eligibility policy and Memory Fabric capacity planner on native ooRexx. */
numeric digits 20
root=arg(1)
offers=.CloudEconomicIO~read(root||'/fixtures/offers.tsv')
jobs=.CloudEconomicIO~read(root||'/fixtures/jobs.tsv')
now=1791000000
resources=.array~new
do offer over offers
  resources~append(.MarketResource~new(offer['id']))
end
calc=.TestCostCompute~new(resources)
alloc=.TestCostAdmission~new
wlu=.TestCostAdmission~new
router=.TestCostAdmission~new
intentions=.GeneralizedComputeIntentionProvider~new(calc,alloc,wlu,router)
planner=.CloudEconomicAuthorityPlanner~new
/* Price flags alone MUST NOT permit a fabric split in authority-bound mode. */
none=planner~evaluate(jobs[1],offers,now,intentions,'workload')
call assert none~decision['selected']='oci-64','no fabric plan prevents split'
call assert none~status='ADVISORY_HANDOFF_READY','eligible single-node advisory'
call assert \none~dispatchable,'economic handoff never dispatchable'
call assert none~selectedCandidates~items=1,'holds original candidate'
call assert none~selectedCandidates[1]~resource == resources[6], 'original object retained'
/* Real fabric registry and capacity plan with matching quote provider IDs. */
GB=1024*1024*1024
registry=.MemoryFabricRegistry~new('price-economics-test')
registry~registerProvider(.MemoryFabricProvider~new('aws-32','MI','MU-A','MI-A', ,
 'aws-eu-west-2a','host-a','queue://a',32*GB,0,'ACTIVE','ACCEPTING',1,1,'boot-a'))
registry~registerProvider(.MemoryFabricProvider~new('aws-32b','MI','MU-B','MI-B', ,
 'aws-eu-west-2a','host-b','queue://b',32*GB,0,'ACTIVE','ACCEPTING',1,1,'boot-b'))
mem=.MemoryFabricCapacityPlanner~new(registry)
proof=mem~plan('MU-X','host-x','aws-eu-west-2a',64*GB,.false,2,.MemoryFabricLocality~SAME_SITE)
call assert proof~complete & proof~providerCount=2,'real fabric 64 GiB proof'
noRegistry=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,proof)
call assert noRegistry~decision['selected']='oci-64','fabric registry evidence mandatory'
selected=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,proof,.nil,.nil,registry)
call assert selected~decision['selected']='aws-32+aws-32b','authority-gated memory pair'
call assert selected~selectedCandidates~items=2,'both provider candidate objects retained'
call assert selected~status='ADVISORY_HANDOFF_READY','multi-fragment advisory ready'
/* A genuine Fabric provider at a different site cannot validate the price
 * of a same-named economic offer in another advertised location. */
offers[2]['site']='unverified-site'
siteVeto=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,proof,.nil,.nil,registry)
call assert siteVeto~decision['selected']='oci-64','fabric registry and quoted site must match'
offers[2]['site']='aws-eu-west-2a'

/* Router/WLU veto cannot be reversed by cost or fabricated fabric evidence. */
wlu~deny='aws-32b'
blocked=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,proof,.nil,.nil,registry)
call assert blocked~decision['selected']='oci-64','WLU veto stops cheaper split'
wlu~deny=''
calc~deny='oci-64'
blockSingle=planner~evaluate(jobs[1],offers,now,intentions,'workload')
call assert blockSingle~decision['selected']\='oci-64','compute veto excludes OCI notwithstanding its lower tariff'
calc~deny=''
/* Test a real JobNodeAllocator policy against explicit binding, generation,
 * fresh/expired observation and job free RAM. */
requirements=.JobNodeRequirement~new(.array~of('UK'),.nil,.nil,.nil,.nil, ,
 .array~of('ooRexx'),.nil,'',65536,0,8,65536,0,8)
request=.JobPlacementRequest~new('memory-job',requirements)
cap=.NodeCapabilityStatement~new('compute-node',1,'proof',.array~of('UK'), ,
 .nil,.nil,.nil,.nil,.array~of('ooRexx'),.nil,'',65536,0,8)
capacity=.NodeCapacityObservation~new('compute-node',1,1,now*1000, ,
 (now+600)*1000,65536,0,8,0)
binding=.directory~new
binding['offer_id']='oci-64'; binding['node_id']='compute-node'
p=.directory~new
p['binding']=binding; p['request']=request;p['capability']=cap;p['capacity']=capacity
nodeProof=.directory~new
nodeProof['oci-64']=p
policy=.JobNodeEligibilityPolicy~new
existing=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,.nil,nodeProof,policy)
call assert existing~decision['selected']='oci-64','real allocator eligibility enables existing node'
call assert existing~status='ADVISORY_HANDOFF_READY','existing node still advisory'
call assert offers[2]['fabric_ok']='1', 'authority planner did not mutate upstream quote'
underspec=.JobNodeRequirement~new(.array~of('UK'),.nil,.nil,.nil,.nil, ,
 .array~of('ooRexx'),.nil,'',1024,0,8,1024,0,8)
underRequest=.JobPlacementRequest~new('memory-job',underspec)
underGate=.CloudEconomicNodeEvidenceGate~new~assess(offers[6],jobs[1], ,
 binding,underRequest,cap,capacity,now*1000,policy)
call assert underGate['reason']='UNDERSTATED_NODE_REQUIREMENTS', ,
 'real allocator request cannot understate economic memory'
otherRequest=.JobPlacementRequest~new('different-job',requirements)
wrongJob=.CloudEconomicNodeEvidenceGate~new~assess(offers[6],jobs[1], ,
 binding,otherRequest,cap,capacity,now*1000,policy)
call assert wrongJob['reason']='JOB_REQUEST_MISMATCH','job identity is bound'

capacityExpired=.NodeCapacityObservation~new('compute-node',1,1,now*1000, ,
 (now-1)*1000,65536,0,8,0)
p['capacity']=capacityExpired
stale=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,.nil,nodeProof,policy)
call assert stale~decision['status']='NO_ELIGIBLE_OPTION','expired allocator observation veto'
p['capacity']=capacity
binding['node_id']='wrong-node'
wrong=planner~evaluate(jobs[1],offers,now,intentions,'workload',.nil,.nil,.nil,nodeProof,policy)
call assert wrong~decision['status']='NO_ELIGIBLE_OPTION','false quote-node binding veto'
call assert alloc~mutations=0 & wlu~mutations=0 & router~mutations=0, ,
 'no admission, lease or dispatch mutation'
say 'PASS authority-backed intention / memory / JNA eligibility / non-mutation'
exit 0
assert: procedure
  use arg condition, message
  if \condition then do
    say 'FAIL:' message
    exit 1
  end
  return
::class MarketResource
::method init
 expose id
 use arg id
::attribute id get
::class TestCostCompute subclass ComputeIntentionAdapter
::method init
 expose resources deny
 use arg resources
 deny=''
::attribute deny
::method discoverCandidates
 expose resources
 return resources
::method assess
 expose deny
 use arg workload,resource,context=.nil
 return .IntentionAssessment~new(resource~id\=deny,'compute','resource check')
::class TestCostAdmission subclass AllocationIntentionAdapter
::method init
 expose deny mutations
 deny=''; mutations=0
::attribute deny
::attribute mutations get
::method assess
 expose deny
 use arg workload,resource,context=.nil
 return .IntentionAssessment~new(resource~id\=deny,'admission','capacity check')
::requires 'CloudEconomicsAuthority.cls'
::requires 'GeneralizedComputeIntentions.cls'
::requires 'JobNodeAllocator.cls'
::requires 'MemoryFabric.cls'
