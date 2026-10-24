/* Business requirements and service placement before selecting a 27-layer stack. */
parse arg destination
if destination == '' then destination = 'cats-capability-plan.json'
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-capabilities','I Love Cats customer platform')
p~domain~statement('We want an I Love Cats business platform', -
  'business sponsor','discovery meeting')
p~domain~entity('cat','SUBJECT','Customer cat','product manager')
p~domain~entity('owner','PERSON','Customer/owner','product manager')
p~domain~entity('owner-principal','PRINCIPAL','Owner user account','identity team')
p~domain~relate('owner','owner-principal','AUTHENTICATES_AS', -
  'Owner signs in','identity team')
p~domain~relate('owner-principal','cat','REPRESENTS', -
  'Owner acts on behalf of cat','product manager')
p~includeScope('CUSTOMER','cats-ltd')
p~groundRules~addRule('cats-legal','Customer legal policy','1', -
  'CUSTOMER','cats-ltd','REQUIRE_CAPABILITY','legal', -
  .Array~of('REQUIRED'),'legal office','policy://cats-legal')
p~capabilities~discover('business architect', -
  'Discover legal, CRM, case, document and identity requirements')
portfolio = p~capabilities
portfolio~assess('crm','REQUIRED','sales head','Customer servicing is in scope')
portfolio~place('crm','DOMAIN','relationship_crm','sales operations', -
  'customer record of relationship','architect', -
  'Use existing domain candidate','portfolio://crm')
portfolio~assess('case_management','REQUIRED','support head','Support cases in scope')
portfolio~place('case_management','DOMAIN','relationship_case', -
  'support operations','case workflow and escalation','architect', -
  'Case management is not legal authority','portfolio://case')
portfolio~assess('document_management','REQUIRED','records manager', -
  'Create, revise and issue customer documents')
portfolio~place('document_management','KNOWLEDGE','notnotes', -
  'document owner','document object and revision truth', -
  'architect','Use NotNotes semantic domain','portfolio://notnotes')
portfolio~assess('legal','REQUIRED','customer counsel','Applicable legal obligations')
portfolio~place('legal','GOVERNANCE','institutional_policy', -
  'qualified legal counsel','policy and control publication', -
  'architect','Legal advice remains external','portfolio://policy')
portfolio~assess('reputation','UNDECIDED','brand head', -
  'No defined reputation program yet')
portfolio~assess('authentication','REQUIRED','security lead', -
  'Customers need access to their accounts')
portfolio~place('authentication','SECURITY','EXTERNAL','identity team', -
  'customer identity provider','security architect', -
  'Authenticate owner, not the cat','architecture://authentication')
portfolio~protect('owner-api','owner','owner-principal','cat-profile', -
  'update','EDGE','customer IdP','security architect', -
  'Browser API boundary requires login','design://edge')
portfolio~assess('secrets','NOT_REQUIRED','security lead', -
  'No distinct application secret-management requirement established yet')
plan = planner~plan(p)
call lineout destination,.JSON~toJSON(plan)
call lineout destination
call stream destination,'C','CLOSE'
say 'Status:' plan['state']
say 'Open discovery and authority questions:' plan['openQuestions']~items
say 'Requested runtime candidates:' plan['buildRequest']['requirements']~items
say 'External domain authority requirements:' -
  plan['buildRequest']['businessCapabilityRequirements']~items
say 'No legal certification or deployment authority claimed'
say 'Wrote:' destination
::requires 'ArchitecturePlanner.cls'
