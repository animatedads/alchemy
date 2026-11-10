/* Native ooRexx test fixture and example. No orchestration language. */
failures=0
passed=0
model=.DocyGraph~new
.DocyTypes~install(model)

model~addFact(.DocyFact~new('grid.ed209f.address','213.255.246.44','ip-address','etc/machines','r51','source:cloudctl'))
model~addFact(.DocyFact~new('cloudctl.tests.passed',62,'integer','cloudctl/test-results','run-A','source:test-runner'))

node=model~newNode('toc','toc.main')
model~addNode(node)
node=model~newNode('section','install.prereqs')
node~put('house','title','Prerequisites')
node~put('project','title','Installation prerequisites')
model~addNode(node)
node=model~newNode('factfield','machines.ed209f.address')
node~put('house','label','ed209f IPv4')
node~put('template','value',.DocyRef~new('grid.ed209f.address'))
model~addNode(node)
node=model~newNode('factfield','cloudctl.tests')
node~put('house','label','Passing tests')
node~put('template','value',.DocyRef~new('cloudctl.tests.passed'))
model~addNode(node)
node=model~newNode('credits','project.credits')
node~put('house','architecture','Tom Dyer')
node~put('house','coding','ChatGPT (DOCY prototype)')
node~put('house','writer','ChatGPT (DOCY prototype)')
model~addNode(node)
node=model~newNode('command','install.command')
node~put('house','command','rexx test.rex')
model~addNode(node)

node=model~newNode('table','machines.table')
node~header('Host')
node~header('IPv4 address')
cells=.array~new
cells~append(.DocyDatum~new('ed209f'))
cells~append(.DocyRef~new('grid.ed209f.address'))
node~addRow(cells)
model~addNode(node)
node=model~newNode('svg','diagram.network')
node~put('house','title','Shared network topology')
node~put('template','source','<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 30"><rect x="2" y="2" width="76" height="26" rx="4" fill="#d9eafe"/><text x="40" y="20" text-anchor="middle" font-size="10">DOCY</text></svg>')
model~addNode(node)
do key over model~nodes~allIndexes
  model~node(key)~authoredBy="tool:demo_test.rex"
end
t=.DocyDocument~new('template.project-docs','Project Template')
t~place('toc','toc.main',10)
t~place('prereqs','install.prereqs',20)
t~place('address','machines.ed209f.address',30)
t~place('credits','project.credits',99)
model~addDocument(t)

a=.DocyDocument~new('doc.grid-plan','Grid Plan','template.project-docs')
a~outputs~append('docs/grid-plan.md')
a~outputs~append('site/grid-plan.html')
a~place('machine-table','machines.table',35)
a~place('network-diagram','diagram.network',36)
model~addDocument(a)

mid=.DocyDocument~new("template.as-built","As-built template","template.project-docs")
mid~override("template","machines.ed209f.address","label","Operations IPv4")
model~addDocument(mid)
b=.DocyDocument~new('doc.as-built','As-built','template.as-built')
b~outputs~append('docs/as-built.md')
b~place('extra-tests','cloudctl.tests',40)
b~place('address-repeat','machines.ed209f.address',41)
model~addDocument(b)

c=.DocyDocument~new('doc.cloudctl-readme','Cloudctl README','template.project-docs')
c~outputs~append('README.md')
c~place('tests','cloudctl.tests',40)
c~place('cmd','install.command',50)
c~override('document','machines.ed209f.address','value','legacy address (intentional override)')
c~override('variant','install.prereqs','title','Operator handbook')
model~addDocument(c)

call check model~node('machines.ed209f.address')~key=='machines.ed209f.address','meaningful stable key'
call check model~document('doc.grid-plan')~effectivePlacements(model)~items==6,'inherited template and local placements'
call check model~document('doc.as-built')~effectivePlacements(model)~items==6,'local and inherited placement'
call check model~validate('doc.grid-plan')~count('STOP')==0,'grid validates'
call check model~validate('doc.cloudctl-readme')~count('STOP')==0,'cloudctl validates'
call check pos('Operations IPv4',model~publish('doc.as-built','markdown')['content'])>0,'nested template layer override'
call check pos('Operator handbook',model~publish('doc.cloudctl-readme','markdown')['content'])>0,'variant layer wins'

p=model~planFactChange('grid.ed209f.address','213.255.246.45','source:machines','change from machines file revision r52')
call check p~impactCount==4,'change impacts four outputs across three docs'
call check p~report~count('WARN')==1,'override shadow warning'
call check model~fact('grid.ed209f.address')~value=='213.255.246.44','plan does not mutate'
call check model~apply(p),'apply change accepted'
call check model~fact('grid.ed209f.address')~value=='213.255.246.45','fact changed once'
call check model~revision==1,'event revision advances'
call check model~events[1]~predecessor=='GENESIS','event predecessor linked'

r=model~publish('doc.grid-plan','markdown')
call check pos('213.255.246.45',r['content'])>0,'grid markdown follows fact'
call check pos('## Contents',r['content'])>0,'markdown TOC'
call check pos('| ed209f | 213.255.246.45 |',r['content'])>0,'typed table reference follows shared fact'
call check pos('Installation prerequisites',r['content'])>0,'project layer wins'
r=model~publish('doc.cloudctl-readme','markdown')
call check pos('legacy address (intentional override)',r['content'])>0,'document override wins'
call check pos('213.255.246.45',r['content'])==0,'shared value masked'

p=model~planNodeChange('install.prereqs','title','project','Before you install','writer:LLM','clearer title')
call check p~impactCount==4,'section change touches all docs'
call check model~apply(p),'section apply'
r=model~publish('doc.grid-plan','markdown')
call check pos('Before you install',r['content'])>0,'shared heading update'

p=model~planFactChange('cloudctl.tests.passed',63,'runner','run-B')
call check p~impactCount==2,'test count impacts two documents'
call check model~apply(p),'test fact update'
r=model~publish('doc.as-built','markdown')
call check pos('63',r['content'])>0,'test count bound from source'

/* Mixed validation: should report all stops instead of throwing. */
model~node('install.command')~put('project','command','rexx test.rex.')
model~node('project.credits')~put('project','writer','')
r=model~validate('doc.cloudctl-readme')
call check r~count('STOP')==2,'two STOP diagnostics accumulated'
r=model~publish('doc.cloudctl-readme','markdown')
call check r['content']=='','STOP prevents publication'
model~node('install.command')~put('project','command','rexx test.rex')
model~node('project.credits')~put('project','writer','ChatGPT (DOCY prototype)')

/* Unknown binding is explicitly diagnosed. */
model~node('machines.ed209f.address')~put('project','value',.DocyRef~new('missing.fact'))
r=model~publish('doc.grid-plan','html')
call check r['report']~count('WARN')>0,'unknown binding emits WARN'
model~node('machines.ed209f.address')~put('project','value',.DocyRef~new('grid.ed209f.address'))

/* A stale change plan is refused, with no unplanned edit. */
stale=model~planFactChange('cloudctl.tests.passed',64,'runner','old proposal')
fresh=model~planFactChange('cloudctl.tests.passed',65,'runner','newer proposal')
call check model~apply(fresh),'fresh proposal accepted'
call check \model~apply(stale),'stale proposal rejected'
call check stale~report~count('STOP')==1,'stale plan diagnostic'
call check model~fact('cloudctl.tests.passed')~value==65,'stale plan did not overwrite source fact'
/* Cyclic template inheritance must produce STOP, not recursion. */
cycle=.DocyDocument~new('doc.cycle','Cycle','doc.cycle')
cycle~outputs~append('bad.md')
model~addDocument(cycle)
report=model~validate('doc.cycle')
call check report~count('STOP')>=1,'template cycle gives STOP'
model~documents~remove('doc.cycle')
/* Deliver real generated outputs. */
saved=.DocyStore~save(model,"alchemy_shared_graph.docy")
loaded=.DocyStore~open(saved)
say loaded["report"]~summary
call check loaded["report"]~count("STOP")==0,"DOCY/2 parses without STOP"
restored=loaded["graph"]
call check restored~document("doc.grid-plan")~effectivePlacements(restored)~items==6,"placement roundtrip"
call check restored~revision==model~revision,'event revision survived snapshot'
call check restored~events~items==4,'event records survived snapshot'
call check restored~node('machines.table')~rows~items==1,'table rows survived snapshot'
call check pos('data:image/svg+xml',restored~publish('doc.grid-plan','html')['content'])>0,'SVG passive HTML rendering'
call check pos('<svg',restored~node('diagram.network')~at('template','source')~value)>0,'SVG source roundtrip'
call check pos("<table>",restored~publish("doc.grid-plan","html")["content"])>0,"table HTML after load"
call check pos("213.255.246.45",restored~publish("doc.grid-plan","markdown")["content"])>0,"reference roundtrip"
/* A damaged snapshot reports both unknown and duplicate node types. */
stream=.stream~new(saved)
stream~open('read')
raw=stream~charin(,stream~query('size'))
stream~close
badEnvelope=.json~fromJSON(raw)
bad=.directory~new
bad['key']=.JsonString~new('extra.unknown')
bad['type']=.JsonString~new('nonexistent-widget')
bad['layers']=.directory~new
badEnvelope['nodes']~append(bad)
duplicate=.directory~new
duplicate['key']=.JsonString~new('install.prereqs')
duplicate['type']=.JsonString~new('section')
duplicate['layers']=.directory~new
badEnvelope['nodes']~append(duplicate)
.json~toJsonFile('damaged_for_test.docy',badEnvelope,.true)
negative=.DocyStore~open('damaged_for_test.docy')
call check negative['report']~count('STOP')>=2,'loader accumulates multiple structural STOP diagnostics'
call writeFile 'alchemy_grid_plan.md', model~publish('doc.grid-plan','markdown')['content']
call writeFile 'alchemy_grid_plan.html', model~publish('doc.grid-plan','html')['content']
call writeFile 'cloudctl_README.md', model~publish('doc.cloudctl-readme','markdown')['content']
say 'DOCY v0.2 tests: 'passed 'PASS; 'failures 'FAIL'
if failures>0 then exit 1
exit 0

check:
  procedure expose passed failures
  use arg assertion,label
  if assertion then do
    say 'PASS 'label
    passed=passed+1
  end
  else do
    say 'FAIL 'label
    failures=failures+1
  end
return

writeFile:
  use arg path, value
  call lineout path,value,1
  call lineout path
return
::requires 'docy_v02.cls'
::requires "docy_store.cls"
