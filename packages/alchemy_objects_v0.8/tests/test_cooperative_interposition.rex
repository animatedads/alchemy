/* Dependency-free structural fixture for the cooperative interposition protocol.
 * The real ooRexx Logging v0.3 package is exercised separately by the optional
 * integration runner. */

obj=.CooperativeWidget~new
obj~activateExternalCoordinator
status=obj~methodInterpositionStatus("WORK")
call assertEq 1,status["physical_wrappers"],"external coordinator owns one physical wrapper"
call assertEq 1,status["methods"][1]["provider_count"],"external provider active before Alchemy"

r=obj~instrumentMethod("WORK")
call assertTrue r~ok,"Alchemy joins active coordinator"
call assertEq "TELEMETRY_COORDINATED",r~code,"coordinated install code"
status=obj~methodInterpositionStatus("WORK")
call assertEq 1,status["physical_wrappers"],"still one physical wrapper after Alchemy joins"
call assertEq 2,status["methods"][1]["provider_count"],"two providers share wrapper"

call assertEq "worked:one",obj~work("one"),"business result preserved"
call assertEq 1,obj~methodTelemetry["WORK"]["calls"],"Alchemy observed coordinated call"
call assertEq 1,obj~externalBeforeCount,"external provider before called"
call assertEq 1,obj~externalAfterCount,"external provider after called"

base=obj~alchemyBaseState
call assertTrue base["cooperative_interposition_available"],"base reports cooperative protocol"
call assertEq 1,base["coordinated_instrumentation_count"],"base reports coordinated Alchemy method"
pub=obj~sealPublicIntrospection~payload
mi=pub["method_interposition"]
call assertEq "alchemy.objects.method-interposition/0.1",mi["schema"],"interposition evidence schema"
call assertTrue mi["cooperative_protocol_available"],"snapshot reports protocol"
call assertEq 0,mi["direct_count"],"no direct Alchemy wrapper in external-first case"
call assertEq 1,mi["coordinated_count"],"one coordinated Alchemy provider"
call assertEq 1,mi["coordinator_physical_wrappers"],"one external physical wrapper"

call assertTrue expectForgedCallbackDenied(obj),"forged public callback denied without opaque token"

r=obj~uninstrumentMethod("WORK")
call assertTrue r~ok,"Alchemy provider can withdraw independently"
call assertEq "TELEMETRY_COORDINATED_REMOVED",r~code,"coordinated removal code"
status=obj~methodInterpositionStatus("WORK")
call assertEq 1,status["physical_wrappers"],"external wrapper remains after Alchemy withdrawal"
call assertEq 1,status["methods"][1]["provider_count"],"external provider remains"
call assertEq "worked:two",obj~work("two"),"business method works after Alchemy withdrawal"
call assertEq 1,obj~methodTelemetry["WORK"]["calls"],"Alchemy telemetry no longer advances"
call assertEq 2,obj~externalBeforeCount,"external provider still active"

obj~removeExternalCoordinator
status=obj~methodInterpositionStatus("WORK")
call assertEq 0,status["physical_wrappers"],"last provider release restores original method"
call assertEq "worked:three",obj~work("three"),"plain method restored"

say "PASS test_cooperative_interposition"
exit 0

expectForgedCallbackDenied: procedure
  use strict arg target
  signal on syntax name denied
  ignore=target~__alchemyCooperativeBefore(.directory~new,"WORK",.array~new)
  signal off syntax
  return .false
denied:
  signal off syntax
  return .true

assertTrue: procedure
  use strict arg actual,message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return

assertEq: procedure
  use strict arg expected,actual,message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class CooperativeWidget subclass AlchemyObject
::method init
  expose miProviders miAlias miWrapper miActive externalInterceptor
  ring=.CryptoMacKeyRing~new
  ring~addKey("coop","00112233445566778899aabbccddeeff")
  sealer=.AlchemyMacSealer~new(ring)
  self~init:super(.nil,sealer,.nil)
  self~registerMethodContract("WORK","cooperative interposition fixture",.array~of("VALUE"),"STRING",.false)
  miProviders=.directory~new
  miAlias=""
  miWrapper=.nil
  miActive=.false
  externalInterceptor=.CountingInterceptor~new

::method work unguarded
  use strict arg value
  return "worked:" || value

::method activateExternalCoordinator
  expose miProviders miAlias miWrapper miActive externalInterceptor
  if miActive then return self
  m=self~class~method("WORK")
  miAlias="__TEST_MI_ORIGINAL"
  saved=m~copy
  saved~setPrivate
  self~sendWith(.array~of("SETMETHOD",.Object),.array~of(miAlias,saved,"OBJECT"))
  body=.array~new
  body~append('args=arg(1,"A")')
  body~append('inv=self~__testMiBegin("WORK",args)')
  body~append('signal on any name __testMiFailure')
  body~append('businessResult=self~sendWith("__TEST_MI_ORIGINAL",args)')
  body~append('signal off any')
  body~append('self~__testMiAfter("WORK",inv,businessResult)')
  body~append('return businessResult')
  body~append('__testMiFailure:')
  body~append('c=condition("O")')
  body~append('self~__testMiFailureDispatch("WORK",inv,c)')
  body~append('raise propagate')
  miWrapper=.Method~new("WORK",body)
  miWrapper~setUnguarded
  self~sendWith(.array~of("SETMETHOD",.Object),.array~of("WORK",miWrapper,"OBJECT"))
  miProviders["TEST.EXTERNAL"]=externalInterceptor
  miActive=.true
  return self

::method removeExternalCoordinator
  ignore=self~__methodInterpositionRemove("WORK","TEST.EXTERNAL")
  return self

::method externalBeforeCount
  expose externalInterceptor
  return externalInterceptor~beforeCount

::method externalAfterCount
  expose externalInterceptor
  return externalInterceptor~afterCount

::method __methodInterpositionAdd public
  expose miProviders miActive
  use strict arg methodName,providerId,interceptor,priority=100
  if \miActive then raise syntax 88.900 array("fixture coordinator must be active before provider add")
  if methodName~string~translate \= "WORK" then raise syntax 88.900 array("fixture only coordinates WORK")
  miProviders[providerId~string]=interceptor
  return .true

::method __methodInterpositionRemove public
  expose miProviders miAlias miActive
  use strict arg methodName,providerId
  if \miActive then return .false
  if \miProviders~hasIndex(providerId~string) then return .false
  miProviders~remove(providerId~string)
  if miProviders~items=0 then do
    self~sendWith(.array~of("UNSETMETHOD",.Object),.array~of("WORK"))
    self~sendWith(.array~of("UNSETMETHOD",.Object),.array~of(miAlias))
    miAlias=""
    miActive=.false
  end
  return .true

::method methodInterpositionStatus public
  expose miProviders miActive
  use strict arg methodName=""
  out=.directory~new
  methods=.array~new
  if miActive then do
    rec=.directory~new
    rec["method"]="WORK"
    rec["provider_count"]=miProviders~items
    providers=.array~new
    ids=miProviders~allIndexes
    ids~sort
    do id over ids
      providers~append(id)
    end
    rec["providers"]=providers
    rec["wrapper_integrity"]=.true
    methods~append(rec)
  end
  out["physical_wrappers"]=methods~items
  out["methods"]=methods
  return out

::method __testMiBegin public unguarded
  expose miProviders
  use strict arg methodName,arguments
  activations=.array~new
  ids=miProviders~allIndexes
  ids~sort
  do id over ids
    interceptor=miProviders[id]
    token=interceptor~before(self,methodName,arguments)
    if token \== .nil then activations~append(.array~of(interceptor,token))
  end
  return activations

::method __testMiAfter public unguarded
  use strict arg methodName,activations,result
  do i=activations~items to 1 by -1
    pair=activations[i]
    pair[1]~after(self,methodName,pair[2],result)
  end
  return .true

::method __testMiFailureDispatch public unguarded
  use strict arg methodName,activations,conditionObject
  do i=activations~items to 1 by -1
    pair=activations[i]
    pair[1]~failure(self,methodName,pair[2],conditionObject)
  end
  return .true

::class CountingInterceptor
::attribute beforeCount get
::attribute afterCount get
::attribute failureCount get
::method init
  expose beforeCount afterCount failureCount
  beforeCount=0; afterCount=0; failureCount=0
::method before public unguarded
  expose beforeCount
  use strict arg receiver,methodName,arguments
  beforeCount=beforeCount+1
  return beforeCount
::method after public unguarded
  expose afterCount
  use strict arg receiver,methodName,token,result
  afterCount=afterCount+1
  return .true
::method failure public unguarded
  expose failureCount
  use strict arg receiver,methodName,token,conditionObject
  failureCount=failureCount+1
  return .true

::requires "AlchemyObjects.cls"
