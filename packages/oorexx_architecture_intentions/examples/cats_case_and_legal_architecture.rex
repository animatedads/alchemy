/* Qualified design handoff, not case creation, legal advice or a live workflow. */
parse arg destination
if destination == '' then destination = 'cats-case-architecture.json'
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('cats-governed','I Love Cats - relationship and legal workflow')
p~domain~statement('We want to know how reputation incidents turn into cases and legal reviews','product owner','workshop://scope')

caps = p~capabilities
caps~assess('reputation','REQUIRED','brand owner','Incidents need investigation')
caps~place('reputation','DOMAIN','brand_interaction_effect', -
  'brand analyst','observed interaction evidence','architect', -
  'Do not conflate observations with third-party reputation truth','catalog://brand')
caps~assess('case_management','REQUIRED','case owner','Resolution needs durable state')
caps~place('case_management','DOMAIN','relationship_case', -
  'case owner','case lifecycle and references','architect', -
  'Case is the coordinator, not the domain truth','catalog://case')
caps~assess('document_management','REQUIRED','document owner','Case uses documents')
caps~place('document_management','KNOWLEDGE','notnotes', -
  'document manager','semantic document revisions','architect', -
  'Bytes and legal holds remain separately qualified','catalog://notnotes')
caps~assess('legal','REQUIRED','counsel','Legal review may be required')
caps~place('legal','GOVERNANCE','institutional_policy', -
  'qualified counsel','published policy and control rule','architect', -
  'Only counsel issues legal decisions','catalog://policy')

r = p~capabilityRelationships
r~relate('incident-case','reputation','case_management','OBSERVATION', -
  'brand-observation-id','brand head','Investigate adverse incident','brief://incident')
r~relate('case-evidence','case_management','document_management','REFERENCE', -
  'case-evidence-id','records officer','Refer to document without copying content', -
  'design://evidence')
r~relate('case-legal','case_management','legal','REVIEW_REQUEST', -
  'case-id/revision','legal head','Request counsel review, not legal effect', -
  'design://legal-review')
r~govern('case-legal','legal team','PRIVILEGED','legal review', -
  'legal hold decision owned by counsel','escalate ambiguous outcomes', -
  'records officer','policy://legal')
r~reference('case-legal','case register','case id and revision', -
  'counsel-only projection','case owner','contract://case')

plan = planner~plan(p)
call lineout destination,.JSON~toJSON(plan)
call lineout destination
call stream destination,'C','CLOSE'
say 'Status:' plan['state']
say 'Cross-domain relations:' plan['capabilityRelationships']['count']
say 'Still-open questions:' plan['openQuestions']~items
say 'Requested runtime components:' plan['buildRequest']['requirements']~items
say 'Queue Fabric requested without an explicit interconnect:' hasQueue(plan)
say 'Wrote:' destination
exit 0
hasQueue:
  use arg plan
  do item over plan['buildRequest']['requirements']
    if item['componentId'] == 'queue_fabric' then return 'YES'
  end
  return 'NO'
::requires 'ArchitecturePlanner.cls'
