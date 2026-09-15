/* Test-only full Wire UI application bridge for the real Queue Fabric gateway acceptance.
   The Node gateway remains generic. This process owns Queue Fabric + WireUIServer + app. */
parse arg inputQueue outputQueue defaultPrincipal securityDomain storeRoot
if inputQueue='' then inputQueue='WIREUI.IN.AP1'
if outputQueue='' then outputQueue='WIREUI.OUT.AP1'
if defaultPrincipal='' then defaultPrincipal='wireui-gateway'
if securityDomain='' then securityDomain='WIREUI'
if storeRoot='' then storeRoot=''

manager=.ObjectQueueManager~new(storeRoot,.QueueGraphPayloadCodec~new,'admin')
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,'admin')
app=buildApp()
server~registerApplication(app)
call must server~provisionAccessPoint('AP1',defaultPrincipal),'provision access point'
call grantAccess inputQueue,defaultPrincipal
call grantAccess outputQueue,defaultPrincipal

running=.true
do while running
  line=linein()
  if line='' then do
    if lines()=0 then leave
    iterate
  end
  request=parseRequest(line)
  if request==.nil then do
    response=.directory~new; response['id']=''; response['ok']=.json~false; response['code']='INVALID_JSON'; response['detail']='request is not valid JSON'
    say .json~toJSON(response)
    iterate
  end
  id=valueOr(request,'id','')
  op=valueOr(request,'op','')~string~upper
  select
    when op='PING' then call emitResponse id,.QueueOperationResult~success('PONG')
    when op='PUT' then do
      queue=valueOr(request,'queue',inputQueue)
      payload=request~at('payload')
      options=request~at('options'); if options==.nil then options=.directory~new
      principal=commandPrincipal(request)
      putResult=manager~put(queue,payload,options,principal)
      if putResult~ok & queue=inputQueue then call serviceIncoming principal
      call emitResponse id,putResult
    end
    when op='CLAIM' then call emitResponse id,manager~claim(valueOr(request,'queue',outputQueue),commandPrincipal(request))
    when op='ACK' then call emitResponse id,manager~ack(valueOr(request,'queue',outputQueue),valueOr(request,'packageId',''),valueOr(request,'claimToken',''),commandPrincipal(request))
    when op='NACK' then call emitResponse id,manager~nack(valueOr(request,'queue',outputQueue),valueOr(request,'packageId',''),valueOr(request,'claimToken',''),commandPrincipal(request))
    when op='RELEASE' then call emitResponse id,manager~release(valueOr(request,'queue',outputQueue),valueOr(request,'packageId',''),valueOr(request,'claimToken',''),commandPrincipal(request),valueOr(request,'detail','gateway release'))
    when op='DEPTH' then call emitResponse id,manager~depth(valueOr(request,'queue',outputQueue),commandPrincipal(request))
    when op='SHUTDOWN' then do; call emitResponse id,.QueueOperationResult~success('BYE'); running=.false; end
    otherwise call emitResponse id,.QueueOperationResult~failure('UNKNOWN_OPERATION',op)
  end
end
exit 0

serviceIncoming: procedure expose server app
  use arg principal
  r=server~receiveFromAccessPoint('AP1',principal)
  if \r~ok then return
  out=app~drainOutbound
  do m over out
    q=server~enqueueToAccessPoint('AP1',m)
    if \q~ok then raise syntax 93.900 additional('failed to enqueue Wire UI outbound' q~code q~detail)
  end
  return

buildApp: procedure
  view=.WireUIView~new('FlyLo.Booking','root')
  slots=.table~new; slots['visible']=.true
  call must view~createInstance('root','FLYLO_ROOT@1',slots),'root'
  ask=.table~new; ask['visible']=.true; ask['enabled']=.true; ask['action']='ASSISTANT.OPEN'; ask['label']='Ask FlyLo'
  call must view~createInstance('ask','ASK_TRIGGER@1',ask,'root'),'ask'
  answer=.table~new; answer['visible']=.true; answer['value']='Ask FlyLo is ready.'
  call must view~createInstance('answer','ASSISTANT_ANSWER@1',answer,'root'),'answer'
  view~setActionAvailable('ask','ASSISTANT.OPEN',.true)
  projection=.WireUIProjection~new; projection~bind('assistantAnswer','answer','value')
  app=.GatewayDemoApplication~new('FLYLO','S1','AP1',view,projection)
  call must app~registerDefinition(.WireUIElementDefinition~new('FLYLO_ROOT','1','PANEL','','','',.nil,'root-ca')),'root def'
  call must app~registerDefinition(.WireUIElementDefinition~new('ASK_TRIGGER','1','ACTION_BUTTON','ASSISTANT.OPEN','Ask FlyLo','',.nil,'ask-ca')),'ask def'
  call must app~registerDefinition(.WireUIElementDefinition~new('ASSISTANT_ANSWER','1','TEXT','','','',.nil,'answer-ca')),'answer def'
  sub=.WireUISubscription~new('FLYLO.SEARCH','1','FlyLo active search and assistant','policy:flylo')
  sub~addDefinition('FLYLO_ROOT@1'); sub~addDefinition('ASK_TRIGGER@1'); sub~addDefinition('ASSISTANT_ANSWER@1'); sub~activate; app~addSubscription(sub)
  return app

parseRequest: procedure
  use arg line
  signal on syntax name invalid
  value=.json~fromJSON(line)
  signal off syntax
  return value
invalid:
  signal off syntax
  return .nil

grantAccess: procedure expose manager
  use arg queueName,principal
  actions=.array~of(.QueueAccess~PUT,.QueueAccess~GET,.QueueAccess~BROWSE)
  do action over actions
    result=manager~grant(queueName,principal,action,'admin')
    if \result~ok then raise syntax 93.900 additional('cannot grant' action 'on' queueName result~code result~detail)
  end
  return

commandPrincipal: procedure expose defaultPrincipal
  use arg request
  principal=request~at('principal')
  if principal==.nil | principal='' then return defaultPrincipal
  return principal~string

valueOr: procedure
  use arg object,key,fallback
  value=object~at(key)
  if value==.nil then return fallback
  return value

emitResponse: procedure
  use arg id,operationResult
  response=.directory~new
  response['id']=id
  if operationResult~ok then response['ok']=.json~true; else response['ok']=.json~false
  response['code']=operationResult~code; response['detail']=operationResult~detail
  if operationResult~value\==.nil then do
    if operationResult~value~isA(.QueueWorkPackage) then response['value']=packageProjection(operationResult~value)
    else response['value']=operationResult~value
  end
  say .json~toJSON(response)
  return

packageProjection: procedure
  use arg package
  value=.directory~new
  value['packageId']=package~packageId; value['payload']=package~payload; value['priority']=package~priority; value['persistent']=package~persistent
  value['securityDomain']=package~securityDomain; value['routingKey']=package~routingKey; value['correlationId']=package~correlationId; value['replyTo']=package~replyTo
  value['requestedQueue']=package~requestedQueue; value['currentQueue']=package~currentQueue; value['createdAt']=package~createdAt; value['sequence']=package~sequence
  value['deliveryCount']=package~deliveryCount; value['backoutCount']=package~backoutCount; value['claimToken']=package~claimToken
  return value

must: procedure
  use arg r,label
  if \r~ok then raise syntax 93.900 additional('setup failed' label r~code r~detail)
  return

::class GatewayDemoApplication subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  if action='ASSISTANT.OPEN' then do
    ignore=self~mutateState('assistantAnswer',"FlyLo's assistant tried very hard. Nothing has been added to your booking.")
    return .WireUIResult~success('assistant-opened')
  end
  return .WireUIResult~failure('UNKNOWN_ACTION',action)

::requires 'json.cls'
::requires 'WireUIAll.cls'
::requires 'WireUIServer.cls'
::requires 'ObjectQueueFabric.cls'
::requires 'ObjectQueueTopics.cls'
