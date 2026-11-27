/* Loopback-only fixture. Never use this identity/credential fixture for production. */
parse arg portFile stopFile
d=.DiplomacyWeb~new
call mustCode d~register('fixture','Observer'),'REGISTERED'
k=d~addCredential('fixture','OPENAI','fixture-openai','Example OpenAI','fixture-only')
a=d~addCredential('fixture','ANTHROPIC','fixture-claude','Example Claude','fixture-only')
p=d~installSealedProfile('independent-fixture-designer','Independent sealed profile (fixture)','Fixture strategy hidden from players')
g=d~createGame('fixture','The 1901 experiment','LAB')
do power over .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  call mustCode d~seat('fixture',g,power,'LLM',k,'Negotiate openly; protect your position. Follow the pinned rules.'),'SEAT_SAVED'
end
game=d~game(g)
do row over .array~of('AUS|A|BUD','AUS|A|VIE','AUS|F|TRI','ENG|F|EDI','ENG|F|LON','ENG|A|LVP','FRA|F|BRE','FRA|A|MAR','FRA|A|PAR','GER|F|KIE','GER|A|BER','GER|A|MUN','ITA|F|NAP','ITA|A|ROM','ITA|A|VEN','RUS|A|WAR','RUS|A|MOS','RUS|F|SEV','RUS|F|STP/SC','TUR|F|ANK','TUR|A|CON','TUR|A|SMY')
  game~record('UNIT|'row)
  parse var row pow '|' typ '|' loc
  parse var loc loc '/' .
  game~record('CENTRE|'loc'|'pow)
end
game~record('PHASE|1901|SPRING_MOVEMENT')
game~record('PRESS_ROUND|1901|SPRING_MOVEMENT|1')
game~record('MAIL|fixture-1|ENG|FRA|0|'||'I propose that we keep the Channel clear this spring.'~c2x)
game~record('MAIL|fixture-2|FRA|ENG|0|'||'Agreed. Let us revisit the arrangement in autumn.'~c2x)
game~record('MAIL|fixture-3|RUS|TUR|0|'||'Shall we discuss the Black Sea?'~c2x)
game~record('PRESS_END|1901|SPRING_MOVEMENT|1|3')
h=d~createGame('fixture','Seven at the table','HUMAN')
m=d~createGame('fixture','Human and machine','MIXED')
manager=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,'admin')
view=.WireUIView~new('DIPLOMACY.WORKSPACE','root')
slots=.table~new; slots['visible']=.true
slots['state']=.json~toJSON(d~project('fixture',g))
slots['actions']=.array~of('DIP.REGISTER','DIP.CREATE','DIP.SELECT','DIP.CREDENTIAL.FIXTURE','DIP.SEAT','DIP.PROMPT','DIP.DESIGN','DIP.START','DIP.SUBMIT')
call must view~createInstance('root','DIP_ROOT@1',slots)
do action over slots['actions']
  view~setActionAvailable('root',action,.true)
end
projection=.WireUIProjection~new
call must projection~bind('state','root','state')
app=.DipApp~new('DIPLOMACY','S1','AP1',view,projection,d,g)
call must app~registerDefinition(.WireUIElementDefinition~new('DIP_ROOT','1','PANEL','','Diplomacy workspace','',.nil))
sub=.WireUISubscription~new('DIPLOMACY.WORKSPACE','1','Fixture projection','policy:fixture')
sub~addDefinition('DIP_ROOT@1')
sub~activate
call must app~addSubscription(sub)
call must server~registerApplication(app)
call must server~provisionAccessPoint('AP1','browser-gateway')
bridge=.QueueFabricWebGatewayBackend~new(manager,'WIREUI.IN.AP1','WIREUI.OUT.AP1','browser-gateway','fixture-loopback-only')
listener=.QueueFabricWebGatewayBridgeListener~new(bridge,'127.0.0.1',0)
if listener~serveAsync==.false then exit 3
call lineout portFile,listener~port
call lineout portFile
say 'DIPLOMACY_FIXTURE_READY' listener~port
do while stream(stopFile,'C','QUERY EXISTS')=''
  r=server~receiveFromAccessPoint('AP1','browser-gateway')
  if \r~ok & r~code\=='QUEUE_EMPTY' then say 'Wire refusal:' r~code
  do msg over app~drainOutbound
    call must server~enqueueToAccessPoint('AP1',msg)
  end
  call sysSleep 0.02
end
listener~stop
exit 0
must:
  use arg r
  if r==.nil then exit 10
  if r~hasMethod('OK') then if \r~ok then do
    say 'FAIL' r~code r~detail
    exit 10
  end
return
mustCode:
  use arg actual,expected
  if actual\==expected then exit 11
return
::class DipApp subclass WireUIApplication
::method init
  expose domain selected principal
  use arg aid,sid,ap,view,projection,domain,selected
  self~init:super(aid,sid,ap,view,projection)
  principal='fixture'
::method dispatchSemanticAction
  expose domain selected principal
  use arg action,message
  x=message['detail']
  if x==.nil then x=.table~new
  if \x~hasMethod('HASINDEX') then return .WireUIResult~failure('BAD_DETAIL')
  r='DENIED'
  select
    when action=='DIP.REGISTER' then do
      /* this is fixture-only, not an authenticated public registration */
      principal='fixture-registered'
      r=domain~register(principal,val(x,'display'))
    end
    when action=='DIP.SELECT' then do
      gid=val(x,'game')
      if domain~game(gid)\==.nil then do
        selected=gid; r='GAME_SELECTED'
      end
    end
    when action=='DIP.CREATE' then do
      r=domain~createGame(principal,val(x,'title'),val(x,'mode'))
      if r~left(1)=='G' then selected=r
    end
    when action=='DIP.CREDENTIAL.FIXTURE' then r=domain~addCredential(principal,val(x,'provider'),val(x,'model'),val(x,'label'),'fixture-only')
    when action=='DIP.SEAT' then r=domain~seat(principal,selected,val(x,'power'),val(x,'kind'),val(x,'credential'),val(x,'prompt'),val(x,'profile'))
    when action=='DIP.PROMPT' then r=domain~prompt(principal,selected,val(x,'power'),val(x,'prompt'))
    when action=='DIP.DESIGN' then r=domain~design(principal,selected,val(x,'power'),val(x,'credential'))
    when action=='DIP.SUBMIT' then if domain~game(selected)\==.nil then r=domain~game(selected)~submitTask(principal,val(x,'task'),val(x,'raw'))
    when action=='DIP.START' then if domain~game(selected)\==.nil then r=domain~game(selected)~start(principal)
    otherwise nop
  end
  p=domain~project(principal,selected)
  p['feedback']=r
  ignore=self~mutateState('state',.json~toJSON(p))
  return .WireUIResult~success(r,'DIP_ACTION_HANDLED')
::routine val
  use arg x,key
  if x~hasIndex(key) then if x[key]~isA(.string) then return x[key]
  return ''
::requires 'DiplomacyWeb.cls'
::requires 'json.cls'
::requires 'QueueFabricWebGatewayBridge.cls'
::requires 'WireUIAll.cls'
::requires 'WireUIServer.cls'
::requires 'ObjectQueueTopics.cls'
