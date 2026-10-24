/* Business/authority placement qualification, no optional feature inflation. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-business','I Love Cats Institutional Platform')
call assert planner~plan(p)['buildRequest']['requirements']~items == 0, -
  'unassessed capabilities do not install the entire estate'
p~capabilities~discover('customer','Capability discovery is explicitly requested')
call assert hasQuestion(planner~plan(p),'cap_inventory'), -
  'initial business capability inventory requested'
p~capabilities~assess('crm','REQUIRED','relationship owner','We serve customers')
p~capabilities~place('crm','DOMAIN','relationship_crm', -
  'relationship team','customer relationship records','architect', -
  'Keep CRM ownership distinct from case and billing','customer://decision/crm')
p~capabilities~clarify('crm','subjects','Customers are humans; cats are business subjects', -
  'product owner','meeting://scope')
p~capabilities~assess('document_management','REQUIRED', -
  'records owner','Our business creates customer documents')
p~capabilities~place('document_management','KNOWLEDGE','notnotes', -
  'records manager','editable contract and document truth', -
  'architect','Existing semantic document API is a candidate','portfolio://notnotes')
p~capabilities~assess('case_management','REQUIRED','case owner','Support cases')
p~capabilities~place('case_management','DOMAIN','relationship_case', -
  'service desk','case coordination','architect', -
  'Legal effect stays with external authority','portfolio://case')
p~capabilities~assess('legal','REQUIRED','legal lead','Legal contract work')
p~capabilities~place('legal','GOVERNANCE','institutional_policy', -
  'legal counsel','policy reference and control lifecycle','architect', -
  'Only the policy substrate is placed','portfolio://policy')
p~capabilities~assess('reputation','REQUIRED','brand lead','Assess brand interventions')
p~capabilities~place('reputation','DOMAIN','brand_interaction_effect', -
  'brand analyst','observed interaction-effect evidence','architect', -
  'Analysis does not own external reputation truth','portfolio://brand')
p~capabilities~assess('authentication','REQUIRED','security lead','Customer login')
p~capabilities~place('authentication','SECURITY','EXTERNAL', -
  'identity team','customer identity-provider boundary','security lead', -
  'Authentication remains external to secret broker','contract://identity')
p~capabilities~protect('public-cat-account','human-owner','owner-principal', -
  'cat-account','read','EDGE','customer IdP','security lead', -
  'Authenticate owner, not the cat','design://security-gate')
p~links~link('cats-api','browser','cats','public','REQUEST_REPLY', -
  'architect','Customer-owned cat records')
plan = planner~plan(p)
call assert hasQuestion(plan,'cap_auth_link_cats-api'), -
  'Each new link needs its own authentication decision'
p~capabilities~exemptBoundary('cats-api', -
  'Pilot has no external endpoint; re-evaluate before going public', -
  'security architect','review://local-only')
plan = planner~plan(p)
call assert \hasQuestion(plan,'cap_auth_link_cats-api'), -
  'Attributed exemption explicitly resolves the link question'
call assert plan['businessCapabilities']['authenticationExemptions']~items == 1, -
  'Trust exception is a proposal, not silent default'
p~groundRules~addRule('require-api-auth','Security architecture','1', -
  'LINK','cats-api','REQUIRE_AUTH_BOUNDARY','cats-api', -
  .Array~of('PROTECTED'),'security council','policy://identity')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_POLICY_AUTH_EXEMPTION_DENIED'), -
  'Exemption cannot override higher security ground rule'
p~capabilities~protect('cats-api','owner','owner-principal','cat-profile', -
  'update','SERVICE','customer IdP','security architect', -
  'Authenticate and authorize mutations at service boundary', -
  'review://service-boundary')
plan = planner~plan(p)
call assert \hasIssue(plan,'ARCH_POLICY_AUTH_EXEMPTION_DENIED'), -
  'Security policy satisfied after explicit protection replaces exemption'
p~capabilities~assess('secrets','NOT_REQUIRED','security lead', -
  'No application-managed secret lifetime in local pilot')
plan = planner~plan(p)
call assert hasComponent(plan,'relationship_crm'),'CRM candidate requested after placement'
call assert hasComponent(plan,'relationship_case'),'Case authority selected separately'
call assert hasComponent(plan,'notnotes'),'NotNotes document truth requested'
call assert hasComponent(plan,'institutional_policy'),'Legal policy, not legal decision'
call assert hasComponent(plan,'brand_interaction_effect'),'Brand analysis selected'
call assert \hasComponent(plan,'secret_broker'),'Authentication not Secret Broker'
call assert \hasComponent(plan,'queue_fabric'),'No queue implied by case management'
call assert plan['buildRequest']['businessCapabilityRequirements']~items == 1, -
  'External IdP is an unresolved requirement'
call assert hasQuestion(plan,'cap_legal_legal_owner'), -
  'Legal decision authority must still be answered'
call assert plan['businessCapabilities']['trustBoundaries']~items == 2, -
  'Exact enforcement boundary recorded'
call assert hasQuestion(plan,'cap_authentication_mechanisms'), -
  'Identity assurance still requires an evidence-backed answer'
call assert \hasQuestion(plan,'cap_crm_subjects'), -
  'Answered CRM subject question is closed'
call assert plan['state'] == 'NEEDS_DECISIONS','proposed placement not automatic approval'

/* Requirements can be removed without leaving stale dependencies. */
p~capabilities~assess('crm','NOT_REQUIRED','customer', -
  'For this alternative, CRM is outside the system')
plan = planner~plan(p)
call assert \hasComponent(plan,'relationship_crm'), -
  'No stale CRM after requirement revoked'
call assert \hasQuestion(plan,'cap_crm_source'), -
  'Revoked feature no longer drives questions'

/* Scoped legal requirement: policy cannot be bypassed by feature omission. */
p~includeScope('CUSTOMER','cats-ltd')
p~groundRules~addRule('legal-mandate','Customer legal controls','1', -
  'CUSTOMER','cats-ltd','REQUIRE_CAPABILITY','legal', -
  .Array~of('REQUIRED'),'legal team','policy://legal')
p~groundRules~addRule('legal-policy-owner','Client policy platform','1', -
  'CUSTOMER','cats-ltd','REQUIRE_CAPABILITY_OWNER','legal', -
  .Array~of('institutional_policy'),'client counsel','policy://owner')
plan = planner~plan(p)
call assert \hasIssue(plan,'ARCH_POLICY_REQUIRES'), -
  'Matching required capability and owner satisfy placement rule'
p~capabilities~assess('legal','NOT_REQUIRED','developer', -
  'Attempt to avoid the customer rule')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_POLICY_REQUIRES'), -
  'Customer legal policy cannot be overridden by a local omission'
p~capabilities~assess('legal','REQUIRED','legal lead','Restore legal scope')
p~groundRules~addRule('conflicting-policy','Another institutional rule','1', -
  'CUSTOMER','cats-ltd','DENY_CAPABILITY','legal', -
  .Array~of('REQUIRED'),'policy owner','policy://contradiction')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_POLICY_CONFLICT'), -
  'Conflicting mandatory and forbidden capability policies are explicit'

/* Scenario does not change business scope; may change the proposed owner. */
comparison = .ArchitectureScenarioComparison~new(planner)
one = .ArchitectureScenario~new('reference','In-house cases', -
  'Current candidate service ownership','architect')
comparison~register(one)
two = .ArchitectureScenario~new('outsourced','External cases', -
  'Third-party relationship case system','architect')
two~placeCapability('case_management','INTEGRATION','EXTERNAL', -
  'customer vendor','external case system','Vendor transition','proposal://outsourcing')
comparison~register(two)
report = comparison~compare(p)
call assert hasComponent(report['scenarios'][1]['plan'],'relationship_case'), -
  'Baseline retains case service'
call assert \hasComponent(report['scenarios'][2]['plan'],'relationship_case'), -
  'Scenario changes case owner without altering base'
call assert report['businessCapabilityMatrix']~items == cat~definition['businessCapabilities']~items, -
  'Scenario comparison exposes all capability choices'
call assert report['scenarios'][2]['plan']['buildRequest']['businessCapabilityRequirements']~items == 2, -
  'External identity and case providers remain unresolved'
call assert p~capabilities~placements['case_management']['ownerComponent'] == -
  'relationship_case','Scenario did not mutate source project'
say 'PASS business capability placement, authentication boundaries, legal policy and scenario isolation'
exit 0
assert:
  use arg test, why
  if test then return
  say 'FAIL:' why
  exit 1
hasComponent:
  use arg plan, id
  do r over plan['buildRequest']['requirements']
    if r['componentId'] == id then return .true
  end
  return .false
hasQuestion:
  use arg plan, id
  do q over plan['openQuestions']
    if q['id'] == id then return .true
  end
  return .false
hasIssue:
  use arg plan, id
  do q over plan['issues']
    if q['code'] == id then return .true
  end
  return .false
::requires 'ArchitectureScenarioWriter.cls'
