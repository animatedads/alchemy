/* Rexx override must reveal the current CLR target when removed, never a saved stale target. */
use strict arg handle
proxy = .AlchemyDotNetObject~new(handle)
override = .RexxSpeakOverride~new
proxy~installRexxMemberOverride("SPEAK", "ALCHEMY.REXX.OVERRIDE", override, 700)
during1 = proxy~speak
g2 = proxy~replaceCSharp("C#-UNDER-OVERRIDE-2")
during2 = proxy~speak
proxy~removeRexxMemberOverride("SPEAK", "ALCHEMY.REXX.OVERRIDE")
revealed = proxy~speak
status = proxy~dotNetMemberInterpositionStatus("SPEAK")
return during1 || "|" || g2 || "|" || during2 || "|" || revealed || "|" || status["physical_wrappers"]

::class RexxSpeakOverride
::method before public unguarded
  use strict arg receiver, methodName, arguments
  return "override"
::method after public unguarded
  use strict arg receiver, methodName, token, result
  return "REXX-OVERRIDE"
::method failure public unguarded
  use strict arg receiver, methodName, token, conditionObject
  return .true
::requires 'AlchemyDotNetObject.cls'
