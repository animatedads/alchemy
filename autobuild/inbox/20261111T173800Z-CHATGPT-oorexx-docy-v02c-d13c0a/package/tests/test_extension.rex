/* Extension type registration is independent of the generic store. */
g=.DocyGraph~new
.DocyTypes~install(g)
g~registerType('note', .DocyExtensionNote)
n=g~newNode('note','extension.note')
n~put('house','text','This node type is user registered.')
g~addNode(n)
credits=g~newNode('credits','credits.custom')
credits~put('house','architecture','Example architect')
credits~put('house','coding','Example coder')
credits~put('house','writer','Example writer')
g~addNode(credits)
d=.DocyDocument~new('doc.ext','Extension Document')
d~place('note','extension.note',10)
d~place('credits','credits.custom',20)
d~outputs~append('extension.md')
g~addDocument(d)
.DocyStore~save(g,'extension.docy')
base=.DocyStore~open('extension.docy')
if base['report']~count('STOP')<1 then do
  say 'FAIL: Unregistered node was not rejected'
  exit 1
end
newGraph=.DocyGraph~new
newGraph~registerType('note', .DocyExtensionNote)
loaded=.DocyStore~open('extension.docy',newGraph)
if loaded['report']~hasStops then do
  say 'FAIL: Registered extension load'
  say loaded['report']~summary
  exit 1
end
markdown=loaded['graph']~publish('doc.ext','markdown')['content']
if pos('user registered',markdown)==0 then do
  say 'FAIL: Extension renderer'
  exit 1
end
say 'PASS: default loader rejects unknown extension'
say 'PASS: registered type round-trips and renders without editing store'
exit 0

::class DocyExtensionNote public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'note')
::method renderMarkdown
  use strict arg graph, doc, place, report
  return '> '||self~effective(graph,doc,'text',report)||'0a0a'x
::method renderHtml
  use strict arg graph, doc, place, report
  return '<blockquote>'||graph~escape(self~effective(graph,doc,'text',report))||'</blockquote>'
::requires 'docy_v02.cls'
::requires 'docy_store.cls'
