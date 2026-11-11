/* DOCY shared placement/override plan qualification on native ooRexx. */
passed=0; failed=0
g=.DocyGraph~new
.DocyTypes~install(g)
heading=g~newNode('section','shared.heading')
heading~put('house','title','Original heading')
heading~authoredBy='tool:fixture'
g~addNode(heading)
second=g~newNode('section','shared.second')
second~put('house','title','Second heading')
second~authoredBy='tool:fixture'
g~addNode(second)
credits=g~newNode('credits','project.credits')
credits~put('house','architecture','Tom Dyer')
credits~put('house','coding','ChatGPT')
credits~put('house','writer','ChatGPT')
credits~authoredBy='tool:fixture'
g~addNode(credits)
t=.DocyDocument~new('template.project','Template')
t~place('first','shared.heading',10)
t~place('credits','project.credits',90)
g~addDocument(t)
a=.DocyDocument~new('doc.a','Project A','template.project')
a~outputs~append('a.md')
a~outputs~append('a.pdf')
g~addDocument(a)
b=.DocyDocument~new('doc.b','Project B','template.project')
b~outputs~append('b.odt')
g~addDocument(b)

p=g~planPlacementAdd('template.project','second','shared.second',20,'','agent:test','new section')
call check p~impactCount==3,'template placement reaches three outputs'
call check t~placements~items==2,'planning leaves template unchanged'
call check g~apply(p),'placement plan accepted'
call check t~placements~items==3,'placement applied once to template'
call check a~effectivePlacements(g)~items==3,'first consumer inherits placement'
call check b~effectivePlacements(g)~items==3,'second consumer inherits placement'
call check pos('Second heading',g~publish('doc.b','markdown')['content'])>0,'published content follows placement event'

p=g~planOverrideChange('template.project','template','shared.heading','title','Shared new heading','tool:test','editorial change')
call check p~impactCount==3,'template override reaches all outputs'
call check pos('Original heading',g~publish('doc.a','markdown')['content'])>0,'override plan is nonmutating'
call check g~apply(p),'template override plan accepted'
call check pos('Shared new heading',g~publish('doc.a','markdown')['content'])>0,'template override reaches first consumer'
call check pos('Shared new heading',g~publish('doc.b','markdown')['content'])>0,'template override reaches second consumer'

p=g~planOverrideChange('doc.b','document','shared.heading','title','Local B heading','tool:test','local variation')
call check p~impactCount==1,'document override affects only its own output'
call check g~apply(p),'document override applied'
call check pos('Local B heading',g~publish('doc.b','markdown')['content'])>0,'local override wins'
call check pos('Shared new heading',g~publish('doc.a','markdown')['content'])>0,'other document remains inherited'

p=g~planOverrideChange('template.project','template','shared.heading','title','Template revised again','tool:test','revision')
call check p~impactCount==3,'lower layer still reports every dependent output'
call check p~report~count('WARN')==1,'masked output emits warning'
call check pos('doc.b',p~report~summary)>0,'warning identifies masked document'
call check g~apply(p),'new template revision accepted'
call check pos('Local B heading',g~publish('doc.b','markdown')['content'])>0,'local override preserved after shared change'

old=g~planPlacementAdd('doc.a','third','shared.second',80,'','tool:test','proposal before concurrent event')
fresh=g~planOverrideChange('doc.a','document','shared.heading','title','A customised heading','tool:test','fresh event')
call check g~apply(fresh),'fresh event commits'
call check \g~apply(old),'stale placement plan blocked'
call check old~report~count('STOP')==1,'stale plan records STOP'
call check a~placements~items==0,'failed stale placement does not mutate'

p=g~planPlacementAdd('doc.a','first','shared.second',80,'','tool:test','conflicting inherited key')
call check p~report~count('STOP')==1,'duplicate inherited placement key blocked'
call check \g~apply(p),'invalid placement rejected'
p=g~planOverrideChange('doc.a','other','shared.heading','title','Bad','tool:test','illegal layer')
call check p~report~count('STOP')==1,'unregistered override layer blocked'
call check \g~apply(p),'illegal override rejected'
p=g~planPlacementAdd('doc.a','missing','unknown.node',99,'','tool:test','bad node')
call check p~report~count('STOP')==1,'unknown placement node blocked'
call check \g~apply(p),'unknown placement node refused'
call check g~events~items==5,'five accepted events retained in sequence'
call check g~events[5]~predecessor==g~events[4]~eventId,'new events link to predecessor'

say 'DOCY shared mutation plans:' passed 'PASS;' failed 'FAIL'
if failed > 0 then exit 1
exit 0
check: procedure expose passed failed
 use arg assertion,description
 if assertion then do
   passed=passed+1
   say 'PASS' description
 end
 else do
   failed=failed+1
   say 'FAIL' description
 end
 return
::requires 'docy_v02.cls'
