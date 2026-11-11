/* DOCY/2 canonical snapshot adapter: structured data, not executable Rexx.
   Snapshot adapter for qualification only; not a Storage Fabric implementation.
   Loader collects structural STOP diagnostics rather than failing on first defect.
*/
::class DocyStore public
::method save class
  use strict arg graph,path
  envelope=.directory~new
  envelope['format']=.JsonString~new('DOCY')
  envelope['schema']=2
  envelope['revision']=graph~revision
  nrecords=.array~new
  do key over graph~nodes~allIndexes
    node=graph~node(key)
    item=.directory~new
    item['key']=.JsonString~new(node~key)
    item['type']=.JsonString~new(node~nodeType)
    item['authoredBy']=.JsonString~new(node~authoredBy)
    layers=.directory~new
    do layer over node~layers~allIndexes
      attrs=.directory~new
      values=node~layers[layer]
      do attr over values~allIndexes
        attrs[attr]=values[attr]~toRecord
      end
      layers[layer]=attrs
    end
    item['layers']=layers
    item['extra']=node~toExtraRecord
    nrecords~append(item)
  end
  envelope['nodes']=nrecords
  frecords=.array~new
  do key over graph~facts~allIndexes
    fact=graph~fact(key)
    item=.directory~new
    item['key']=.JsonString~new(fact~key)
    item['type']=.JsonString~new(fact~typeName)
    item['source']=.JsonString~new(fact~source)
    item['sourceRevision']=.JsonString~new(fact~sourceRevision)
    item['author']=.JsonString~new(fact~author)
    if fact~typeName == 'integer' then item['value']=fact~value
    else item['value']=.JsonString~new(fact~value)
    frecords~append(item)
  end
  envelope['facts']=frecords
  drecs=.array~new
  do key over graph~documents~allIndexes
    doc=graph~document(key)
    item=.directory~new
    item['key']=.JsonString~new(doc~key)
    item['title']=.JsonString~new(doc~title)
    item['template']=.JsonString~new(doc~templateKey)
    placements=.array~new
    do place over doc~placements
      placements~append(place~toRecord)
    end
    item['placements']=placements
    overrides=.directory~new
    do prop over doc~overrides~allIndexes
      overrides[prop]=doc~overrides[prop]~toRecord
    end
    item['overrides']=overrides
    outputs=.array~new
    do output over doc~outputs
      outputs~append(.JsonString~new(output))
    end
    item['outputs']=outputs
    drecs~append(item)
  end
  envelope['documents']=drecs
  erecs=.array~new
  do e over graph~events
    item=.directory~new
    item['sequence']=e~sequence
    item['id']=.JsonString~new(e~eventId)
    item['previousEvent']=.JsonString~new(e~predecessor)
    item['kind']=.JsonString~new(e~kind)
    item['target']=.JsonString~new(e~target)
    item['attribute']=.JsonString~new(e~attribute)
    item['layer']=.JsonString~new(e~layer)
    item['author']=.JsonString~new(e~author)
    item['reason']=.JsonString~new(e~reason)
    erecs~append(item)
  end
  envelope['events']=erecs
  .json~toJsonFile(path,envelope,.true)
  return path

::method datum class
  use strict arg data,report
  if \data~isA(.directory) then do
    report~add('STOP','VALUE.INVALID','Expected typed datum record')
    return .DocyDatum~new('')
  end
  kind=data['kind']
  if kind=='reference' then do
    if data['target'] == .nil then do
      report~add('STOP','REFERENCE.INVALID','Reference has no target')
      return .DocyDatum~new('')
    end
    return .DocyRef~new(data['target']~string)
  end
  if kind=='literal' then do
    if data['type'] == .nil | data['value'] == .nil then do
      report~add('STOP','VALUE.INVALID','Literal lacks type/value')
      return .DocyDatum~new('')
    end
    return .DocyDatum~new(data['value']~string,data['type']~string)
  end
  report~add('STOP','VALUE.UNKNOWN','Unsupported datum kind: '||kind)
  return .DocyDatum~new('')

::method open class
  use arg path, graph
  report=.DocyReport~new
  bundle=.directory~new
  bundle['report']=report
  if \arg(2,"E") then graph=.DocyGraph~new
  .DocyTypes~install(graph)
  bundle['graph']=graph
  source=.stream~new(path)
  status=source~open('read')
  if status \== 'READY:' then do
    report~add('STOP','FILE.UNREADABLE',path)
    return bundle
  end
  raw=source~charin(,source~query('size'))
  source~close
  signal on syntax name malformed
  envelope=.json~fromJSON(raw)
  signal off syntax
  if \envelope~isA(.directory) then do
    report~add('STOP','ENVELOPE.INVALID','Root must be a record')
    return bundle
  end
  if envelope['format'] \== 'DOCY' then report~add('STOP','FORMAT.INVALID','Expected DOCY')
  if envelope['schema'] \== 2 then report~add('STOP','SCHEMA.UNSUPPORTED','Expected DOCY/2')
  do name over 'nodes documents facts'~makeArray(' ')
    if \envelope[name]~isA(.array) then report~add('STOP','COLLECTION.MISSING',name)
  end
  if report~hasStops then return bundle
  do item over envelope['facts']
    if \item~isA(.directory) then do
      report~add('STOP','FACT.INVALID','Fact entry is not a record')
      iterate
    end
    if item['key']==.nil | item['value']==.nil then do
      report~add('STOP','FACT.INVALID','Fact missing key/value')
      iterate
    end
    typ='string'
    if item['type'] \== .nil then typ=item['type']~string
    sourceUri=''
    if item['source'] \== .nil then sourceUri=item['source']~string
    revision=''
    if item['sourceRevision'] \== .nil then revision=item['sourceRevision']~string
    author=''
    if item['author'] \== .nil then author=item['author']~string
    if \graph~addFact(.DocyFact~new(item['key']~string,item['value']~string,typ,sourceUri,revision,author)) then report~add('STOP','FACT.DUPLICATE',item['key'])
  end
  do item over envelope['nodes']
    if \item~isA(.directory) then do
      report~add('STOP','NODE.INVALID','Node entry not a record')
      iterate
    end
    if item['type']==.nil | item['key']==.nil then do
      report~add('STOP','NODE.INVALID','Node lacks type/key')
      iterate
    end
    node=graph~newNode(item['type']~string,item['key']~string)
    if node == .nil then do
      report~add('STOP','NODE.TYPE.UNREGISTERED',item['type']~string)
      iterate
    end
    if item['layers'] \== .nil then do layer over item['layers']~allIndexes
      attrs=item['layers'][layer]
      do attr over attrs~allIndexes
        node~put(layer,attr,self~datum(attrs[attr],report))
      end
    end
    node~loadExtraRecord(item["extra"],report)
    if item['authoredBy'] \== .nil then node~authoredBy=item['authoredBy']~string
    if \graph~addNode(node) then report~add('STOP','NODE.DUPLICATE',item['key']~string)
  end
  do item over envelope['documents']
    if \item~isA(.directory) then do
      report~add('STOP','DOCUMENT.INVALID','Document entry not a record')
      iterate
    end
    if item['key']==.nil | item['title']==.nil then do
      report~add('STOP','DOCUMENT.INVALID','Document lacks key/title')
      iterate
    end
    templateKey=''
    if item['template'] \== .nil then templateKey=item['template']~string
    doc=.DocyDocument~new(item['key']~string,item['title']~string,templateKey)
    if item['placements'] \== .nil then do p over item['placements']
      if p['key']==.nil | p['node']==.nil then do
        report~add('STOP','PLACEMENT.INVALID',doc~key)
        iterate
      end
      ordering=100
      if p['order'] \== .nil then ordering=p['order']
      parentKey=''
      if p['parent'] \== .nil then parentKey=p['parent']~string
      doc~place(p['key']~string,p['node']~string,ordering,parentKey)
    end
    if item['overrides'] \== .nil then do key over item['overrides']~allIndexes
      parse var key layer '|' nodeKey '|' attr
      doc~override(layer,nodeKey,attr,self~datum(item['overrides'][key],report))
    end
    if item['outputs'] \== .nil then do output over item['outputs']
      doc~outputs~append(output~string)
    end
    if \graph~addDocument(doc) then report~add('STOP','DOCUMENT.DUPLICATE',doc~key)
  end
  do key over graph~documents~allIndexes
    doc=graph~document(key)
    if doc~templateKey \== '' & graph~document(doc~templateKey)==.nil then report~add('STOP','TEMPLATE.MISSING',doc~key)
    do p over doc~placements
      if graph~node(p~nodeKey)==.nil then report~add('STOP','PLACEMENT.NODE.MISSING',p~nodeKey||' in '||doc~key)
    end
  end
  /* Logical event predecessor replay. Cryptographic verification is NOT here. */
  prior='GENESIS'
  if envelope['events']~isA(.array) then do e over envelope['events']
    if \e~isA(.directory) then do
      report~add('STOP','EVENT.INVALID','Event is not a record')
      iterate
    end
    if e['previousEvent'] \== prior then report~add('STOP','EVENT.CHAIN.BROKEN',e['id']~string)
    plan=.DocyPlan~new(e['kind']~string,e['target']~string,e['attribute']~string,e['layer']~string,'',e['author']~string,e['reason']~string)
    restoredEvent=.DocyEvent~new(e['sequence'],e['previousEvent']~string,plan)
    if restoredEvent~eventId \== e['id'] then report~add('STOP','EVENT.ID.MISMATCH',e['id']~string)
    graph~events~append(restoredEvent)
    prior=restoredEvent~eventId
  end
  if envelope['revision'] \== .nil then graph~revision=envelope['revision']
  if graph~revision \== graph~events~items then report~add('STOP','REVISION.MISMATCH','Event count differs from revision')
  return bundle
malformed:
  report~add('STOP','JSON.MALFORMED','Cannot parse DOCY snapshot')
  return bundle

::requires 'docy_v02.cls'
