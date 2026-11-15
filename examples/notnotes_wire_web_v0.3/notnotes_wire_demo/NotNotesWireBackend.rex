/* End-to-end demonstration bridge: REAL MiniNotesApp -> NotNotesWebProjectionPort
   -> WireUIApplication / WireUIServer -> same ObjectQueueManager -> Web Gateway.
   Browser is strictly presentation; no lifecycle logic lives in JavaScript. */
parse arg portFile stopFile resultFile dbRoot
if portFile='' | stopFile='' | resultFile='' | dbRoot='' then do
  say 'ERROR: requires port-file stop-file receipt-file db-root'
  exit 2
end

manager=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,'admin')
notNotes=.MiniNotesApp~new(dbRoot)
notNotes~seedFive
port=.NotNotesWireExtendedPort~new(notNotes)
authorities=.directory~new
authorities["NOTNOTES_FIELD_WRITE"]=.true
intentions=.AlchemyNotNotesIntentionRuntime~new(notNotes~node,.directory~new,authorities)
app=buildApp(port,intentions)
server~registerApplication(app)
call must server~provisionAccessPoint('AP1','browser-gateway'),'provision AP1'
bridge=.QueueFabricWebGatewayBackend~new(manager,'WIREUI.IN.AP1','WIREUI.OUT.AP1','browser-gateway','notnotes-dev-bridge-token')
listener=.QueueFabricWebGatewayBridgeListener~new(bridge,'127.0.0.1',0)
if listener~serveAsync==.false then do
  say 'ERROR: cannot start Queue Fabric bridge listener'
  exit 3
end
call lineout portFile,listener~port
call lineout portFile
say 'NOTNOTES_BACKEND_READY' listener~port

calls=0
errors=0
refusals=0
do while stream(stopFile,'C','QUERY EXISTS')=''
  r=server~receiveFromAccessPoint('AP1','browser-gateway')
  if r~ok then do
    say 'TRACE SERVER OK' r~code
    calls+=1
  end
  else if r~code='NOTNOTES_ACTION_REFUSED' then do
    refusals+=1
    say 'REFUSED ACTION' r~detail
  end
  else if r~code<>'QUEUE_EMPTY' then do
    errors+=1
    say 'ERROR receive' r~code r~detail
  end
  /* Rejected actions may still publish an authoritative error/status projection.
     Never discard view patches merely because the action result is REFUSED. */
  out=app~drainOutbound
  if out~items>0 then say 'TRACE OUTBOUND' out~items
  do msg over out
    qr=server~enqueueToAccessPoint('AP1',msg)
    if \qr~ok then do
      errors+=1
      say 'ERROR outbound' qr~code qr~detail
    end
  end
  call sysSleep 0.02
end
receipt=.directory~new
receipt['handledRequests']=calls
receipt['serverErrors']=errors
receipt['refusedActions']=refusals
state=port~project('All Documents','','',0,50)
receipt['selectedKey']=state['selectedKey']
state=port~project('All Documents','','PR-1002',0,50)
receipt['pr1002Status']=state['detail']['status']
call lineout resultFile,.json~toJSON(receipt)
call lineout resultFile
ignore=listener~stop
exit 0

buildApp: procedure
  use arg port,intentions
  p=port~project('All Documents','','PR-1002',0,50)
  view=.WireUIView~new('NOTNOTES.WORKSPACE','root')
  slots=.table~new; slots['visible']=.true; slots['ariaLabel']='notNotes document workspace'
  call must view~createInstance('root','NN_ROOT@1',slots),'root'
  slots=.table~new; slots['value']='notNotes — live Wire UI'; call must view~createInstance('heading','NN_HEADING@1',slots,'root'),'heading'
  slots=.table~new; slots['value']='Documents: 'p['totalCount']' | Authoritative application: MiniNotesApp'; call must view~createInstance('summary','NN_SUMMARY@1',slots,'root'),'summary'
  slots=.table~new; slots['items']=p['rows']; slots['visible']=.true; slots['action']='NOTNOTES.SELECT_DOCUMENT'; call must view~createInstance('documents','NN_DOCUMENTS@1',slots,'root'),'documents'
  slots=.table~new; slots['value']=p['detail']['title']; call must view~createInstance('title','NN_TITLE@1',slots,'root'),'title'
  slots=.table~new; slots['value']=p['detail']['status']; call must view~createInstance('status','NN_STATUS@1',slots,'root'),'status'
  slots=.table~new; slots['value']='Selected: 'p['selectedKey']' · risk 'p['detail']['risk']; call must view~createInstance('selection','NN_SELECTION@1',slots,'root'),'selection'
  slots=.table~new; slots['text']='Approve selected document'; slots['enabled']=.true; slots['action']='NOTNOTES.APPROVE'; call must view~createInstance('approve','NN_APPROVE@1',slots,'root'),'approve'
  slots=.table~new; slots['text']='Reject selected document'; slots['enabled']=.true; slots['action']='NOTNOTES.REJECT'; call must view~createInstance('reject','NN_REJECT@1',slots,'root'),'reject'
  slots=.table~new; slots['value']=''; call must view~createInstance('feedback','NN_FEEDBACK@1',slots,'root'),'feedback'
  slots=.table~new; slots['value']='Document fields'; call must view~createInstance('fieldsHeading','NN_FIELDS_HEADING@1',slots,'root'),'fields heading'
  slots=.table~new; slots['items']=p['detail']['fields']; slots['visible']=.true; call must view~createInstance('fields','NN_FIELDS@1',slots,'root'),'document fields'
  slots=.table~new; slots['value']='Edit selected document'; call must view~createInstance('editorHeading','NN_EDITOR_HEADING@1',slots,'root'),'editor heading'
  editFields=.table~new
  editFields['Title']='title'; editFields['Amount']='amount'; editFields['Risk (LOW/MEDIUM/HIGH)']='risk'
  slots=.table~new; slots['title']=p['detail']['title']; slots['amount']=p['detail']['amount']; slots['risk']=p['detail']['risk']; slots['visible']=.true; slots['action']='NOTNOTES.UPDATE_DOCUMENT'
  call must view~createInstance('edit','NN_EDIT@1',slots,'root'),'edit form'
  slots=.table~new; slots['value']='Create document'; call must view~createInstance('createHeading','NN_CREATE_HEADING@1',slots,'root'),'create heading'
  createFields=.table~new
  createFields['Document type']='type'; createFields['Title']='title'; createFields['Amount']='amount'; createFields['Risk (LOW/MEDIUM/HIGH)']='risk'; createFields['Dependencies (keys)']='dependsOn'
  slots=.table~new; slots['type']='Purchase Request'; slots['title']=''; slots['amount']='0'; slots['risk']='LOW'; slots['dependsOn']=''; slots['visible']=.true; slots['action']='NOTNOTES.CREATE_DOCUMENT'
  call must view~createInstance('create','NN_CREATE@1',slots,'root'),'create form'
  slots=.table~new; slots['value']='Intentions — enter a request or answer confirmation'; call must view~createInstance('intentionHeading','NN_INTENTION_HEADING@1',slots,'root'),'intention heading'
  intentFields=.table~new; intentFields['Request or confirmation']='request'
  slots=.table~new; slots['request']=''; slots['visible']=.true; slots['action']='NOTNOTES.INTENTION.INPUT'
  call must view~createInstance('intention','NN_INTENTION@1',slots,'root'),'intention form'
  slots=.table~new; slots['value']=''; call must view~createInstance('intentionResult','NN_INTENTION_RESULT@1',slots,'root'),'intention result'
  slots=.table~new; slots['value']='Formats and saved reports'; call must view~createInstance('catalogueHeading','NN_CATALOGUE_HEADING@1',slots,'root'),'catalogue heading'
  slots=.table~new; slots['value']=''; call must view~createInstance('catalogue','NN_CATALOGUE@1',slots,'root'),'catalogue'
  slots=.table~new; slots['value']='Define a document format'; call must view~createInstance('formatHeading','NN_FORMAT_HEADING@1',slots,'root'),'format heading'
  formatFields=.table~new
  formatFields['Format name']='format'; formatFields['Fields: NAME|Label|TYPE; ...']='fields'
  slots=.table~new; slots['format']=''; slots['fields']=''; slots['visible']=.true; slots['action']='NOTNOTES.DESIGN_FORMAT'
  call must view~createInstance('format','NN_FORMAT@1',slots,'root'),'format designer'
  slots=.table~new; slots['value']='Complete a user-defined document'; call must view~createInstance('userDocHeading','NN_USERDOC_HEADING@1',slots,'root'),'user doc heading'
  userDocFields=.table~new; userDocFields['Format name']='format'; userDocFields['Field values: NAME=value; ...']='values'
  slots=.table~new; slots['format']=''; slots['values']=''; slots['visible']=.true; slots['action']='NOTNOTES.CREATE_USER_DOCUMENT'
  call must view~createInstance('userDoc','NN_USERDOC@1',slots,'root'),'user doc form'
  slots=.table~new; slots['value']='Edit a typed document field'; call must view~createInstance('typedHeading','NN_TYPED_HEADING@1',slots,'root'),'typed heading'
  typedFields=.table~new; typedFields['Field name']='field'; typedFields['New value']='value'
  slots=.table~new; slots['field']=''; slots['value']=''; slots['visible']=.true; slots['action']='NOTNOTES.SET_FIELD'
  call must view~createInstance('typed','NN_TYPED@1',slots,'root'),'typed edit form'
  slots=.table~new; slots['value']='Link or unlink a document reference'; call must view~createInstance('linkHeading','NN_LINK_HEADING@1',slots,'root'),'link heading'
  linkFields=.table~new; linkFields['Reference field']='field'; linkFields['Target document key']='target'
  slots=.table~new; slots['field']=''; slots['target']=''; slots['visible']=.true; slots['action']='NOTNOTES.LINK_DOCUMENT'
  call must view~createInstance('link','NN_LINK@1',slots,'root'),'link form'
  slots=.table~new; slots['field']=''; slots['target']=''; slots['visible']=.true; slots['action']='NOTNOTES.UNLINK_DOCUMENT'
  call must view~createInstance('unlink','NN_UNLINK@1',slots,'root'),'unlink form'
  slots=.table~new; slots['value']='Saved report designer and runner'; call must view~createInstance('reportsHeading','NN_REPORTS_HEADING@1',slots,'root'),'reports heading'
  reportFields=.table~new; reportFields['Report name']='report'; reportFields['Document format']='sourceForm'; reportFields['Columns: Label=BINDING; ...']='columns'
  slots=.table~new; slots['report']=''; slots['sourceForm']=''; slots['columns']=''; slots['visible']=.true; slots['action']='NOTNOTES.DESIGN_REPORT'
  call must view~createInstance('reportDesign','NN_REPORT_DESIGN@1',slots,'root'),'report designer'
  reportRunFields=.table~new; reportRunFields['Saved report name']='report'
  slots=.table~new; slots['report']=''; slots['visible']=.true; slots['action']='NOTNOTES.RUN_REPORT'
  call must view~createInstance('reportRun','NN_REPORT_RUN@1',slots,'root'),'report runner'
  slots=.table~new; slots['value']=''; call must view~createInstance('reportOutput','NN_REPORT_OUTPUT@1',slots,'root'),'report output'
  slots=.table~new; slots['text']='Submit selected document'; slots['enabled']=.true; slots['action']='NOTNOTES.SUBMIT'; call must view~createInstance('submit','NN_SUBMIT@1',slots,'root'),'submit'
  slots=.table~new; slots['text']='Save selected document'; slots['enabled']=.true; slots['action']='NOTNOTES.SAVE_DOCUMENT'; call must view~createInstance('save','NN_SAVE@1',slots,'root'),'save'
  view~setActionAvailable('documents','NOTNOTES.SELECT_DOCUMENT',.true)
  view~setActionAvailable('approve','NOTNOTES.APPROVE',.true)
  view~setActionAvailable('reject','NOTNOTES.REJECT',.true)
  do binding over .array~of('edit|NOTNOTES.UPDATE_DOCUMENT','create|NOTNOTES.CREATE_DOCUMENT','intention|NOTNOTES.INTENTION.INPUT','submit|NOTNOTES.SUBMIT','save|NOTNOTES.SAVE_DOCUMENT','format|NOTNOTES.DESIGN_FORMAT','userDoc|NOTNOTES.CREATE_USER_DOCUMENT','typed|NOTNOTES.SET_FIELD','link|NOTNOTES.LINK_DOCUMENT','unlink|NOTNOTES.UNLINK_DOCUMENT','reportDesign|NOTNOTES.DESIGN_REPORT','reportRun|NOTNOTES.RUN_REPORT')
    parse var binding instance '|' action
    view~setActionAvailable(instance,action,.true)
  end
  projection=.WireUIProjection~new
  call must projection~bind('summary','summary','value'),'binding summary'
  call must projection~bind('rows','documents','items'),'binding documents'
  call must projection~bind('title','title','value'),'binding title'
  call must projection~bind('status','status','value'),'binding status'
  call must projection~bind('selection','selection','value'),'binding selection'
  call must projection~bind('fields','fields','items'),'document fields projection'
  call must projection~bind('createTitle','create','title'),'create title projection'
  call must projection~bind('createAmount','create','amount'),'create amount projection'
  call must projection~bind('editTitle','edit','title'),'edit title'
  call must projection~bind('editAmount','edit','amount'),'edit amount'
  call must projection~bind('editRisk','edit','risk'),'edit risk'
  call must projection~bind('feedback','feedback','value'),'feedback'
  call must projection~bind('intentionResult','intentionResult','value'),'intention result'
  /* One atomic authoritative view revision per semantic action. */
  group=.NotNotesWireGroupProjection~new
  group~bind('summary','summary','value')
  group~bind('rows','documents','items')
  group~bind('title','title','value')
  group~bind('status','status','value')
  group~bind('selection','selection','value')
  group~bind('fields','fields','items')
  group~bind('editTitle','edit','title')
  group~bind('editAmount','edit','amount')
  group~bind('editRisk','edit','risk')
  group~bind('createTitle','create','title')
  group~bind('createAmount','create','amount')
  group~bind('feedback','feedback','value')
  group~bind('intentionResult','intentionResult','value')
  group~bind('catalogue','catalogue','value')
  group~bind('reportOutput','reportOutput','value')
  keys=.array~of('summary','rows','title','status','selection','fields','editTitle','editAmount','editRisk','createTitle','createAmount','feedback','intentionResult','catalogue','reportOutput')
  call must projection~bindDerived(keys,group),'atomic projection binding'
  app=.NotNotesWireUIApplication~new('NOTNOTES','S1','AP1',view,projection,port,intentions)
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_ROOT','1','PANEL','','','',.nil, 'nn-root-ca')),'def root'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_HEADING','1','TEXT','','','',.nil, 'nn-heading-ca')),'def heading'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_SUMMARY','1','TEXT','','','',.nil, 'nn-summary-ca')),'def summary'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_DOCUMENTS','1','SEMANTIC_COLLECTION','NOTNOTES.SELECT_DOCUMENT','Documents','',.nil, 'nn-documents-ca')),'def documents'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_TITLE','1','TEXT','','','',.nil, 'nn-title-ca')),'def title'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_STATUS','1','TEXT','','','',.nil, 'nn-status-ca')),'def status'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_SELECTION','1','TEXT','','','',.nil, 'nn-selection-ca')),'def selection'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_APPROVE','1','ACTION_BUTTON','NOTNOTES.APPROVE','Approve selected document','',.nil, 'nn-approve-ca')),'def approve'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_REJECT','1','ACTION_BUTTON','NOTNOTES.REJECT','Reject selected document','',.nil, 'nn-reject-ca')),'def reject'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_FEEDBACK','1','TEXT','','','',.nil,'nn-feedback-ca')),'def feedback'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_FIELDS_HEADING','1','TEXT','','','',.nil,'nn-fields-heading-ca')),'def fields heading'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_FIELDS','1','SEMANTIC_COLLECTION','','Fields','',.nil,'nn-fields-ca')),'def fields'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_EDITOR_HEADING','1','TEXT','','','',.nil,'nn-editor-heading-ca')),'def editor heading'
  editMeta=.table~new; editMeta['bindings']=editFields; editMeta['submitLabel']='Save document changes'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_EDIT','1','FORM','NOTNOTES.UPDATE_DOCUMENT','Edit document','',editMeta,'nn-edit-form-ca')),'def edit form'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_CREATE_HEADING','1','TEXT','','','',.nil,'nn-create-heading-ca')),'def create heading'
  createMeta=.table~new; createMeta['bindings']=createFields; createMeta['submitLabel']='Create document'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_CREATE','1','FORM','NOTNOTES.CREATE_DOCUMENT','Create document','',createMeta,'nn-create-form-ca')),'def create form'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_INTENTION_HEADING','1','TEXT','','','',.nil,'nn-intention-heading-ca')),'def intention heading'
  intentionMeta=.table~new; intentionMeta['bindings']=intentFields; intentionMeta['submitLabel']='Run intention'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_INTENTION','1','FORM','NOTNOTES.INTENTION.INPUT','Interpret intention','',intentionMeta,'nn-intention-form-ca')),'def intention form'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_INTENTION_RESULT','1','TEXT','','','',.nil,'nn-intention-result-ca')),'def intention result'
  do definition over .array~of('NN_CATALOGUE_HEADING|TEXT','NN_CATALOGUE|TEXT','NN_FORMAT_HEADING|TEXT','NN_USERDOC_HEADING|TEXT','NN_TYPED_HEADING|TEXT','NN_LINK_HEADING|TEXT','NN_REPORTS_HEADING|TEXT','NN_REPORT_OUTPUT|TEXT')
    parse var definition id '|' kind
    call must app~registerDefinition(.WireUIElementDefinition~new(id,'1',kind,'','','',.nil,id || '-ca')),'def' id
  end
  formatMeta=.table~new; formatMeta['bindings']=formatFields; formatMeta['submitLabel']='Save document format'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_FORMAT','1','FORM','NOTNOTES.DESIGN_FORMAT','Define format','',formatMeta,'nn-format-ca')),'def format'
  userDocMeta=.table~new; userDocMeta['bindings']=userDocFields; userDocMeta['submitLabel']='Create user document'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_USERDOC','1','FORM','NOTNOTES.CREATE_USER_DOCUMENT','Complete document','',userDocMeta,'nn-userdoc-ca')),'def user doc'
  typedMeta=.table~new; typedMeta['bindings']=typedFields; typedMeta['submitLabel']='Save typed field'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_TYPED','1','FORM','NOTNOTES.SET_FIELD','Edit typed field','',typedMeta,'nn-typed-ca')),'def typed'
  linkMeta=.table~new; linkMeta['bindings']=linkFields; linkMeta['submitLabel']='Link document'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_LINK','1','FORM','NOTNOTES.LINK_DOCUMENT','Link document','',linkMeta,'nn-link-ca')),'def link'
  unlinkMeta=.table~new; unlinkMeta['bindings']=linkFields; unlinkMeta['submitLabel']='Unlink document'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_UNLINK','1','FORM','NOTNOTES.UNLINK_DOCUMENT','Unlink document','',unlinkMeta,'nn-unlink-ca')),'def unlink'
  reportDesignMeta=.table~new; reportDesignMeta['bindings']=reportFields; reportDesignMeta['submitLabel']='Save report'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_REPORT_DESIGN','1','FORM','NOTNOTES.DESIGN_REPORT','Design saved report','',reportDesignMeta,'nn-report-design-ca')),'def report designer'
  reportRunMeta=.table~new; reportRunMeta['bindings']=reportRunFields; reportRunMeta['submitLabel']='Run saved report'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_REPORT_RUN','1','FORM','NOTNOTES.RUN_REPORT','Run saved report','',reportRunMeta,'nn-report-run-ca')),'def report runner'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_SUBMIT','1','ACTION_BUTTON','NOTNOTES.SUBMIT','Submit selected document','',.nil,'nn-submit-ca')),'def submit'
  call must app~registerDefinition(.WireUIElementDefinition~new('NN_SAVE','1','ACTION_BUTTON','NOTNOTES.SAVE_DOCUMENT','Save selected document','',.nil,'nn-save-ca')),'def save'
  sub=.WireUISubscription~new('NOTNOTES.DOCUMENTS','1','Authenticated NotNotes document workspace','policy:notnotes')
  do def over .array~of('NN_ROOT','NN_HEADING','NN_SUMMARY','NN_DOCUMENTS','NN_TITLE','NN_STATUS','NN_SELECTION','NN_APPROVE','NN_REJECT','NN_FEEDBACK','NN_FIELDS_HEADING','NN_FIELDS','NN_EDITOR_HEADING','NN_EDIT','NN_CREATE_HEADING','NN_CREATE','NN_INTENTION_HEADING','NN_INTENTION','NN_INTENTION_RESULT','NN_CATALOGUE_HEADING','NN_CATALOGUE','NN_FORMAT_HEADING','NN_FORMAT','NN_USERDOC_HEADING','NN_USERDOC','NN_TYPED_HEADING','NN_TYPED','NN_LINK_HEADING','NN_LINK','NN_UNLINK','NN_REPORTS_HEADING','NN_REPORT_DESIGN','NN_REPORT_RUN','NN_REPORT_OUTPUT','NN_SUBMIT','NN_SAVE')
    ignore=sub~addDefinition(def || '@1')
  end
  sub~activate
  call must app~addSubscription(sub),'subscription'
  return app

must: procedure
  use arg result,label
  if result==.nil then do; say 'FAIL' label 'nil'; exit 10; end
  if result~hasMethod('OK') then if \result~ok then do; say 'FAIL' label result~code result~detail; exit 10; end
  return result

::class NotNotesWireGroupProjection public
::method init
  expose wiring
  wiring=.table~new
::method bind
  expose wiring
  use arg stateKey,instanceId,slotName
  wiring[stateKey]=.array~of(instanceId,slotName)
  return self
::method call
  expose wiring
  use arg stateSnapshot,changedKeys
  output=.table~new
  do key over changedKeys
    if \wiring~hasIndex(key) then iterate
    targetRef=wiring[key]
    instanceId=targetRef[1]
    target=output[instanceId]
    if target==.nil then do
      target=.table~new
      output[instanceId]=target
    end
    target[targetRef[2]]=stateSnapshot[key]
  end
  return output

::class NotNotesWireUIApplication subclass WireUIApplication
::method init
  expose port intentions intentionMessage reportText
  use arg applicationId,sessionId,accessPointId,view,projection,portArg,intentionsArg
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  port=portArg
  intentions=intentionsArg
  intentionMessage=""
  reportText=""

::method dispatchSemanticAction
  expose port intentions intentionMessage reportText
  use arg action,message
  say 'TRACE DISPATCH' action
  detail=message['detail']
  if detail==.nil then detail=.directory~new
  say 'TRACE PORT start'
  if action='NOTNOTES.INTENTION.INPUT' then do
    request=''
    if detail~hasIndex('request') then request=detail['request']~string~strip
    if request='' then return .WireUIResult~failure('INTENTION_TEXT_REQUIRED')
    decision=intentions~input(request)
    intentionMessage='Intention status: 'decision~status
    if decision~registration \== .nil then intentionMessage=intentionMessage' · 'decision~registration~id
    if decision~planAssessment \== .nil then intentionMessage=intentionMessage' · 'decision~planAssessment~status
    say 'TRACE INTENTION' decision~status
    do slotName over decision~slots~allIndexes
      say 'TRACE SLOT' slotName decision~slots[slotName]~value
    end
    if decision~status='READY' then do
      result=intentions~dispatch(decision)
      intentionMessage=intentionMessage' · dispatched by Intention Service'
      ignore=port~application~persistNow
      if port~application~selected \== .nil then say 'TRACE SELECTED AFTER INTENTION' port~application~selected~DocKey port~application~selected~Title
    end
    r=.directory~new; r['ok']=.true; r['status']=decision~status
  end
  else r=port~perform(action,detail)
  if action='NOTNOTES.RUN_REPORT' & r['ok'] then do
    reportText='Report: 'detail['report']' — rows: 'r['result']['COUNT'] || '0a'x || r['result']['TEXT']
  end
  say 'TRACE PORT result' r['ok']
  p=port~project('All Documents','','',0,50)
  changes=.table~new
  changes['summary']='Documents: 'p['totalCount']' | Authoritative application: MiniNotesApp'
  changes['rows']=p['rows']
  changes['title']=p['detail']['title']
  changes['status']=p['detail']['status']
  changes['selection']='Selected: 'p['selectedKey']' · risk 'p['detail']['risk']
  changes['fields']=p['detail']['fields']
  if action='NOTNOTES.CREATE_DOCUMENT' & r['ok'] then do
    changes['createTitle']=''
    changes['createAmount']='0'
  end
  changes['editTitle']=p['detail']['title']
  changes['editAmount']=p['detail']['amount']
  changes['editRisk']=p['detail']['risk']
  outcome='OK'
  if r~hasIndex('status') then outcome=r['status']
  changes['feedback']=action' : 'outcome
  if \r['ok'] then changes['feedback']=action' : REFUSED 'outcome
  changes['intentionResult']=intentionMessage
  changes['reportOutput']=reportText
  changes['catalogue']=catalogueText(p)
  /* Standard projection bindings use mutateState; mutateStateGroup projects
     only bindDerived outputs, so it would silently emit zero UI patches. */
  rr=self~mutateStateGroup(changes)
  if \rr~ok then return rr
  say 'TRACE STATE PATCHES emitted' self~view~revision
  if \r['ok'] then return .WireUIResult~failure('NOTNOTES_ACTION_REFUSED',r['status'])
  return .WireUIResult~success(r,'NOTNOTES_ACTION_EXECUTED')

::routine catalogueText
  use arg p
  formats='Formats: '
  do item over p['formats']
    if formats<>'Formats: ' then formats=formats || ', '
    formats=formats || item
  end
  reports='Saved reports: '
  do item over p['reports']
    if reports<>'Saved reports: ' then reports=reports || ', '
    reports=reports || item
  end
  return formats || '0a'x || reports

::requires 'json.cls'
::requires 'MiniNotesApp.cls'
::requires 'NotNotesWireExtendedPort.cls'
::requires 'QueueFabricWebGatewayBridge.cls'
::requires 'WireUIAll.cls'
::requires 'WireUIServer.cls'
::requires 'ObjectQueueTopics.cls'
::requires 'AlchemyNotNotesIntentions.cls'
