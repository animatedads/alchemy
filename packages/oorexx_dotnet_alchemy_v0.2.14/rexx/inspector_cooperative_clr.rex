/* Exact Inspector Clouseau v0.8.1 public-API torture over a CLR projection. */
use strict arg handle
inspector = .InspectorClouseau~new
opts = .directory~new
opts["write_json"] = .false
opts["write_text"] = .false
inspector~createInspectionReportOnMethod("ALCHEMYDOTNETOBJECT", "SPEAK", opts)

proxy = .AlchemyDotNetObject~new(handle)
/* Simulate Logging already owning the physical wrapper. Inspector must join it. */
proxy~__methodInterpositionAdd("SPEAK", "TEST.LOGGING", .DotNetNoopInterceptor~new, 100)
inspector~addRoot("dotnet", proxy)
ignore = inspector~snapshot

before = proxy~methodInterpositionStatus("SPEAK")
value1 = proxy~speak
generation = proxy~replaceCSharp("C#-INSPECTOR-2")
value2 = proxy~speak
snap2 = inspector~snapshot~asDirectory
events = snap2["trigger_events"]~items
return before["physical_wrappers"] || "|" || before["methods"][1]["provider_count"] || "|" || value1 || "|" || generation || "|" || value2 || "|" || events

::class DotNetNoopInterceptor
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
