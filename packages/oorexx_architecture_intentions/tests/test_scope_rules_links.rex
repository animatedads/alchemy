/* Architecture scope, ground rule intersection, and per-edge bindings. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-demo','I Love Cats')
call assert planner~plan(p)['buildRequest']['requirements']~items == 0, -
  'no universal 27-layer runtime stack'
p~domain~statement('We are building an I Love Cats business platform', -
  'customer','meeting-2026-10-08')
p~domain~entity('cats','SUBJECT','Cats','product owner')
p~domain~entity('mysql','SYSTEM','Legacy MySQL','owner','', 'EXISTING')
p~domain~entity('files','DATASET','Legacy flat files','owner','', 'EXISTING')
plan = planner~plan(p)
call assert plan['state'] == 'NEEDS_DISCOVERY','business discovery before runtime decisions'
call assert hasQuestion(plan,'domain_scope_EXISTING_ESTATE'),'discovery asks about existing estate'
call assert hasQuestion(plan,'domain_subject_cats'),'cats do not authenticate by name'
call assert hasQuestion(plan,'domain_legacy_mysql'),'unverified legacy MySQL inventory'
call assert hasQuestion(plan,'domain_dataset_files'),'unverified flat-file inventory'
call assert \hasComponent(plan,'queue_fabric'),'no inferred queue fabric'
p~domain~clarify('BUSINESS_OUTCOME','Catalog/records for cats','product owner')
plan = planner~plan(p)
call assert \hasQuestion(plan,'domain_scope_BUSINESS_OUTCOME'), -
  'clarified business outcome no longer requires the same question'

/* Separate business subject, human actor, device and security principal. */
p~domain~entity('owner','PERSON','Cat owner','architect')
p~domain~entity('login','PRINCIPAL','Owner account','identity owner')
p~domain~entity('reader','DEVICE','Cat-flap RFID reader','hardware team')
p~domain~relate('owner','login','AUTHENTICATES_AS','Human login','identity owner')
p~domain~relate('login','cats','REPRESENTS','Acts for the cat','identity owner')
p~domain~relate('reader','cats','IDENTIFIES','RFID identification','hardware team')
plan = planner~plan(p)
call assert \hasQuestion(plan,'domain_subject_cats'),'identity model explicit'

/* Define three edges; these are integration semantics, NOT a global switch. */
p~links~link('mobile-api','mobile','catalog-api','public','REQUEST_REPLY', -
  'architect','Partner interactive call')
p~links~link('catalog-worker','catalog-api','worker','core','COMMAND', -
  'architect','Queued internal job')
p~links~link('billing','billing','erp','finance','EVENT', -
  'architect','Enterprise event bridge')
p~links~bind('mobile-api','json_rpc','Partner contract','customer')
p~links~bind('catalog-worker','queue_fabric','Local authority queue','architect')
p~links~bind('billing','jms','Existing enterprise bus','customer')
plan = planner~plan(p)
call assert plan['interconnects']['edges']~items == 3,'three separately modelled edges'
call assert hasComponent(plan,'queue_fabric'),'queue required by internal edge'
call assert plan['buildRequest']['externalIntegrationRequirements']~items == 2, -
  'JSON-RPC and JMS adapter requirements not faked as existing packages'
call assert hasQuestion(plan,'link_billing_BROKER'),'JMS needs broker proof'
call assert hasQuestion(plan,'link_mobile-api_CARRIER'),'JSON-RPC needs carrier proof'
call assert hasQuestion(plan,'link_catalog-worker_RECOVERY'),'Queue Fabric needs recovery contract'

/* Global permission plus customer restriction, after customer scope attached. */
rules = p~groundRules
rules~addRule('global-restrict','Org integration standard','2026-10','GLOBAL','*', -
  'DENY_BINDING','interconnect',.Array~of('jms'),'architect council','std://org/2026')
p~includeScope('CUSTOMER','cats-inc')
rules~addRule('customer-allow','Customer technical boundary','4','CUSTOMER','cats-inc', -
  'ALLOW_BINDING','interconnect',.Array~of('json_rpc','queue_fabric'), -
  'customer security','cus://integration/4')
plan = planner~plan(p)
call assert plan['state'] == 'INCONSISTENT','global prohibition must hold'
call assert hasIssue(plan,'ARCH_POLICY_DENIED'),'JMS denied by global policy'
call assert hasIssue(plan,'ARCH_POLICY_NOT_ALLOWED'),'customer disallows JMS'

/* Even a link-specific demand cannot silently supersede a global ban. */
rules~addRule('billing-demand','Enterprise integration contract','7','LINK','billing', -
  'REQUIRE_BINDING','interconnect',.Array~of('jms'), -
  'ERP owner','contract://erp/7')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_POLICY_CONFLICT'),'intersection detects impossible requirements'

/* An unrelated project's policy must not leak into the active project. */
rules~addRule('other-customer','Another customer','1','CUSTOMER','another-company', -
  'DENY_BINDING','interconnect',.Array~of('queue_fabric'), -
  'another architect','customer://other/1')
plan = planner~plan(p)
call assert plan['groundRules']['applicableRules']~items == 3, -
  'unattached customer ground rule inactive'

/* No invented SPIRAL 1 controls. Named policy without a versioned control set
 * remains a question even if someone records a PASS assertion. */
rules~addRule('spiral1','SPIRAL 1','customer-specified','GLOBAL','*', -
  'CONTROL','SPIRAL_1_CONTROL_INVENTORY',.Array~new, -
  'compliance owner','customer://policy/pending')
plan = planner~plan(p)
call assert hasQuestion(plan,'policy_spiral1'),'control inventory must be defined'
rules~evaluateControl('spiral1','PASS','internal reviewer','review://123', -
  'Preliminary evidence only')
plan = planner~plan(p)
call assert hasQuestion(plan,'policy_spiral1'),'unidentified controls not certified'
call assert plan['groundRules']['complianceStatus'] == 'REVIEW_ONLY_NOT_CERTIFIED', -
  'no false conformance assertion'

/* Hidden choices must not be resurrected into policy evaluation. */
p~answer('deployment_model','cloud','Exploring cloud','architect')
p~answer('interconnect','api','Exploring public APIs','architect')
p~answer('deployment_model','rexxos_mu_mi','Exploring MU/MI','architect')
rules~addRule('no-socket','Internal carrier mandate','1','GLOBAL','*', -
  'DENY_CHOICE','interconnect',.Array~of('api'),'architect','std://internal')
plan = planner~plan(p)
call assert \hasIssueFor(plan,'ARCH_POLICY_DENIED','no-socket'), -
  'hidden decision cannot violate active policy'
rules~addRule('not-in-catalog','Invalid copied policy','1','GLOBAL','*', -
  'DENY_CHOICE','imaginary_question',.Array~of('any'), -
  'customer','policy://missing')
plan = planner~plan(p)
call assert hasIssue(plan,'ARCH_POLICY_QUESTION_UNKNOWN'), -
  'policy cannot target a question that is not in the catalog'

say 'PASS scope discovery, scoped policy intersection, per-edge bindings, compliance gate'
exit 0
assert:
  use arg truth, explanation
  if truth then return
  say 'FAIL:' explanation
  exit 1
hasQuestion:
  use arg data, identity
  do question over data['openQuestions']
    if question['id'] == identity then return .true
  end
  return .false
hasComponent:
  use arg data, identity
  do component over data['buildRequest']['requirements']
    if component['componentId'] == identity then return .true
  end
  return .false
hasIssue:
  use arg data, code
  do issue over data['issues']
    if issue['code'] == code then return .true
  end
  return .false
hasIssueFor:
  use arg data, code, ruleId
  do issue over data['issues']
    if issue['code'] == code & issue~hasIndex('ruleId') then do
      if issue['ruleId'] == ruleId then return .true
    end
  end
  return .false
::requires 'ArchitecturePlanner.cls'
