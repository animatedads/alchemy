/* Real estate queue ownership and Wire UI boundary; malicious message
   tries to address another principal using an entirely forged envelope. */
n=0
d=.DiplomacyWeb~new
call eq d~register('Alice','Alice'),'REGISTERED'
call eq d~register('Bob','Bob'),'REGISTERED'
g=d~createGame('Alice','Private lab','LAB')
k=d~addCredential('Alice','OPENAI','test','test','PRIVATE_VAULT')
call eq d~seat('Alice',g,'ENG','LLM',k,'ALICE_PRIVATE_PROMPT'),'SEAT_SAVED'
manager=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,'admin')
ingress=.DiplomacyWireIngress~new(manager,server,'admin')
alice=.DiplomacyWireSession~new('A','S-A','AP-A',.DiplomacySession~new(d,'Alice',g))
bob=.DiplomacyWireSession~new('B','S-B','AP-B',.DiplomacySession~new(d,'Bob',g))
call eq ingress~bind(alice,'gateway-a'),.true
call eq ingress~bind(bob,'gateway-b'),.true
call eq ingress~bind(bob,'gateway-c'),.false
m=.table~new; m['applicationId']='A'; m['sessionId']='S-A'; m['accessPointId']='AP-A'; m['type']='UI_HELLO'; m['messageId']='forged'
opts=.table~new
r=manager~put('WIREUI.IN.AP-A',m,opts,'gateway-b')
call eq r~ok,.false
r=manager~put('WIREUI.IN.AP-B',m,opts,'gateway-b')
call eq r~ok,.true
call eq ingress~pump('AP-B')~code,'QUEUE_SESSION_MISMATCH'
call eq manager~claim('WIREUI.OUT.AP-A','gateway-b')~ok,.false
call eq manager~claim('WIREUI.OUT.AP-B','gateway-b')~ok,.false
do p over .array~of('A','B')
  m=.table~new; m['applicationId']=p; m['sessionId']='S-'p; m['accessPointId']='AP-'p; m['type']='UI_HELLO'; m['messageId']='hello-'p
  r=manager~put('WIREUI.IN.AP-'p,m,opts,'gateway-'p~lower)
  call eq r~ok,.true
  call eq ingress~pump('AP-'p)~ok,.true
  found=.false; private=.false
  do forever
    c=manager~claim('WIREUI.OUT.AP-'p,'gateway-'p~lower)
    if \c~ok then leave
    raw=.json~toJSON(c~value~payload)
    if raw~pos('ALICE_PRIVATE_PROMPT')>0 then private=.true
    if c~value~payload~hasIndex('elementInstances') then found=.true
    ignore=manager~ack('WIREUI.OUT.AP-'p,c~value~packageId,c~value~claimToken,'gateway-'p~lower)
  end
  call eq found,.true
  call eq private,(p=='A')
end
/* Correct queue + victim envelope is refused even for an action. */
m=.table~new; m['type']='UI_ACTION'; m['applicationId']='A'; m['sessionId']='S-A'; m['accessPointId']='AP-A'; m['messageId']='forged-action'
m['viewRef']=alice~view~viewRef; m['renderedRevision']=alice~view~revision; m['elementInstance']='root'; m['action']='DIP.PROMPT'
x=.table~new; x['power']='ENG'; x['prompt']='ATTACKER_MUTATION'; m['detail']=x
call eq manager~put('WIREUI.IN.AP-B',m,opts,'gateway-b')~ok,.true
call eq ingress~pump('AP-B')~code,'QUEUE_SESSION_MISMATCH'
call eq d~game(g)~project('Alice')['seats'][2]['prompt'],'ALICE_PRIVATE_PROMPT'
/* Correct actor envelope + forged principal in detail still cannot edit. */
m['applicationId']='B'; m['sessionId']='S-B'; m['accessPointId']='AP-B'; m['viewRef']=bob~view~viewRef; m['renderedRevision']=bob~view~revision; m['messageId']='forged-detail'
x['principal']='Alice'
call eq manager~put('WIREUI.IN.AP-B',m,opts,'gateway-b')~ok,.true
r=ingress~pump('AP-B')
call eq r~ok,.true
call eq r~value,'DENIED'
call eq d~game(g)~project('Alice')['seats'][2]['prompt'],'ALICE_PRIVATE_PROMPT'
say 'PASS' n 'real Queue Fabric and Wire ingress assertions'
exit 0
eq:
  use arg actual,expected
  n+=1
  if actual\==expected then do
    say 'FAIL' n actual 'expected' expected
    exit 1
  end
return
::requires 'DiplomacyWireSession.cls'
::requires 'ObjectQueueTopics.cls'
