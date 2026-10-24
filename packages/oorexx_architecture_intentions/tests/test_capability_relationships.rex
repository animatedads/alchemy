/* Named domain services keep independent authoritative records. All transitions
 * are design proposals; no case, document, queue, legal system or IdP is called. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cat-risk','Cat support, legal and reputational governance')
start = planner~plan(p)
call assert start['capabilityRelationships']['count'] == 0,'no implied relationship graph'
call assert start['buildRequest']['requirements']~items == 0,'no mandatory enterprise layers'

caps = p~capabilities
caps~assess('crm','REQUIRED','customer owner','Customer interactions')
caps~place('crm','DOMAIN','relationship_crm','CRM team','relationship records','architect', -
  'CRM owns interactions only','portfolio://crm')
caps~assess('case_management','REQUIRED','case owner','Customer case resolution')
caps~place('case_management','DOMAIN','relationship_case','case desk', -
  'case workflow and references','architect','Cases coordinate only','portfolio://case')
caps~assess('reputation','REQUIRED','brand director','Reputational incident triage')
caps~place('reputation','DOMAIN','brand_interaction_effect','brand analyst', -
  'observed interaction evidence','architect','External reputation is separate','portfolio://brand')
caps~assess('document_management','REQUIRED','records director','Case evidence documents')
caps~place('document_management','KNOWLEDGE','notnotes','record owner', -
  'document revisions','architect','NotNotes owns graph and semantics','portfolio://documents')
caps~assess('legal','REQUIRED','legal owner','Review legal impact')
caps~place('legal','GOVERNANCE','institutional_policy','policy custodian', -
  'published policy and controls','architect','Counsel alone makes legal decisions','portfolio://policy')

r = p~capabilityRelationships
r~relate('observe-case','reputation','case_management','OBSERVATION', -
  'brand-observation-id','brand lead','Open follow-up to reported incident','ticket://brand/1')
r~relate('crm-case','crm','case_management','REFERENCE', -
  'crm-interaction-id','support lead','Tie contact to service ticket','ticket://crm/1')
r~relate('case-document','case_management','document_management','REFERENCE', -
  'case-evidence-id','records lead','Attach document reference without copying document','record://case-doc')
r~relate('case-legal','case_management','legal','REVIEW_REQUEST', -
  'case-review-id','legal lead','Counsel reviews facts and decides legal effect','case://counsel')
r~relate('case-reputation','case_management','reputation','PUBLICATION', -
  'case-outcome-id','brand director','Publish reviewed outcome into brand evidence','review://brand')

plan = planner~plan(p)
call assert plan['capabilityRelationships']['count'] == 5,'five separate relationship intentions'
call assert hasQuestion(plan,'rel_observe-case_governance'), -
  'incident-to-case has its own access and retention questions'
call assert hasQuestion(plan,'rel_case-legal_reference'), -
  'legal review may not take untyped legal evidence'
call assert hasQuestion(plan,'rel_case-document_transport'), -
  'a domain relationship does not choose RPC, direct, JMS or queue'
call assert \hasComponent(plan,'queue_fabric'),'case workflow does not imply Queue Fabric'
call assert \hasComponent(plan,'connect_selector'),'domain relationships do not imply a selector'

p~links~link('case-review-link','case','legal-review','compliance', -
  'COMMAND','architect','Request human counsel review')
p~links~bind('case-review-link','queue_fabric','review queue with separately tested commit','architect')
p~links~serviceIntent('case-review-link','case.legalReview','ENQUEUE', -
  'DURABLE','legal-reviews','architect','Durable request, not legal approval')
r~bind('case-legal','case-review-link','architect','diagram://counsel-queue')
r~govern('case-legal','legal policy owner','PRIVILEGED','legal review', -
  'legal hold may supersede disposal','retry and escalate unknown result', -
  'records counsel','policy://confidential')
r~reference('case-legal','case service','typed case ID and revision', -
  'counsel-only projection','records officer','api://case-ref')
plan = planner~plan(p)
call assert relationStatus(plan,'case-legal','PROPOSED_REQUIRES_QUALIFICATION'), -
  'qualified design completeness is not live approval'
call assert hasComponent(plan,'queue_fabric'),'explicit queue link selects its dependency'
call assert hasQuestion(plan,'cap_legal_legal_owner'), -
  'legal decision authority still remains open'
call assert plan['capabilityRelationships']['executable'] == .JSON~false, -
  'relationship projection never executes a service'

/* Source metadata and linked record authority survive native JSON roundtrip. */
serialized = .JSON~toJSON(plan['capabilityRelationships'])
parsed = .JSON~fromJSON(serialized)
call assert parsed['count'] == 5,'schema serialises'
call assert parsed['relationships']~items == 5,'projection roundtrip complete'

/* Technically unworkable relation pattern is an inconsistency. */
p~links~link('bad-review-link','case','legal-review','compliance', -
  'EVENT','architect','Wrong event semantics for review request')
r~bind('case-legal','bad-review-link','architect','diagram://bad-pattern')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_REL_PATTERN_MISMATCH'), -
  'a review request cannot be mapped to an event-only link'
r~bind('case-legal','case-review-link','architect','diagram://restored')

/* Counterfactual scenario clones preserve independently owned relationships. */
comparison = .ArchitectureScenarioComparison~new(planner)
local = .ArchitectureScenario~new('local','Local','Local service candidate','architect')
comparison~register(local)
remote = .ArchitectureScenario~new('cloud','Cloud','Remote qualified candidate','architect')
remote~placeCapability('case_management','DOMAIN','EXTERNAL', -
  'outsourced service desk','case orchestration contract', -
  'External case provider scenario','supplier://case-contract')
comparison~register(remote)
prior = planner~plan(p)
options = comparison~compare(p)
call assert options['capabilityRelationshipMatrix']~items == 5, -
  'scenario comparison now includes relationship ownership graph'
call assert options['scenarios'][1]['plan']['capabilityRelationships']['count'] == 5, -
  'scenario retains graph without modifying original'
call assert options['capabilityRelationshipMatrix'][1]['ownerByScenario']['local'] \== -
    options['capabilityRelationshipMatrix'][1]['ownerByScenario']['cloud'], -
    'scenario can change domain authority without altering the business requirement'
call assert planner~plan(p)['capabilityRelationships']['count'] == prior['capabilityRelationships']['count'], -
  'pure comparison does not mutate project'

/* Customer exclusion must fail closed; no implicit scope resurrection. */
caps~assess('case_management','NOT_REQUIRED','customer','Remove case management')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_REL_CAPABILITY_EXCLUDED'), -
  'proposed relationship cannot overrule a customer scope exclusion'
call assert plan['state'] == 'INCONSISTENT','excluded source/target blocks readiness'
call assert \hasComponent(plan,'relationship_case'), -
  'excluded case component must not survive as a runtime requirement'

say 'PASS capability graph: CRM/brand/case/NotNotes/legal ownership, references, controls, scenarios and exclusions'
exit 0
assert:
  use arg truth, reason
  if truth then return
  say 'FAIL:' reason
  exit 1
hasComponent:
  use arg plan, id
  do component over plan['buildRequest']['requirements']
    if component['componentId'] == id then return .true
  end
  return .false
hasQuestion:
  use arg plan, id
  do q over plan['openQuestions']
    if q['id'] == id then return .true
  end
  return .false
hasIssue:
  use arg plan, code
  do item over plan['issues']
    if item['code'] == code then return .true
  end
  return .false
relationStatus:
  use arg plan, id, status
  do item over plan['capabilityRelationships']['relationships']
    if item['id'] == id & item['status'] == status then return .true
  end
  return .false
::requires 'ArchitectureScenarios.cls'
