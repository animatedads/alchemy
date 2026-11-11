/* DOCY v0.2 candidate: native ooRexx document graph.
   Nodes are reusable; placements belong to documents; facts are authoritative.
   A plan precedes every graph mutation. No private methods.
   This candidate does not claim Storage Fabric or StringTemplate integration.
*/

::class DocyDiagnostic public
::method init
  expose severity code detail
  use strict arg severity, code, detail
::attribute severity get
::attribute code get
::attribute detail get
::method description
  return self~severity || ' ' || self~code || ': ' || self~detail

::class DocyReport public
::method init
  expose entries
  entries = .array~new
::attribute entries get
::method add
  expose entries
  use strict arg level, code, detail
  entries~append(.DocyDiagnostic~new(level,code,detail))
::method count
  expose entries
  use strict arg level
  n=0
  do e over entries
    if e~severity == level then n=n+1
  end
  return n
::method hasStops
  return self~count('STOP') > 0
::method summary
  expose entries
  out=''
  do e over entries
    out=out||e~description||'0a'x
  end
  return out

/* One generic typed datum, with a typed reference as a subclass.
   Its record representation is self-describing and does not evaluate source. */
::class DocyDatum public
::method init
  expose value typeName
  use strict arg value, typeName='string'
::attribute value get
::attribute typeName get
::method evaluate
  use strict arg graph, document, report
  return self~value
::method dependencies
  return .array~new
::method toRecord
  item=.directory~new
  item['kind']=.JsonString~new('literal')
  item['type']=.JsonString~new(self~typeName)
  if self~typeName == 'integer' then item['value']=self~value
  else item['value']=.JsonString~new(self~value~string)
  return item

::method fromRecord class
  use strict arg data,report
  if \data~isA(.directory) then do
    report~add('STOP','VALUE.INVALID','Expected typed datum record')
    return .DocyDatum~new('')
  end
  kind=data['kind']
  if kind == 'reference' then do
    if data['target'] == .nil then do
      report~add('STOP','REFERENCE.INVALID','Reference has no target')
      return .DocyDatum~new('')
    end
    return .DocyRef~new(data['target']~string)
  end
  if kind == 'literal' then do
    if data['type'] == .nil | data['value'] == .nil then do
      report~add('STOP','VALUE.INVALID','Literal lacks type/value')
      return .DocyDatum~new('')
    end
    return .DocyDatum~new(data['value']~string,data['type']~string)
  end
  report~add('STOP','VALUE.UNKNOWN','Unsupported datum kind')
  return .DocyDatum~new('')
::class DocyRef public subclass DocyDatum
::method init
  expose targetKey
  use strict arg targetKey
  self~init:super('', 'reference')
::attribute targetKey get
::method evaluate
  use strict arg graph, document, report
  return graph~factValue(self~targetKey,report)
::method dependencies
  a=.array~new
  a~append(self~targetKey)
  return a
::method toRecord
  item=.directory~new
  item['kind']=.JsonString~new('reference')
  item['target']=.JsonString~new(self~targetKey)
  return item

::class DocyNode public
::method init
  expose key nodeType layers authoredBy
  use strict arg key, nodeType='node'
  layers=.directory~new
  authoredBy=''
::attribute key get
::attribute nodeType get
::attribute authoredBy
::attribute layers get
::method put
  expose layers
  use strict arg layer, attr, datum
  if \datum~isA(.DocyDatum) then datum=.DocyDatum~new(datum)
  values=layers[layer]
  if values == .nil then do
    values=.directory~new
    layers[layer]=values
  end
  values[attr]=datum
  return self
::method at
  expose layers
  use strict arg layer, attr
  values=layers[layer]
  if values == .nil then return .nil
  return values[attr]
::method effective
  use strict arg graph, document, attr, report
  return graph~resolve(document, self, attr, report)
::method dependencies
  expose layers
  a=.array~new
  do layer over layers~allIndexes
    d=layers[layer]
    do prop over d~allIndexes
      datum=d[prop]
      do target over datum~dependencies
        a~append(target)
      end
    end
  end
  return a
::method renderMarkdown
  use strict arg graph, doc, placement, report
  report~add('WARN','NODE.RENDERER', 'No Markdown renderer: '||self~nodeType)
  return ''
::method renderHtml
  use strict arg graph, doc, placement, report
  report~add('WARN','NODE.RENDERER', 'No HTML renderer: '||self~nodeType)
  return ''
::method renderPdf
  use strict arg target, graph, doc, placement, report
  report~add('WARN','PDF.NODE.UNSUPPORTED', self~key||' ('||self~nodeType||')')
::method renderOdt
  use strict arg target, graph, doc, placement, report
  report~add('WARN','ODT.NODE.UNSUPPORTED', self~key||' ('||self~nodeType||')')
::method validate
  use strict arg graph, doc, placement, report
  return

::method toExtraRecord
  return .directory~new
::method loadExtraRecord
  use strict arg data,report
  return
::class DocySection public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'section')
::method renderMarkdown
  use strict arg graph, doc, placement, report
  return '## '||self~effective(graph,doc,'title',report)||'0a0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  return '<h2 id="'||graph~escape(self~key)||'">'||graph~escape(self~effective(graph,doc,'title',report))||'</h2>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addSection(self~effective(graph,doc,'title',report),2)
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addHeading(self~effective(graph,doc,'title',report),2)

::class DocyText public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'text')
::method renderMarkdown
  use strict arg graph, doc, placement, report
  return self~effective(graph,doc,'text',report)||'0a0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  return '<p>'||graph~escape(self~effective(graph,doc,'text',report))||'</p>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addParagraph(self~effective(graph,doc,'text',report))
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addParagraph(self~effective(graph,doc,'text',report))

::class DocyCommand public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'command')
::method validate
  use strict arg graph, doc, placement, report
  command=self~effective(graph,doc,'command',report)
  if right(strip(command),1) == '.' then report~add('STOP','COMMAND.TRAILING_PERIOD',self~key||' ends with a period')
::method renderMarkdown
  use strict arg graph, doc, placement, report
  return '```sh'||'0a'x||self~effective(graph,doc,'command',report)||'0a'x||'```'||'0a0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  return '<pre><code>'||graph~escape(self~effective(graph,doc,'command',report))||'</code></pre>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addParagraph('$ '||self~effective(graph,doc,'command',report))
  report~add('WARN','PDF.COMMAND.STYLE','Monospace command style not implemented for '||self~key)
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addParagraph(self~effective(graph,doc,'command',report))
  report~add('WARN','ODT.COMMAND.STYLE','Monospace command style not implemented for '||self~key)

::class DocyFactField public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'factfield')
::method renderMarkdown
  use strict arg graph, doc, placement, report
  return '**'||self~effective(graph,doc,'label',report)||':** '||self~effective(graph,doc,'value',report)||'0a0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  return '<p><strong>'||graph~escape(self~effective(graph,doc,'label',report))||':</strong> '||graph~escape(self~effective(graph,doc,'value',report))||'</p>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addParagraph(self~effective(graph,doc,'label',report)||': '||self~effective(graph,doc,'value',report))
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addParagraph(self~effective(graph,doc,'label',report)||': '||self~effective(graph,doc,'value',report))

::class DocyCredits public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'credits')
::method validate
  use strict arg graph, doc, placement, report
  do item over 'architecture coding writer'~makeArray(' ')
    if strip(self~effective(graph,doc,item,report)) == '' then report~add('STOP','CREDITS.MISSING',self~key||' lacks '||item)
  end
::method renderMarkdown
  use strict arg graph, doc, placement, report
  return '## Credits'||'0a0a'x||'Architecture: '||self~effective(graph,doc,'architecture',report)||'0a0a'x||'Coding: '||self~effective(graph,doc,'coding',report)||'0a0a'x||'Writer: '||self~effective(graph,doc,'writer',report)||'0a0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  return '<h2>Credits</h2><p>Architecture: '||graph~escape(self~effective(graph,doc,'architecture',report))||'; Coding: '||graph~escape(self~effective(graph,doc,'coding',report))||'; Writer: '||graph~escape(self~effective(graph,doc,'writer',report))||'</p>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addSection('Credits',2)
  target~addParagraph('Architecture: '||self~effective(graph,doc,'architecture',report))
  target~addParagraph('Coding: '||self~effective(graph,doc,'coding',report))
  target~addParagraph('Writer: '||self~effective(graph,doc,'writer',report))
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addHeading('Credits',2)
  target~addParagraph('Architecture: '||self~effective(graph,doc,'architecture',report))
  target~addParagraph('Coding: '||self~effective(graph,doc,'coding',report))
  target~addParagraph('Writer: '||self~effective(graph,doc,'writer',report))

::class DocyTOC public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'toc')
::method renderMarkdown
  use strict arg graph, doc, placement, report
  a=doc~effectivePlacements(graph)
  out='## Contents'||'0a0a'x
  do p over a
    n=graph~node(p~nodeKey)
    if n == .nil then iterate
    if n~nodeType == 'section' then out=out||'- '||n~effective(graph,doc,'title',report)||'0a'x
  end
  return out||'0a'x
::method renderHtml
  use strict arg graph, doc, placement, report
  a=doc~effectivePlacements(graph)
  out='<nav aria-label="Contents"><strong>Contents</strong><ul>'
  do p over a
    n=graph~node(p~nodeKey)
    if n == .nil then iterate
    if n~nodeType == 'section' then out=out||'<li><a href="#'||graph~escape(n~key)||'">'||graph~escape(n~effective(graph,doc,'title',report))||'</a></li>'
  end
  return out||'</ul></nav>'||'0a'x
::method renderPdf
  use strict arg target, graph, doc, placement, report
  target~addSection('Contents',2)
  do p over doc~effectivePlacements(graph)
    n=graph~node(p~nodeKey)
    if n == .nil then iterate
    if n~nodeType == 'section' then target~addParagraph(n~effective(graph,doc,'title',report))
  end
::method renderOdt
  use strict arg target, graph, doc, placement, report
  target~addHeading('Contents',2)
  do p over doc~effectivePlacements(graph)
    n=graph~node(p~nodeKey)
    if n == .nil then iterate
    if n~nodeType == 'section' then target~addParagraph(n~effective(graph,doc,'title',report))
  end

::class DocyTable public subclass DocyNode
::method init
  expose headers rows
  use strict arg key
  self~init:super(key,'table')
  headers=.array~new
  rows=.array~new
::attribute headers get
::attribute rows get
::method header
  expose headers
  use strict arg text
  headers~append(text)
::method addRow
  expose rows
  use strict arg cells
  rows~append(cells)
::method dependencies
  expose rows
  a=self~dependencies:super
  do row over rows
    do cell over row
      do target over cell~dependencies
        a~append(target)
      end
    end
  end
  return a
::method validate
  expose headers rows
  use strict arg graph,doc,placement,report
  do row over rows
    if row~items \== headers~items then report~add('STOP','TABLE.WIDTH',self~key||' has a mismatched row')
  end
::method renderMarkdown
  expose headers rows
  use strict arg graph,doc,placement,report
  out='|'
  do value over headers
    out=out||' '||changestr('|',value,'\\|')||' |'
  end
  out=out||'0a'x||'|'
  do value over headers
    out=out||' --- |'
  end
  out=out||'0a'x
  do row over rows
    out=out||'|'
    do cell over row
      rendered=cell~evaluate(graph,doc,report)~string
      out=out||' '||changestr('|',rendered,'\\|')||' |'
    end
    out=out||'0a'x
  end
  return out||'0a'x
::method renderHtml
  expose headers rows
  use strict arg graph,doc,placement,report
  out='<table><thead><tr>'
  do value over headers
    out=out||'<th>'||graph~escape(value)||'</th>'
  end
  out=out||'</tr></thead><tbody>'
  do row over rows
    out=out||'<tr>'
    do cell over row
      out=out||'<td>'||graph~escape(cell~evaluate(graph,doc,report))||'</td>'
    end
    out=out||'</tr>'
  end
  return out||'</tbody></table>'||'0a'x
::method renderPdf
  expose headers rows
  use strict arg target,graph,doc,placement,report
  renderedRows=.array~new
  do row over rows
    cells=.array~new
    do datum over row
      cells~append(datum~evaluate(graph,doc,report)~string)
    end
    renderedRows~append(cells)
  end
  target~addDataTable(headers,renderedRows,self~key)
::method renderOdt
  expose headers rows
  use strict arg target,graph,doc,placement,report
  renderedRows=.array~new
  do row over rows
    cells=.array~new
    do datum over row
      cells~append(datum~evaluate(graph,doc,report)~string)
    end
    renderedRows~append(cells)
  end
  target~addDataTable(headers,renderedRows,self~key)
::method toExtraRecord
  expose headers rows
  data=.directory~new
  h=.array~new
  do value over headers
    h~append(.JsonString~new(value))
  end
  data['headers']=h
  r=.array~new
  do row over rows
    cells=.array~new
    do value over row
      cells~append(value~toRecord)
    end
    r~append(cells)
  end
  data['rows']=r
  return data
::method loadExtraRecord
  expose headers rows
  use strict arg data,report
  if data == .nil then do
    report~add('STOP','TABLE.INVALID',self~key||' is missing table data')
    return
  end
  do value over data['headers']
    self~header(value~string)
  end
  do row over data['rows']
    cells=.array~new
    do value over row
      cells~append(.DocyDatum~fromRecord(value,report))
    end
    self~addRow(cells)
  end

::class DocySvg public subclass DocyNode
::method init
  use strict arg key
  self~init:super(key,'svg')
::method validate
  use strict arg graph,doc,placement,report
  s=self~effective(graph,doc,'source',report)~lower
  if pos('<svg',s)==0 then report~add('STOP','SVG.INVALID',self~key||' lacks an SVG root')
  if pos('<script',s)>0 | pos('foreignobject',s)>0 | pos('javascript:',s)>0 then report~add('STOP','SVG.ACTIVE_CONTENT',self~key||' contains active content')
::method renderMarkdown
  use strict arg graph,doc,placement,report
  return '**'||self~effective(graph,doc,'title',report)||'**'||'0a0a'x||'```xml'||'0a'x||self~effective(graph,doc,'source',report)||'0a'x||'```'||'0a0a'x
::method renderHtml
  use strict arg graph,doc,placement,report
  uri='data:image/svg+xml;charset=utf-8,'||graph~uriEncode(self~effective(graph,doc,'source',report))
  return '<figure><img alt="'||graph~escape(self~effective(graph,doc,'title',report))||'" src="'||uri||'"></figure>'||'0a'x
::method renderPdf
  use strict arg target,graph,doc,placement,report
  target~addParagraph('[Figure not embedded: '||self~effective(graph,doc,'title',report)||']')
  report~add('WARN','PDF.SVG.UNSUPPORTED',self~key||' needs an SVG asset provider')
::method renderOdt
  use strict arg target,graph,doc,placement,report
  target~addParagraph('[Figure not embedded: '||self~effective(graph,doc,'title',report)||']')
  report~add('WARN','ODT.SVG.UNSUPPORTED',self~key||' needs an SVG asset provider')

::class DocyPlacement public
::method init
  expose key nodeKey ordering parentKey
  use strict arg key, nodeKey, ordering=100, parentKey=''
::attribute key get
::attribute nodeKey get
::attribute ordering get
::attribute parentKey get
::method toRecord
  d=.directory~new
  d['key']=.JsonString~new(self~key)
  d['node']=.JsonString~new(self~nodeKey)
  d['order']=self~ordering
  d['parent']=.JsonString~new(self~parentKey)
  return d

::class DocyDocument public
::method init
  expose key title templateKey placements overrides outputs
  use strict arg key,title='',templateKey=''
  placements=.array~new
  overrides=.directory~new
  outputs=.array~new
::attribute key get
::attribute title
::attribute templateKey
::attribute placements get
::attribute overrides get
::attribute outputs get
::method place
  expose placements
  use strict arg key,nodeKey,ordering=100,parentKey=''
  p=.DocyPlacement~new(key,nodeKey,ordering,parentKey)
  placements~append(p)
  return p
::method override
  expose overrides
  use strict arg layer,nodeKey,attr,datum
  if \datum~isA(.DocyDatum) then datum=.DocyDatum~new(datum)
  overrides[layer||'|'||nodeKey||'|'||attr]=datum
::method getOverride
  expose overrides
  use strict arg layer,nodeKey,attr
  return overrides[layer||'|'||nodeKey||'|'||attr]
::method hasOverride
  use strict arg nodeKey,attr
  return self~getOverride('document',nodeKey,attr) \== .nil | self~getOverride('variant',nodeKey,attr) \== .nil
::method effectivePlacements
  use strict arg graph
  chain=.array~new
  seen=.directory~new
  cursor=self
  do while cursor \== .nil
    if seen[cursor~key] \== .nil then leave
    seen[cursor~key]=.true
    chain~append(cursor)
    if cursor~templateKey == "" then leave
    cursor=graph~document(cursor~templateKey)
  end
  all=.array~new
  do i=chain~items to 1 by -1
    do p over chain[i]~placements
      all~append(p)
    end
  end
  /* Deterministic insertion ordering, without mutable node parenting. */
  sorted=.array~new
  do p over all
    sorted~append(p)
    do j=sorted~items to 2 by -1
      if sorted[j]~ordering >= sorted[j-1]~ordering then leave
      tmp=sorted[j-1]
      sorted[j-1]=sorted[j]
      sorted[j]=tmp
    end
  end
  return sorted

::class DocyFact public
::method init
  expose key typeName value source sourceRevision author
  use strict arg key, value, typeName='string',source='',sourceRevision='',author=''
::attribute key get
::attribute value
::attribute typeName get
::attribute source get
::attribute sourceRevision get
::attribute author get

::class DocyImpact public
::method init
  expose documentKey output mask
  use strict arg documentKey,output,mask=.false
::attribute documentKey get
::attribute output get
::attribute mask get

::class DocyPlan public
::method init
  expose kind targetKey attribute layer newValue author reason impacts report baseRevision
  use strict arg kind,targetKey,attribute,layer,newValue,author,reason
  impacts=.array~new
  report=.DocyReport~new
::attribute baseRevision
::attribute kind get
::attribute targetKey get
::attribute attribute get
::attribute layer get
::attribute newValue get
::attribute author get
::attribute reason get
::attribute impacts get
::attribute report get
::method impactCount
  expose impacts
  return impacts~items

::class DocyEvent public
::method init
  expose sequence eventId predecessor target kind attribute layer author reason
  use strict arg sequence, predecessor, plan
  eventId='ev-'||right(sequence,8,'0')
  target=plan~targetKey
  kind=plan~kind
  attribute=plan~attribute
  layer=plan~layer
  author=plan~author
  reason=plan~reason
::attribute sequence get
::attribute eventId get
::attribute predecessor get
::attribute target get
::attribute kind get
::attribute attribute get
::attribute layer get
::attribute author get
::attribute reason get

::class DocyGraph public
::method init
  expose nodes documents facts types events revision
  nodes=.directory~new
  documents=.directory~new
  facts=.directory~new
  types=.directory~new
  events=.array~new
  revision=0
::attribute nodes get
::attribute documents get
::attribute facts get
::attribute types get
::attribute events get
::attribute revision
::method registerType
  expose types
  use strict arg typeName, classObject
  types[typeName]=classObject
::method newNode
  expose types
  use strict arg typeName,key
  c=types[typeName]
  if c == .nil then return .nil
  return c~new(key)
::method addNode
  expose nodes
  use strict arg node
  if nodes[node~key] \== .nil then return .false
  nodes[node~key]=node
  return .true
::method addDocument
  expose documents
  use strict arg doc
  if documents[doc~key] \== .nil then return .false
  documents[doc~key]=doc
  return .true
::method addFact
  expose facts
  use strict arg fact
  if facts[fact~key] \== .nil then return .false
  facts[fact~key]=fact
  return .true
::method node
  expose nodes
  use strict arg key
  return nodes[key]
::method document
  expose documents
  use strict arg key
  return documents[key]
::method fact
  expose facts
  use strict arg key
  return facts[key]
::method factValue
  expose facts
  use strict arg key,report
  fact=facts[key]
  if fact == .nil then do
    report~add("WARN","BINDING.UNKNOWN","Unknown fact "||key)
    return "[unresolved: "||key||"]"
  end
  return fact~value
::method resolve
  use strict arg doc,node,attr,report
  v=doc~getOverride("variant",node~key,attr)
  if v == .nil then v=doc~getOverride("document",node~key,attr)
  if v == .nil then v=doc~getOverride("project",node~key,attr)
  if v == .nil then v=node~at("project",attr)
  if v == .nil then do
    seen=.directory~new
    key=doc~templateKey
    do while key \== ""
      if seen[key] \== .nil then leave
      seen[key]=.true
      ancestor=self~document(key)
      if ancestor == .nil then leave
      v=ancestor~getOverride("template",node~key,attr)
      if v \== .nil then leave
      key=ancestor~templateKey
    end
  end
  if v == .nil then v=node~at("template",attr)
  if v == .nil then v=node~at("house",attr)
  if v == .nil then do
    report~add("WARN","PROPERTY.MISSING",node~key||"."||attr)
    return ""
  end
  return v~evaluate(self,doc,report)
::method uriEncode
  use strict arg s
  safe='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~'
  out=''
  do i=1 to length(s)
    c=substr(s,i,1)
    if pos(c,safe)>0 then out=out||c
    else out=out||'%'||c2x(c)
  end
  return out
::method escape
  use strict arg text
  s=text~string
  s=changestr('&',s,'&amp;')
  s=changestr('<',s,'&lt;')
  s=changestr('>',s,'&gt;')
  s=changestr('"',s,'&quot;')
  return s
::method validate
  use strict arg docKey
  report=.DocyReport~new
  doc=self~document(docKey)
  if doc == .nil then do
    report~add('STOP','DOCUMENT.UNKNOWN',docKey)
    return report
  end
  seen=.directory~new
  cursor=doc
  do while cursor \== .nil
    if seen[cursor~key] \== .nil then do
      report~add("STOP","TEMPLATE.CYCLE",docKey||" inherits cyclically")
      leave
    end
    seen[cursor~key]=.true
    if cursor~templateKey == "" then leave
    parent=self~document(cursor~templateKey)
    if parent == .nil then do
      report~add("STOP","TEMPLATE.MISSING",cursor~templateKey)
      leave
    end
    cursor=parent
  end
  credits=0
  do p over doc~effectivePlacements(self)
    node=self~node(p~nodeKey)
    if node == .nil then do
      report~add('STOP','NODE.UNKNOWN',p~nodeKey||' in '||docKey)
      iterate
    end
    if node~nodeType == 'credits' then credits=credits+1
    node~validate(self,doc,p,report)
    if node~authoredBy == "" then report~add("WARN","AUTHOR.MISSING",node~key||" has no tool provenance")
  end
  if credits == 0 then report~add('STOP','CREDITS.REQUIRED',docKey||' requires Credits')
  return report
::method publish
  use strict arg docKey,format
  report=self~validate(docKey)
  bundle=.directory~new
  bundle['report']=report
  bundle['content']=''
  if report~hasStops then return bundle
  doc=self~document(docKey)
  out=''
  if format == 'markdown' then out='# '||doc~title||'0a0a'x
  else if format == 'html' then out='<!doctype html><html><head><meta charset="utf-8"></head><body><h1>'||self~escape(doc~title)||'</h1>'||'0a'x
  else do
    report~add('STOP','FORMAT.UNSUPPORTED',format)
    return bundle
  end
  do p over doc~effectivePlacements(self)
    node=self~node(p~nodeKey)
    if node == .nil then iterate
    if format == 'markdown' then out=out||node~renderMarkdown(self,doc,p,report)
    else out=out||node~renderHtml(self,doc,p,report)
  end
  if format == 'html' then out=out||'</body></html>'||'0a'x
  if \report~hasStops then bundle['content']=out
  return bundle
::method planNodeChange
  use strict arg key,attr,layer,datum,author,reason
  p=.DocyPlan~new('node',key,attr,layer,datum,author,reason)
  p~baseRevision=self~revision
  if self~node(key) == .nil then p~report~add('STOP','NODE.UNKNOWN',key)
  if layer \== 'house' & layer \== 'template' & layer \== 'project' then p~report~add('STOP','LAYER.INVALID',layer)
  self~buildImpacts(p)
  return p
::method planFactChange
  use strict arg key,datum,author,reason
  p=.DocyPlan~new('fact',key,'value','source',datum,author,reason)
  p~baseRevision=self~revision
  if self~fact(key) == .nil then p~report~add('STOP','FACT.UNKNOWN',key)
  self~buildImpacts(p)
  return p
::method planPlacementAdd
  use strict arg documentKey,placementKey,nodeKey,ordering,parentKey,author,reason
  placement=.DocyPlacement~new(placementKey,nodeKey,ordering,parentKey)
  p=.DocyPlan~new('placement',documentKey,placementKey,'document',placement,author,reason)
  p~baseRevision=self~revision
  doc=self~document(documentKey)
  if doc == .nil then p~report~add('STOP','DOCUMENT.UNKNOWN',documentKey)
  if self~node(nodeKey) == .nil then p~report~add('STOP','NODE.UNKNOWN',nodeKey)
  if strip(placementKey) == '' then p~report~add('STOP','PLACEMENT.KEY.EMPTY',documentKey)
  if doc \== .nil then do
    do existing over doc~effectivePlacements(self)
      if existing~key == placementKey then p~report~add('STOP','PLACEMENT.KEY.DUPLICATE',placementKey)
    end
  end
  self~buildImpacts(p)
  return p
::method planOverrideChange
  use strict arg documentKey,layer,nodeKey,attr,datum,author,reason
  if \datum~isA(.DocyDatum) then datum=.DocyDatum~new(datum)
  value=.array~of(nodeKey,datum)
  p=.DocyPlan~new('override',documentKey,attr,layer,value,author,reason)
  p~baseRevision=self~revision
  if self~document(documentKey) == .nil then p~report~add('STOP','DOCUMENT.UNKNOWN',documentKey)
  if self~node(nodeKey) == .nil then p~report~add('STOP','NODE.UNKNOWN',nodeKey)
  if layer \== 'template' & layer \== 'project' & layer \== 'document' & layer \== 'variant' then -
    p~report~add('STOP','LAYER.INVALID',layer)
  if strip(attr) == '' then p~report~add('STOP','ATTRIBUTE.EMPTY',nodeKey)
  self~buildImpacts(p)
  return p
::method buildImpacts
  expose documents
  use strict arg plan
  target=plan~targetKey
  do docKey over documents~allIndexes
    doc=documents[docKey]
    if doc~templateKey == '' & doc~outputs~items == 0 then iterate
    affected=.false
    masked=.false
    if plan~kind == 'placement' | plan~kind == 'override' then do
      /* A change to a template's placements or template-layer properties
         affects every inheriting document, even if the node was absent. */
      cursor=doc
      seen=.directory~new
      do while cursor \== .nil
        if seen[cursor~key] \== .nil then leave
        seen[cursor~key]=.true
        if cursor~key == target then do
          if plan~kind == 'placement' | plan~layer == 'template' | docKey == target then affected=.true
          leave
        end
        if cursor~templateKey == '' then leave
        cursor=self~document(cursor~templateKey)
      end
      if affected & plan~kind == 'override' & docKey \== target then do
        if doc~hasOverride(plan~newValue[1],plan~attribute) then masked=.true
      end
    end
    else do
      do place over doc~effectivePlacements(self)
        node=self~node(place~nodeKey)
        if node == .nil then iterate
        if plan~kind == 'node' then do
          if node~key \== target then iterate
          affected=.true
          if doc~hasOverride(target,plan~attribute) then masked=.true
        end
        else if plan~kind == 'fact' then do
          do ref over node~dependencies
            if ref \== target then iterate
            affected=.true
            /* A literal document override can mask the referenced field. */
            if doc~hasOverride(node~key,'value') then masked=.true
          end
        end
      end
    end
    if affected then do
      do output over doc~outputs
        plan~impacts~append(.DocyImpact~new(docKey,output,masked))
      end
      if masked then plan~report~add('WARN','OVERRIDE.SHADOWS',docKey||' locally shadows '||target)
    end
  end
::method apply
  expose revision events
  use strict arg plan
  if plan~report~hasStops then return .false
  if plan~baseRevision \== revision then do
    plan~report~add("STOP","PLAN.STALE","Graph changed since proposal was made")
    return .false
  end
  select
    when plan~kind == 'node' then do
      self~node(plan~targetKey)~put(plan~layer,plan~attribute,plan~newValue)
      self~node(plan~targetKey)~authoredBy=plan~author
    end
    when plan~kind == 'fact' then self~fact(plan~targetKey)~value=plan~newValue
    when plan~kind == 'placement' then do
      doc=self~document(plan~targetKey)
      placement=plan~newValue
      doc~place(placement~key,placement~nodeKey,placement~ordering,placement~parentKey)
    end
    when plan~kind == 'override' then do
      doc=self~document(plan~targetKey)
      value=plan~newValue
      doc~override(plan~layer,value[1],plan~attribute,value[2])
    end
    otherwise do
      plan~report~add('STOP','PLAN.KIND.UNKNOWN',plan~kind)
      return .false
    end
  end
  prior='GENESIS'
  if events~items > 0 then prior=events[events~items]~eventId
  revision=revision+1
  events~append(.DocyEvent~new(revision,prior,plan))
  return .true

::class DocyTypes public
::method install class
  use strict arg graph
  graph~registerType('section',.DocySection)
  graph~registerType('text',.DocyText)
  graph~registerType('command',.DocyCommand)
  graph~registerType('factfield',.DocyFactField)
  graph~registerType('credits',.DocyCredits)
  graph~registerType('toc',.DocyTOC)
  graph~registerType('table',.DocyTable)
  graph~registerType('svg',.DocySvg)

::requires 'json.cls'
