/* Non-executable architecture request from an intentionally vague proposal.
 * Usage: rexx examples/cats_scope_and_policies.rex [output.json]
 */
parse arg outputPath
if outputPath == '' then outputPath = 'cats-discovery-plan.json'
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
p = .ArchitecturePlanner~new(cat)~project('cats-platform','I Love Cats')
p~domain~statement('We need an I Love Cats business platform', -
  'Customer stakeholder','workshop day 1')
p~domain~entity('cats','SUBJECT','Cats','product owner')
p~domain~entity('mysql','SYSTEM','Existing MySQL?','customer', '', 'EXISTING')
p~domain~entity('flatfiles','DATASET','Existing flat files?','customer', '', 'EXISTING')
p~includeScope('CUSTOMER','cats-customer')
p~links~link('internal-command','application','worker','core','COMMAND', -
  'architect','Internal work submission')
p~links~bind('internal-command','queue_fabric','Internal queue standard','architect')
p~links~link('erp-event','billing','erp','integration','EVENT', -
  'architect','Enterprise integration')
p~links~bind('erp-event','jms','Customer requested JMS','customer')
p~groundRules~addRule('jms-enterprise','Customer enterprise standard','rev-4', -
  'LINK','erp-event','REQUIRE_BINDING','interconnect',.Array~of('jms'), -
  'customer architect','policy://example/enterprise')
p~groundRules~addRule('spiral1','SPIRAL 1','to-be-verified', -
  'CUSTOMER','cats-customer','CONTROL','CONTROL_REGISTER_UNKNOWN',.Array~new, -
  'compliance owner','customer://sp1/request')
plan = .ArchitecturePlanner~new(cat)~plan(p)
call lineout outputPath, .JSON~toJSON(plan)
call lineout outputPath
call stream outputPath,'C','CLOSE'
say 'Status:' plan['state']
say 'Questions:' plan['openQuestions']~items 'Issues:' plan['issues']~items
say 'Runtime components requested:' plan['buildRequest']['requirements']~items
say 'Unresolved integrations:' plan['buildRequest']['externalIntegrationRequirements']~items
say 'Wrote:' outputPath
::requires 'ArchitecturePlanner.cls'
