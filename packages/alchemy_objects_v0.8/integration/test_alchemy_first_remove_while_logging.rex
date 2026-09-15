obj=.InteropWidget~new
r=obj~instrumentMethod("WORK")
call assertTrue r~ok,"Alchemy direct telemetry installed first"
call assertEq "TELEMETRY_INSTALLED",r~code,"direct install code"
call assertEq "worked:before",obj~work("before"),"Alchemy direct wrapper works"
call assertEq 1,obj~methodTelemetry["WORK"]["calls"],"Alchemy sees initial call"

service=.LogService~new("alchemy-first-remove")
mem=.LogMemoryTarget~new("memory",.Log~INTERNAL)
service~addTarget(mem)
service~registerMethod(obj,"work",.Log~INTERNAL)
rule=.LogRule~new("outer-logging","interop","InteropWidget","work", -
  .Log~INTERNAL,.Log~INTERNAL,.Log~DEBUG,.LogConditionAlways~new,.array~of("memory"), -
  .array~of(.Log~ENTRY,.Log~EXIT))
service~addRule(rule)

status=obj~methodInterpositionStatus("work")
call assertEq 1,status["physical_wrappers"],"Logging wraps pre-existing Alchemy layer"
call assertTrue status["methods"][1]["had_object_method"],"Logging captured Alchemy object method"

r=obj~uninstrumentMethod("WORK")
call assertTrue \r~ok,"Alchemy refuses unsafe removal below active coordinator"
call assertEq "TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE",r~code,"unsafe release code"
call assertEq "worked:during",obj~work("during"),"both layers still execute"
call assertEq 2,obj~methodTelemetry["WORK"]["calls"],"Alchemy layer preserved"
call assertEq 2,mem~count,"Logging layer preserved"

service~disableRule("outer-logging")
status=obj~methodInterpositionStatus("work")
call assertEq 0,status["physical_wrappers"],"Logging releases outer wrapper"
call assertEq "worked:restored",obj~work("restored"),"Alchemy wrapper restored"
call assertEq 3,obj~methodTelemetry["WORK"]["calls"],"restored Alchemy wrapper active"

r=obj~uninstrumentMethod("WORK")
call assertTrue r~ok,"Alchemy can remove after outer coordinator releases"
call assertEq "TELEMETRY_REMOVED",r~code,"direct removal code"
call assertEq "worked:plain",obj~work("plain"),"plain class method remains"
call assertEq 3,obj~methodTelemetry["WORK"]["calls"],"plain call no longer instrumented"
say "PASS test_alchemy_first_remove_while_logging"
exit 0

assertTrue: procedure
  use strict arg actual,message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected,actual,message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class InteropWidget subclass AlchemyObject inherit LogInstrumentationParticipant
::method init
  self~init:super(.nil,.nil,.nil)
  self~registerMethodContract("WORK","Alchemy first integration",.array~of("VALUE"),"STRING",.false)
::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "AlchemyObject.cls"
::requires "LoggingCore.cls"
