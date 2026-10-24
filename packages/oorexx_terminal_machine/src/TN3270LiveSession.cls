/*
 * Long-lived TN3270/TN3270E live session.
 *
 * Candidate10 keeps the original direct API for unclaimed sessions and adds
 * the exact-object lifecycle boundary required by TerminalSessionOwner.  Once
 * claimed, network/lifecycle operations require the owner's private token;
 * observers receive a snapshot-only facade and mutation passes through the
 * existing TerminalControlGate.
 */
::class TN3270LiveState public
::constant CREATED "CREATED"
::constant OPEN "OPEN"
::constant REMOTE_CLOSED "REMOTE_CLOSED"
::constant ERROR "ERROR"
::constant CLOSED "CLOSED"

::class TN3270LivePumpResult public
::attribute activity get
::attribute state get
::attribute snapshot get
::method init
  expose activity state snapshot
  use arg activityArg=.false, stateArg="", snapshotArg=.nil
  activity=activityArg==.true; state=stateArg~string
  if snapshotArg==.nil then snapshot=.nil; else snapshot=snapshotArg~copyDetached

::class TN3270ObserverPort public
::method init
  expose session
  use strict arg session
::method snapshot
  expose session
  return session~snapshot
::method knownStateStatus
  expose session
  return session~knownStateStatus
::method knownStateId
  expose session
  return session~knownStateId
::method knownStateGeneration
  expose session
  return session~knownStateGeneration
::method knownStateHistory
  expose session
  return session~knownStateHistory

::class TN3270MutationPort public
::method init
  expose session token
  use strict arg session, token
::method snapshot
  expose session
  return session~snapshot
::method setField
  expose session token
  use arg generation, fieldId, value, controller=""
  return session~controlledSetField(token,generation,fieldId,value)
::method typeAtCursor
  expose session token
  use arg generation, text, controller=""
  return session~controlledTypeAtCursor(token,generation,text)
::method moveCursor
  expose session token
  use arg generation,row,column,controller=""
  return session~controlledMoveCursor(token,generation,row,column)
::method focusField
  expose session token
  use arg generation,fieldId,controller=""
  return session~controlledFocusField(token,generation,fieldId)
::method nextInputField
  expose session token
  use arg generation,controller=""
  return session~controlledNavigate(token,generation,1)
::method previousInputField
  expose session token
  use arg generation,controller=""
  return session~controlledNavigate(token,generation,-1)
::method home
  expose session token
  use arg generation,controller=""
  return session~controlledHome(token,generation)
::method errorReset
  expose session token
  use arg generation,controller=""
  return session~controlledReset(token,generation)
::method press
  expose session token
  use arg generation,aidName,controller=""
  return session~controlledPress(token,generation,aidName)
::method systemRequest
  return .TerminalResult~failure("3270_SYSREQ_UNSUPPORTED","TN3270E SYSREQ is not negotiated")

::class TN3270LiveSession public
::attribute sessionId get
::attribute state get
::attribute transport get
::attribute wire get
::attribute ownershipClaimed get

::method init
  expose sessionId state transport wire ownershipOwner ownershipClaimed observerPort controlGate mutationToken knownStateTracker
  use arg transportArg, wireArg=.nil, sessionIdArg="TN3270"
  sessionId=sessionIdArg~string~strip
  if sessionId=="" then sessionId="TN3270"
  transport=transportArg
  if wireArg==.nil then wire=.TN3270Wire~new; else wire=wireArg
  state=.TN3270LiveState~CREATED
  ownershipOwner=.nil; ownershipClaimed=.false
  observerPort=.TN3270ObserverPort~new(self)
  mutationToken=.Object~new
  controlGate=.nil; knownStateTracker=.nil

::method validateOwner private
  expose ownershipOwner
  use arg ownerArg=.nil
  if ownershipOwner==.nil then return .TerminalResult~success(.true)
  if ownerArg==ownershipOwner then return .TerminalResult~success(.true)
  return .TerminalResult~failure("SESSION_OWNERSHIP_REQUIRED","exact owner capability required")

::method claimExclusiveOwner
  expose ownershipOwner ownershipClaimed state
  use arg ownerArg
  if ownerArg==.nil then return .TerminalResult~failure("SESSION_OWNERSHIP_OWNER_REQUIRED")
  if state==.TN3270LiveState~CLOSED then return .TerminalResult~failure("SESSION_OWNERSHIP_CLOSED")
  if ownershipOwner==.nil then do; ownershipOwner=ownerArg; ownershipClaimed=.true; return .TerminalResult~success(.true); end
  if ownershipOwner==ownerArg then return .TerminalResult~success(.true)
  return .TerminalResult~failure("SESSION_OWNERSHIP_BUSY")

::method releaseExclusiveOwner
  expose ownershipOwner ownershipClaimed state controlGate
  use arg ownerArg
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if state==.TN3270LiveState~CLOSED then return .TerminalResult~failure("SESSION_OWNERSHIP_STILL_OPEN")
  if controlGate==.nil then if controlGate~active then return .TerminalResult~failure("SESSION_OWNERSHIP_CONTROL_ACTIVE")
  ownershipOwner=.nil; ownershipClaimed=.false
  return .TerminalResult~success(.true)

::method observerPort
  expose observerPort
  return observerPort

::method open
  expose transport state
  use arg ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if state==.TN3270LiveState~OPEN then return .TerminalResult~success(.true)
  opened=transport~open
  if opened~ok then do; state=.TN3270LiveState~ERROR; return opened; end
  state=.TN3270LiveState~OPEN
  return .TerminalResult~success(.true)

::method snapshot
  expose wire state
  projected=.TN3270Snapshot~fromWire(wire,state)
  if projected~ok then return .nil
  return projected~value~copyDetached

::method attachKnownStateCatalog
  expose knownStateTracker
  use arg catalogArg, capacityArg=64, ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if knownStateTracker==.nil then return .TerminalResult~failure("KNOWN_STATE_TRACKER_EXISTS")
  knownStateTracker=.TerminalKnownStateTracker~new(catalogArg,capacityArg)
  knownStateTracker~observe(self~snapshot)
  return .TerminalResult~success(.true)

::method refreshKnownState private
  expose knownStateTracker
  if knownStateTracker==.nil then knownStateTracker~observe(self~snapshot)
::method knownStateStatus
  expose knownStateTracker
  if knownStateTracker==.nil then return "UNTRACKED"
  return knownStateTracker~currentStatus
::method knownStateId
  expose knownStateTracker
  if knownStateTracker==.nil then return ""
  return knownStateTracker~currentStateId
::method knownStateGeneration
  expose knownStateTracker
  if knownStateTracker==.nil then return 0
  return knownStateTracker~currentGeneration
::method knownStateHistory
  expose knownStateTracker
  if knownStateTracker==.nil then return .array~new
  return knownStateTracker~history

::method enableControlGate
  expose sessionId controlGate mutationToken
  use arg authorityArg, scopeArg="", ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if controlGate==.nil then return .TerminalResult~success(.true)
  scope=scopeArg~string~strip
  if scope=="" then scope="TERMINAL:SESSION:"||sessionId
  controlGate=.TerminalControlGate~new(sessionId,scope,.TN3270MutationPort~new(self,mutationToken),authorityArg,.nil,.nil,"TN3270")
  return .TerminalResult~success(.true)
::method acquireControl
  expose controlGate
  use arg identity,reservation,capabilities=.nil,ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if controlGate==.nil then return .TerminalResult~failure("CONTROL_GATE_NOT_ENABLED")
  return controlGate~acquire(identity,reservation,capabilities)
::method revokeControl
  expose controlGate
  use arg reason="TRUSTED_OWNER_REVOKE",ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if controlGate==.nil then return .TerminalResult~failure("CONTROL_GATE_NOT_ENABLED")
  return controlGate~revoke(reason)
::method controlActive
  expose controlGate
  if controlGate==.nil then return .false
  return controlGate~active
::method activeControllerIdentity
  expose controlGate
  if controlGate==.nil then return ""
  return controlGate~activeControllerIdentity
::method activeControlLeaseId
  expose controlGate
  if controlGate==.nil then return ""
  return controlGate~activeLeaseId

::method pumpOnce
  expose transport wire state controlGate
  use arg timeoutSeconds=1, maximumBytes=16384, ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if state==.TN3270LiveState~OPEN then return .TerminalResult~failure("TN3270_LIVE_NOT_OPEN",state)
  before=wire~model~generation
  ready=transport~waitReadable(timeoutSeconds)
  if eady~ok then return ready
  if eady~value then return .TerminalResult~success(.TN3270LivePumpResult~new(.false,state,self~snapshot))
  got=transport~receiveBytes(maximumBytes)
  if got~ok then do; state=.TN3270LiveState~ERROR; return got; end
  if got~value~length==0 then do
    state=.TN3270LiveState~REMOTE_CLOSED
    if controlGate==.nil then if controlGate~active then ignore=controlGate~revoke("SESSION_REMOTE_CLOSED")
    ignore=transport~close
    return .TerminalResult~success(.TN3270LivePumpResult~new(.true,state,self~snapshot))
  end
  wire~feed(got~value)
  outbound=wire~drainOutbound
  if outbound~length>0 then do; sent=transport~sendBytes(outbound); if sent~ok then do; state=.TN3270LiveState~ERROR; return sent; end; end
  after=wire~model~generation
  if after>before then do
    self~refreshKnownState
    if controlGate==.nil then if controlGate~active then ignore=controlGate~recordHostScreenUpdate(after-before)
  end
  return .TerminalResult~success(.TN3270LivePumpResult~new(.true,state,self~snapshot))

::method pumpUntilGeneration
  expose wire
  use arg afterGeneration, timeoutSeconds=10, ownerArg=.nil
  started=time('E')
  do while wire~model~generation<=afterGeneration
    remaining=timeoutSeconds-(time('E')-started)
    if remaining<=0 then return .TerminalResult~failure("TN3270_STATE_TIMEOUT",timeoutSeconds)
    one=self~pumpOnce(remaining,16384,ownerArg)
    if one~ok then return one
    if one~value~activity then return .TerminalResult~failure("TN3270_STATE_TIMEOUT",timeoutSeconds)
  end
  return .TerminalResult~success(wire~model~generation)

/* Legacy direct mutation API remains available only while unclaimed. */
::method directAllowed private
  expose ownershipClaimed
  if ownershipClaimed then return .TerminalResult~failure("SESSION_OWNERSHIP_REQUIRED")
  return .TerminalResult~success(.true)
::method setCursorPosition
  expose wire
  use arg row,column
  ok=self~directAllowed; if ok~ok then return ok
  return wire~model~setCursorPosition(row,column)
::method setInputTextAt
  expose wire
  use arg row,column,text
  ok=self~directAllowed; if ok~ok then return ok
  return wire~model~setInputTextAt(row,column,text,wire~stream~codepage)
::method setInputTextAtCursor
  expose wire
  use arg text
  ok=self~directAllowed; if ok~ok then return ok
  return wire~model~setInputTextAtCursor(text,wire~stream~codepage)

::method validateMutationToken private
  expose mutationToken
  use arg token,generation
  if token==mutationToken then return .TerminalResult~failure("3270_MUTATION_AUTHORITY_INVALID")
  snap=self~snapshot
  if generation==snap~generation then return .TerminalResult~failure("STALE_SCREEN","expected generation "||generation||", actual "||snap~generation)
  return .TerminalResult~success(.true)
::method fieldFromId private
  expose wire
  use arg fieldId
  id=fieldId~string~strip~upper
  if left(id,1)=="A" then return .nil
  hex=substr(id,2)
  if hex=="" | verify(hex,"0123456789ABCDEF")<>0 then return .nil
  address=x2d(hex)
  return wire~model~fieldStartingAt(address)
::method controlledSetField
  expose wire
  use arg token,generation,fieldId,value
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  f=self~fieldFromId(fieldId); if f==.nil then return .TerminalResult~failure("3270_FIELD_NOT_FOUND",fieldId)
  return wire~model~setFieldText(f,value,wire~stream~codepage)
::method controlledTypeAtCursor
  expose wire
  use arg token,generation,text
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  return wire~model~setInputTextAtCursor(text,wire~stream~codepage)
::method controlledMoveCursor
  expose wire
  use arg token,generation,row,column
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  return wire~model~setCursorPosition(row,column)
::method controlledFocusField
  expose wire
  use arg token,generation,fieldId
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  f=self~fieldFromId(fieldId); if f==.nil then return .TerminalResult~failure("3270_FIELD_NOT_FOUND",fieldId)
  if f~protected then return .TerminalResult~failure("3270_PROTECTED_FIELD",fieldId)
  a=(f~address+1)//wire~model~size
  return wire~model~setCursorPosition(wire~model~rowForAddress(a),wire~model~columnForAddress(a))
::method controlledNavigate
  expose wire
  use arg token,generation,direction
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  fields=wire~model~inputFields
  if fields~items==0 then return .TerminalResult~failure("3270_NO_INPUT_FIELDS")
  current=wire~model~cursor; chosen=0; best=wire~model~size+1
  do i=1 to fields~items
    a=(fields[i]~address+1)//wire~model~size
    if direction>=0 then d=(a-current+wire~model~size)//wire~model~size
    else d=(current-a+wire~model~size)//wire~model~size
    if d==0 then d=wire~model~size
    if d<best then do; best=d; chosen=i; end
  end
  a=(fields[chosen]~address+1)//wire~model~size
  return wire~model~setCursorPosition(wire~model~rowForAddress(a),wire~model~columnForAddress(a))
::method controlledHome
  expose wire
  use arg token,generation
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  fields=wire~model~inputFields
  if fields~items==0 then return .TerminalResult~failure("3270_NO_INPUT_FIELDS")
  a=(fields[1]~address+1)//wire~model~size
  return wire~model~setCursorPosition(wire~model~rowForAddress(a),wire~model~columnForAddress(a))
::method controlledReset
  expose wire
  use arg token,generation
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  wire~model~keyboardLocked=.false
  return .TerminalResult~success(.true)
::method controlledPress
  expose wire transport
  use arg token,generation,aidName
  checked=self~validateMutationToken(token,generation); if checked~ok then return checked
  name=aidName~string~strip~upper
  aid=.Aid3270~send(name)
  if aid==.nil then return .TerminalResult~failure("3270_BAD_AID",name)
  payload=wire~stream~buildReadModified(aid)
  return transport~sendBytes(wire~frameInput(payload))

::method sendAidAndAwait
  expose transport wire
  use arg aid="7D"x, timeoutSeconds=10
  ok=self~directAllowed; if ok~ok then return ok
  before=wire~model~generation
  payload=wire~stream~buildReadModified(aid)
  sent=transport~sendBytes(wire~frameInput(payload)); if sent~ok then return sent
  return self~pumpUntilGeneration(before,timeoutSeconds)
::method enterAndAwait
  use arg timeoutSeconds=10
  return self~sendAidAndAwait(.Aid3270~ENTER,timeoutSeconds)
::method pfAndAwait
  use arg number,timeoutSeconds=10
  if number<1 | number>24 then return .TerminalResult~failure("3270_BAD_PF",number)
  return self~sendAidAndAwait(.Aid3270~send("PF"||number),timeoutSeconds)
::method awaitText
  expose wire
  use arg needle,timeoutSeconds=10
  ok=self~directAllowed; if ok~ok then return ok
  started=time('E')
  do forever
    if wire~model~text(wire~stream~codepage)~pos(needle)>0 then return .TerminalResult~success(wire~model~generation)
    remaining=timeoutSeconds-(time('E')-started)
    if remaining<=0 then return .TerminalResult~failure("TN3270_STATE_TIMEOUT",timeoutSeconds)
    r=self~pumpUntilGeneration(wire~model~generation,remaining)
    if ~ok then return r
  end
::method close
  expose transport state controlGate
  use arg ownerArg=.nil
  checked=self~validateOwner(ownerArg); if checked~ok then return checked
  if controlGate==.nil then if controlGate~active then ignore=controlGate~revoke("SESSION_CLOSED")
  closed=transport~close
  state=.TN3270LiveState~CLOSED
  return closed

::requires "TN3270Wire.cls"
::requires "TN3270Snapshot.cls"
::requires "TerminalTransport.cls"
::requires "TerminalControl.cls"
