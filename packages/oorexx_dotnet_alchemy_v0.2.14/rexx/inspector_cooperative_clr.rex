/* Inspector v0.8.1 / CLR projection cooperative torture.
   Inspector must join the same coordinator and must not replace the projected method twice. */
use strict arg handle
proxy = .AlchemyDotNetObject~new(handle)
before = proxy~methodInterpositionStatus("SPEAK")
inspector = .InspectorClouseau~new
rule = .directory~new
rule~put("SPEAK", "method_name")
ok = inspector~installOneMethodTrigger(proxy, "SPEAK", rule)
if \ok then return "FAIL:INSTALL"
after = proxy~methodInterpositionStatus("SPEAK")
value1 = proxy~speak
generation = proxy~replaceCSharp("C#-INSPECTOR-2")
value2 = proxy~speak
return before~physical_wrappers || "|" || after~physical_wrappers || "|" || after~provider_count || "|" || value1 || "|" || generation || "|" || value2
::requires 'AlchemyDotNetObject.cls'
::requires 'InspectorClouseau.cls'
