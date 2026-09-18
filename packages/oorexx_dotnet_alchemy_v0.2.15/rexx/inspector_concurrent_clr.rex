/* Inspector v0.8.1 stays attached while Rexx and C# publish over a blocked CLR generation. */
use strict arg handle
proxy = .AlchemyDotNetObject~new(handle)
proxy~__methodInterpositionAdd("INVOKESNAPSHOT", "TEST.LOGGING", .ConcurrentNoopInterceptor~new, 100)
inspector = .InspectorClouseau~new
opts = .directory~new
opts["write_json"] = .false
opts["write_text"] = .false
inspector~createInspectionReportOnMethod("ALCHEMYDOTNETOBJECT", "INVOKESNAPSHOT", opts)
inspector~addRoot("dotnet-concurrent", proxy)
ignore = inspector~snapshot
status = proxy~methodInterpositionStatus("INVOKESNAPSHOT")
return status["physical_wrappers"] || "|" || status["methods"][1]["provider_count"]

::class ConcurrentNoopInterceptor
::method before public unguarded
  use strict arg receiver, methodName, arguments
  return "noop"
::method after public unguarded
  use strict arg receiver, methodName, token, result
  return .true
::method failure public unguarded
  use strict arg receiver, methodName, token, conditionObject
  return .true
::requires 'AlchemyDotNetObject.cls'
::requires 'InspectorClouseau.cls'
