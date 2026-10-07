/*----------------------------------------------------------------------------*/
/* ooRexx Debug Runtime v0.1-dev1                                             */
/* Provider-neutral semantic debugging objects and registered execution       */
/* events. Debugger protocol syntax does not escape the provider boundary.    */
/*----------------------------------------------------------------------------*/

::class DebugRuntimeBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "debug.runtime/0.1"

::class DebugEvents public
::constant SESSION_STARTING "DEBUG.SESSION.STARTING"
::constant SESSION_RUNNING "DEBUG.SESSION.RUNNING"
::constant SESSION_STOPPED "DEBUG.SESSION.STOPPED"
::constant SESSION_EXITED "DEBUG.SESSION.EXITED"
::constant THREAD_STARTED "DEBUG.THREAD.STARTED"
::constant THREAD_EXITED "DEBUG.THREAD.EXITED"
::constant BREAKPOINT_INSTALLED "DEBUG.BREAKPOINT.INSTALLED"
::constant BREAKPOINT_ENABLED "DEBUG.BREAKPOINT.ENABLED"
::constant BREAKPOINT_DISABLED "DEBUG.BREAKPOINT.DISABLED"
::constant BREAKPOINT_HIT "DEBUG.BREAKPOINT.HIT"
::constant STEP_COMPLETED "DEBUG.STEP.COMPLETED"
::constant SIGNAL_RECEIVED "DEBUG.SIGNAL.RECEIVED"
::constant EXCEPTION_RAISED "DEBUG.EXCEPTION.RAISED"
::constant MODULE_LOADED "DEBUG.MODULE.LOADED"
::constant MODULE_UNLOADED "DEBUG.MODULE.UNLOADED"
::constant CONTROL_REQUESTED "DEBUG.CONTROL.REQUESTED"
::constant PROVIDER_ERROR "DEBUG.PROVIDER.ERROR"

::class DebugProviderEvents public
::constant RUNNING "RUNNING"
::constant STOPPED "STOPPED"
::constant EXITED "EXITED"
::constant THREAD_STARTED "THREAD_STARTED"
::constant THREAD_EXITED "THREAD_EXITED"
::constant BREAKPOINT_INSTALLED "BREAKPOINT_INSTALLED"
::constant BREAKPOINT_ENABLED "BREAKPOINT_ENABLED"
::constant BREAKPOINT_DISABLED "BREAKPOINT_DISABLED"
::constant BREAKPOINT_HIT "BREAKPOINT_HIT"
::constant STEP_COMPLETED "STEP_COMPLETED"
::constant SIGNAL_RECEIVED "SIGNAL_RECEIVED"
::constant EXCEPTION_RAISED "EXCEPTION_RAISED"
::constant MODULE_LOADED "MODULE_LOADED"
::constant MODULE_UNLOADED "MODULE_UNLOADED"
::constant FRAME_SNAPSHOT "FRAME_SNAPSHOT"
::constant ERROR "ERROR"

::class DebugTarget public
::attribute targetId get
::attribute kind get
::attribute displayName get
::attribute metadata get
::attribute capabilities get

::method init
  expose targetId kind displayName metadata capabilities
  use strict arg targetIdArg,kindArg='PROCESS',displayNameArg='',metadataArg=.nil,capabilitiesArg=.nil
  targetId=targetIdArg~string
  kind=kindArg~string~upper
  displayName=displayNameArg~string
  if displayName=='' then displayName=targetId
  if metadataArg==.nil then metadata=.directory~new; else metadata=metadataArg~copy
  capabilities=.directory~new
  if capabilitiesArg<>.nil then do c over capabilitiesArg; capabilities[c~string~upper]=.true; end

::method hasCapability
  expose capabilities
  use strict arg capability
  return capabilities~hasIndex(capability~string~upper)

::method metadataValue
  expose metadata
  use strict arg name,default=.nil
  if metadata~hasIndex(name) then return metadata[name]
  return default

::class DebugLocation public
::attribute functionName get
::attribute sourceFile get
::attribute line get
::attribute column get
::attribute address get

::method init
  expose functionName sourceFile line column address
  use strict arg functionArg='',sourceArg='',lineArg=0,columnArg=0,addressArg=''
  functionName=functionArg~string; sourceFile=sourceArg~string
  line=lineArg+0; column=columnArg+0; address=addressArg~string

::method string
  expose functionName sourceFile line address
  s=''
  if functionName<>'' then s=functionName
  if sourceFile<>'' then do
    if s<>'' then s=s||' @ '
    s=s||sourceFile
    if line>0 then s=s||':'||line
  end
  if s=='' & address<>'' then s=address
  return s

::class DebugBreakpointSpec public
::attribute kind get
::attribute location get
::attribute condition get
::attribute expression get
::attribute metadata get

::method init
  expose kind location condition expression metadata
  use strict arg kindArg,locationArg=.nil,conditionArg='',expressionArg='',metadataArg=.nil
  kind=kindArg~string~upper
  if locationArg==.nil then location=.DebugLocation~new; else location=locationArg
  condition=conditionArg~string; expression=expressionArg~string
  if metadataArg==.nil then metadata=.directory~new; else metadata=metadataArg~copy

::method where
  expose kind location condition expression metadata
  use strict arg predicate
  return .DebugBreakpointSpec~new(kind,location,predicate~string,expression,metadata)

::class Execution public
::method enters class
  use strict arg functionName
  return .DebugBreakpointSpec~new('FUNCTION',.DebugLocation~new(functionName))

::method at class
  use strict arg sourceFile,line,column=0
  return .DebugBreakpointSpec~new('SOURCE',.DebugLocation~new('',sourceFile,line,column))

::method address class
  use strict arg address
  return .DebugBreakpointSpec~new('ADDRESS',.DebugLocation~new('','',0,0,address))

::method changes class
  use strict arg expression
  return .DebugBreakpointSpec~new('DATA',.nil,'',expression)

::class DebugValue public
::attribute name get
::attribute typeName get
::attribute value get
::attribute valueId get
::attribute children get
::attribute writable get

::method init
  expose name typeName value valueId children writable
  use strict arg nameArg,typeArg='',valueArg=.nil,valueIdArg='',childrenArg=.nil,writableArg=.false
  name=nameArg~string; typeName=typeArg~string; value=valueArg; valueId=valueIdArg~string
  if childrenArg==.nil then children=.directory~new; else children=childrenArg
  writable=writableArg

::method child
  expose children
  use strict arg childName
  key=childName~string~upper
  if children~hasIndex(key) then return children[key]
  return .nil

::method unknown
  expose children
  use strict arg messageName,args
  if args~items==0 then do
    key=messageName~string~upper
    if children~hasIndex(key) then return children[key]
  end
  return .nil

::method copyDetached
  expose name typeName value valueId children writable
  c=.directory~new
  do n over children
    item=children[n]
    if item<>.nil & item~hasMethod('COPYDETACHED') then c[n]=item~copyDetached
    else c[n]=item
  end
  return .DebugValue~new(name,typeName,value,valueId,c,writable)

::class DebugScope public
::attribute name get
::attribute values get

::method init
  expose name values
  use strict arg nameArg,valuesArg=.nil
  name=nameArg~string
  if valuesArg==.nil then values=.directory~new; else values=valuesArg

::method put
  expose values
  use strict arg valueObject
  values[valueObject~name~upper]=valueObject
  return valueObject

::method at
  expose values
  use strict arg variableName
  key=variableName~string~upper
  if values~hasIndex(key) then return values[key]
  return .nil

::method unknown
  expose values
  use strict arg messageName,args
  key=messageName~string~upper
  if args~items==0 & values~hasIndex(key) then return values[key]
  return .nil

::class DebugFrame public
::attribute frameId get
::attribute level get
::attribute location get
::attribute locals get
::attribute arguments get
::attribute statics get
::attribute language get

::method init
  expose frameId level location locals arguments statics language
  use strict arg frameIdArg,levelArg=0,locationArg=.nil,languageArg=''
  frameId=frameIdArg~string; level=levelArg+0
  if locationArg==.nil then location=.DebugLocation~new; else location=locationArg
  language=languageArg~string
  locals=.DebugScope~new('locals'); arguments=.DebugScope~new('arguments'); statics=.DebugScope~new('statics')

::method function
  expose location
  return location~functionName
::method source
  expose location
  return location~sourceFile
::method line
  expose location
  return location~line

::class DebugThread public
::attribute threadId get
::attribute name get
::attribute state get
::attribute frames get

::method init
  expose threadId name state frames
  use strict arg threadIdArg,nameArg='',stateArg='UNKNOWN'
  threadId=threadIdArg~string; name=nameArg~string; state=stateArg~string~upper
  frames=.array~new

::method replaceFrames guarded
  expose frames
  use strict arg newFrames
  frames=.array~new; do f over newFrames; frames~append(f); end
  return self

::method topFrame guarded
  expose frames
  if frames~items==0 then return .nil
  return frames[1]

::method setState guarded
  expose state
  use strict arg newState
  state=newState~string~upper
  return self

::class DebugBreakpoint public subclass EventSource
::attribute session get
::attribute breakpointId get
::attribute providerId get
::attribute spec get
::attribute observedEnabled get
::attribute hitCount get
::attribute installed get

::method init
  expose session breakpointId providerId spec observedEnabled hitCount installed
  use strict arg sessionArg,idArg,specArg
  self~init:super('debug:breakpoint:'||idArg)
  session=sessionArg; breakpointId=idArg~string; providerId=''; spec=specArg
  observedEnabled=.false; hitCount=0; installed=.false

::method requestEnable
  expose session
  return session~provider~setBreakpointEnabled(session,self,.true)

::method requestDisable
  expose session
  return session~provider~setBreakpointEnabled(session,self,.false)

::method remove
  expose session
  return session~provider~removeBreakpoint(session,self)

::method observeInstalled guarded
  expose providerId installed observedEnabled
  use strict arg providerIdArg,enabledArg=.true
  providerId=providerIdArg~string; installed=.true; observedEnabled=enabledArg
  guard off
  self~emit(.DebugEvents~BREAKPOINT_INSTALLED,self)
  return self

::method observeEnabled guarded
  expose observedEnabled
  use strict arg enabledArg
  old=observedEnabled; observedEnabled=enabledArg
  guard off
  if old<>observedEnabled then do
    if observedEnabled then self~emit(.DebugEvents~BREAKPOINT_ENABLED,self)
    else self~emit(.DebugEvents~BREAKPOINT_DISABLED,self)
  end
  return self

::method observeHit guarded
  expose hitCount
  use strict arg data=.nil
  hitCount+=1
  guard off
  if data==.nil then data=self
  self~emit(.DebugEvents~BREAKPOINT_HIT,data)
  return self

::class DebugProviderEvent public
::attribute type get
::attribute data get
::attribute providerEventId get
::attribute occurredAt get

::method init
  expose type data providerEventId occurredAt
  use strict arg typeArg,dataArg=.nil,idArg='',occurredAtArg=''
  type=typeArg~string~upper; data=dataArg; providerEventId=idArg~string
  occurredAt=occurredAtArg~string
  if occurredAt=='' then occurredAt=date('S')||'T'||time('L')

::class DebugExecutionBinding public
::method init
  expose session spec
  use strict arg sessionArg,specArg
  session=sessionArg; spec=specArg

::method notify
  expose session spec
  use strict arg target,messageName,delivery='SYNC'
  bp=session~breakpoint(spec)
  return bp~on(.DebugEvents~BREAKPOINT_HIT,target,messageName,delivery)

::method fire
  expose session spec
  use strict arg target,messageName,delivery='ASYNC'
  bp=session~breakpoint(spec)
  return bp~on(.DebugEvents~BREAKPOINT_HIT,target,messageName,delivery)

::class DebugSession public subclass EventSource
::attribute sessionId get
::attribute provider get
::attribute target get
::attribute state get
::attribute threads get
::attribute breakpoints get
::attribute exitCode get
::attribute currentThread get
::attribute currentFrame get

::method init
  expose sessionId provider target state threads breakpoints nextBreakpoint exitCode currentThread currentFrame
  use strict arg sessionIdArg,providerArg,targetArg
  self~init:super('debug:session:'||sessionIdArg)
  sessionId=sessionIdArg~string; provider=providerArg; target=targetArg
  state='NEW'; threads=.directory~new; breakpoints=.directory~new; nextBreakpoint=1
  exitCode=.nil; currentThread=.nil; currentFrame=.nil

::method start
  expose provider
  return provider~start(self)

::method when
  expose dispatcher
  use strict arg interest
  if interest~isA(.DebugBreakpointSpec) then return .DebugExecutionBinding~new(self,interest)
  return self~init:super(interest)

::method breakpoint guarded
  expose provider breakpoints nextBreakpoint
  use strict arg spec
  id='BP-'||nextBreakpoint; nextBreakpoint+=1
  bp=.DebugBreakpoint~new(self,id,spec); breakpoints[id]=bp
  guard off
  provider~installBreakpoint(self,bp)
  return bp

::method breakpointByProviderId guarded
  expose breakpoints
  use strict arg providerId
  do id over breakpoints
    bp=breakpoints[id]
    if bp~providerId==providerId~string then return bp
  end
  return .nil

::method run
  return self~requestControl('RUN')
::method continue
  return self~requestControl('CONTINUE')
::method pause
  return self~requestControl('PAUSE')
::method stepInto
  return self~requestControl('STEP_INTO')
::method stepOver
  return self~requestControl('STEP_OVER')
::method stepOut
  return self~requestControl('STEP_OUT')

::method requestControl
  expose provider
  use strict arg operation
  d=.directory~new; d['operation']=operation
  self~emit(.DebugEvents~CONTROL_REQUESTED,d)
  return provider~control(self,operation)

::method thread guarded
  expose threads
  use strict arg threadId
  if threads~hasIndex(threadId~string) then return threads[threadId~string]
  return .nil

::method acceptProviderEvent guarded
  expose state threads breakpoints exitCode currentThread currentFrame
  use strict arg event
  t=event~type; data=event~data
  select
    when t==.DebugProviderEvents~RUNNING then do
      state='RUNNING'
      do id over threads; threads[id]~setState('RUNNING'); end
      guard off; self~emit(.DebugEvents~SESSION_RUNNING,data)
    end
    when t==.DebugProviderEvents~STOPPED then do
      state='STOPPED'
      if data<>.nil & data~isA(.directory) then do
        if data~hasIndex('threadId') then currentThread=self~thread(data['threadId'])
        if data~hasIndex('frame') then currentFrame=data['frame']
      end
      guard off; self~emit(.DebugEvents~SESSION_STOPPED,data)
    end
    when t==.DebugProviderEvents~EXITED then do
      state='EXITED'; if data<>.nil then exitCode=data
      guard off; self~emit(.DebugEvents~SESSION_EXITED,data)
    end
    when t==.DebugProviderEvents~THREAD_STARTED then do
      if data~isA(.DebugThread) then thread=data
      else thread=.DebugThread~new(data~string)
      threads[thread~threadId]=thread
      guard off; self~emit(.DebugEvents~THREAD_STARTED,thread)
    end
    when t==.DebugProviderEvents~THREAD_EXITED then do
      id=data~string
      thread=.nil; if threads~hasIndex(id) then do; thread=threads[id]; threads~remove(id); end
      guard off; self~emit(.DebugEvents~THREAD_EXITED,thread)
    end
    when t==.DebugProviderEvents~BREAKPOINT_INSTALLED then do
      bp=data['breakpoint']; bp~observeInstalled(data['providerId'],data['enabled'])
      guard off; self~emit(.DebugEvents~BREAKPOINT_INSTALLED,bp)
    end
    when t==.DebugProviderEvents~BREAKPOINT_ENABLED then do
      bp=self~breakpointByProviderId(data['providerId']); guard off
      if bp<>.nil then bp~observeEnabled(.true)
    end
    when t==.DebugProviderEvents~BREAKPOINT_DISABLED then do
      bp=self~breakpointByProviderId(data['providerId']); guard off
      if bp<>.nil then bp~observeEnabled(.false)
    end
    when t==.DebugProviderEvents~BREAKPOINT_HIT then do
      providerId=data['providerId']; bp=self~breakpointByProviderId(providerId)
      state='STOPPED'
      if data~hasIndex('threadId') then currentThread=self~thread(data['threadId'])
      if data~hasIndex('frame') then currentFrame=data['frame']
      guard off
      if bp<>.nil then bp~observeHit(data)
      self~emit(.DebugEvents~BREAKPOINT_HIT,data)
      self~emit(.DebugEvents~SESSION_STOPPED,data)
    end
    when t==.DebugProviderEvents~STEP_COMPLETED then do
      state='STOPPED'; guard off
      self~emit(.DebugEvents~STEP_COMPLETED,data); self~emit(.DebugEvents~SESSION_STOPPED,data)
    end
    when t==.DebugProviderEvents~SIGNAL_RECEIVED then do
      state='STOPPED'; guard off
      self~emit(.DebugEvents~SIGNAL_RECEIVED,data); self~emit(.DebugEvents~SESSION_STOPPED,data)
    end
    when t==.DebugProviderEvents~EXCEPTION_RAISED then do
      state='STOPPED'; guard off
      self~emit(.DebugEvents~EXCEPTION_RAISED,data); self~emit(.DebugEvents~SESSION_STOPPED,data)
    end
    when t==.DebugProviderEvents~FRAME_SNAPSHOT then do
      threadId=data['threadId']; frames=data['frames']
      if 	hreads~hasIndex(threadId) then threads[threadId]=.DebugThread~new(threadId)
      threads[threadId]~replaceFrames(frames)
      if frames~items>0 then currentFrame=frames[1]
      currentThread=threads[threadId]
      guard off
    end
    when t==.DebugProviderEvents~MODULE_LOADED then do
      guard off; self~emit(.DebugEvents~MODULE_LOADED,data)
    end
    when t==.DebugProviderEvents~MODULE_UNLOADED then do
      guard off; self~emit(.DebugEvents~MODULE_UNLOADED,data)
    end
    otherwise do
      guard off; self~emit(.DebugEvents~PROVIDER_ERROR,event)
    end
  end
  return self

::class DebugProvider public
::method name
  return 'ABSTRACT'
::method supports
  use strict arg target
  return .false
::method start
  use strict arg session
  raise syntax 93.900 array('DebugProvider.start() not implemented',self~name)
::method installBreakpoint
  use strict arg session,breakpoint
  raise syntax 93.900 array('DebugProvider.installBreakpoint() not implemented',self~name)
::method setBreakpointEnabled
  use strict arg session,breakpoint,enabled
  raise syntax 93.900 array('DebugProvider.setBreakpointEnabled() not implemented',self~name)
::method removeBreakpoint
  use strict arg session,breakpoint
  raise syntax 93.900 array('DebugProvider.removeBreakpoint() not implemented',self~name)
::method control
  use strict arg session,operation
  raise syntax 93.900 array('DebugProvider.control() not implemented',self~name)

::class DebugProviderRegistry public
::method init
  expose providers
  providers=.array~new
::method register
  expose providers
  use strict arg provider
  providers~append(provider); return provider
::method resolve
  expose providers
  use strict arg target
  do p over providers
    if p~supports(target) then return p
  end
  return .nil

::class DebugRuntime public
::method init
  expose registry nextSession
  use strict arg registryArg=.nil
  if registryArg==.nil then registry=.DebugProviderRegistry~new; else registry=registryArg
  nextSession=1
::method providers
  expose registry
  return registry
::method attach
  expose registry nextSession
  use strict arg target
  p=registry~resolve(target)
  if p==.nil then raise syntax 93.900 array('No debug provider supports target',target~targetId)
  s=.DebugSession~new(nextSession,p,target); nextSession+=1; s~start; return s

::class DebugMemoryProvider public subclass DebugProvider
::attribute controls get
::attribute installed get
::method init
  expose controls installed nextProviderId
  controls=.array~new; installed=.directory~new; nextProviderId=1
::method name
  return 'MEMORY'
::method supports
  use strict arg target
  return target~hasCapability('DEBUG.MEMORY')
::method start
  use strict arg session
  session~acceptProviderEvent(.DebugProviderEvent~new(.DebugProviderEvents~RUNNING))
  return .true
::method installBreakpoint
  expose installed nextProviderId
  use strict arg session,bp
  id='MEM-'||nextProviderId; nextProviderId+=1; installed[id]=bp
  d=.directory~new; d['breakpoint']=bp; d['providerId']=id; d['enabled']=.true
  session~acceptProviderEvent(.DebugProviderEvent~new(.DebugProviderEvents~BREAKPOINT_INSTALLED,d))
  return id
::method setBreakpointEnabled
  use strict arg session,bp,enabled
  d=.directory~new; d['providerId']=bp~providerId
  if enabled then t=.DebugProviderEvents~BREAKPOINT_ENABLED; else t=.DebugProviderEvents~BREAKPOINT_DISABLED
  session~acceptProviderEvent(.DebugProviderEvent~new(t,d)); return .true
::method removeBreakpoint
  expose installed
  use strict arg session,bp
  if installed~hasIndex(bp~providerId) then installed~remove(bp~providerId)
  return .true
::method control
  expose controls
  use strict arg session,operation
  controls~append(operation)
  return .true
::method simulateThread
  use strict arg session,id,name=''
  session~acceptProviderEvent(.DebugProviderEvent~new(.DebugProviderEvents~THREAD_STARTED,.DebugThread~new(id,name,'STOPPED')))
::method simulateBreakpointHit
  use strict arg session,bp,threadId='1',frame=.nil
  d=.directory~new; d['providerId']=bp~providerId; d['threadId']=threadId
  if frame<>.nil then d['frame']=frame
  session~acceptProviderEvent(.DebugProviderEvent~new(.DebugProviderEvents~BREAKPOINT_HIT,d))

::requires "EventRuntime.cls"
