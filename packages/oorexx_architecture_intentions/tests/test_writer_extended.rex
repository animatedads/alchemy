parse arg dir
if dir == '' then exit 2
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
p = .ArchitecturePlanner~new(cat)~project('bundle','Bundle')
p~domain~statement('We would like a catalog for cats','owner')
p~links~link('a-b','a','b','core','EVENT','owner','messages')
p~links~bind('a-b','jms','legacy external bus','owner')
p~groundRules~addRule('compliance','SPIRAL 1','unknown','GLOBAL','*', -
  'CONTROL','CONTROL_INVENTORY_UNDEFINED',.Array~new,'owner','customer policy')
plan = .ArchitecturePlanner~new(cat)~plan(p)
if plan['state'] \== 'NEEDS_DISCOVERY' then exit 1
items = .ArchitecturePackageWriter~new~write(plan,dir)
if items~items \== 14 then exit 1
files = .Array~of('architecture-plan.json','questions.json','decisions.json', -
  'features.json','issues.json','build-request.json','cost.json', -
  'business-capabilities.json','scope.json','ground-rules.json','interconnects.json', -
  'connector-reviews.json','interconnect-alternatives.json', -
  'capability-relationships.json')
do f over files
  path = dir'/'f
  if stream(path,'C','QUERY EXISTS') == '' then exit 1
  document = .JSON~fromJSON(charin(path,1,chars(path)))
  call stream path,'C','CLOSE'
  if document == .nil then exit 1
end
say 'PASS fourteen-file JSON artifact writer'
::requires 'ArchitecturePackageWriter.cls'
