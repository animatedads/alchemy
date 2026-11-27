/* Server-integrated per-session Wire UI. Never share one application/view
   across accounts, and never route a queue message by caller-supplied app ID. */
::requires 'DiplomacySession.cls'
::requires 'WireUIAll.cls'
::requires 'WireUIServer.cls'
::requires 'json.cls'

::class DiplomacyWireSession subclass WireUIApplication public
::method init
  expose session
  use strict arg aid,sid,ap,session
  view=.WireUIView~new('DIPLOMACY.WORKSPACE.'sid,'root')
  slots=.table~new; slots['visible']=.true
  slots['state']=.json~toJSON(session~project)
  slots['actions']=.array~of('DIP.CREATE','DIP.SELECT','DIP.SEAT','DIP.PROMPT','DIP.DESIGN','DIP.START','DIP.SUBMIT','DIP.REFRESH')
  r=view~createInstance('root','DIP_ROOT@1',slots)
  if r==.nil then raise syntax 93.900 array('View admission failed')
  if r~hasMethod('OK') then if \r~ok then raise syntax 93.900 array('Wire admission refused')
  do action over slots['actions']
    view~setActionAvailable('root',action,.true)
  end
  projection=.WireUIProjection~new
  r=projection~bind('state','root','state')
  if r==.nil then raise syntax 93.900 array('State admission failed')
  if r~hasMethod('OK') then if \r~ok then raise syntax 93.900 array('Wire admission refused')
  self~init:super(aid,sid,ap,view,projection)
  r=self~registerDefinition(.WireUIElementDefinition~new('DIP_ROOT','1','PANEL','','Diplomacy workspace','',.nil))
  if r==.nil then raise syntax 93.900 array('Definition admission failed')
  if r~hasMethod('OK') then if \r~ok then raise syntax 93.900 array('Wire admission refused')
  sub=.WireUISubscription~new('DIPLOMACY.WORKSPACE','1','Authorised game projection','policy:diplomacy')
  sub~addDefinition('DIP_ROOT@1')
  sub~activate
  r=self~addSubscription(sub)
  if r==.nil then raise syntax 93.900 array('Subscription admission failed')
  if r~hasMethod('OK') then if \r~ok then raise syntax 93.900 array('Wire admission refused')
::method dispatchSemanticAction
  expose session
  use strict arg action,message
  x=.table~new
  if message~hasIndex('detail') then x=message['detail']
  feedback=session~dispatch(action,x)
  p=session~project
  p['feedback']=feedback
  r=self~mutateState('state',.json~toJSON(p))
  if \r~ok then return r
  return .WireUIResult~success(feedback,'DIP_ACTION_HANDLED')

::class DiplomacyWireIngress public
::method init
  expose manager server admin bindings
  use strict arg manager,server,admin
  bindings=.table~new
::method bind
  expose bindings server
  use strict arg app,queuePrincipal
  ap=app~accessPointId
  if bindings~hasIndex(ap) then return .false
  /* Queue principal is provisioned by the authenticated host, not supplied
     by a WebSocket frame. It must be unique per access point. */
  do pair over bindings~allItems
    if pair[2]==queuePrincipal | pair[1]~applicationId==app~applicationId then return .false
  end
  r=server~provisionAccessPoint(ap,queuePrincipal)
  if \r~ok then return .false
  bindings[ap]=.array~of(app,queuePrincipal)
  return .true
::method pump
  expose bindings manager server admin
  use strict arg ap
  binding=bindings[ap]
  if binding==.nil then return .WireUIResult~failure('ACCESS_POINT_UNKNOWN')
  app=binding[1]
  queue=server~directQueueName(ap,'IN')
  claim=manager~claim(queue,admin)
  if \claim~ok then return .WireUIResult~failure(claim~code,claim~detail)
  package=claim~value
  payload=package~payload
  /* The server owns the AP binding; no registry lookup by appId. Even a
     correctly forged victim envelope sent through another queue fails. */
  outcome=.WireUIResult~failure('QUEUE_SESSION_MISMATCH')
  if payload~isA(.table) then do
    if payload['applicationId']==app~applicationId & payload['sessionId']==app~sessionId & payload['accessPointId']==ap then do
      if .array~of('UI_HELLO','UI_ACTION','UI_DEFINITION_REQUIRED','UI_RESYNC_REQUEST')~hasItem(payload['type']) then outcome=app~receive(payload)
      else outcome=.WireUIResult~failure('MESSAGE_TYPE_DENIED')
    end
  end
  ignore=manager~ack(queue,package~packageId,package~claimToken,admin)
  if outcome~ok then do
    if outcome~code=='RESYNC_SNAPSHOT' then call checkEnqueue server~enqueueToAccessPoint(ap,outcome~value)
    do msg over app~drainOutbound
      call checkEnqueue server~enqueueToAccessPoint(ap,msg)
    end
  end
  return outcome
::routine checkEnqueue
  use strict arg r
  if r==.nil then raise syntax 93.900 array('Authorised outbound queue failed')
  if r~hasMethod('OK') then if \r~ok then raise syntax 93.900 array('Wire admission refused')
