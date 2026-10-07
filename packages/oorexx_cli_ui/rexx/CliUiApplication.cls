::class CliUiKeyMap public
::method init; expose bindings; bindings=.directory~new
::method bind; expose bindings; use strict arg chord,command; bindings[chord~lower]=command; return self
::method resolve; expose bindings; use strict arg chord; k=chord~lower; if bindings~hasIndex(k) then return bindings[k]; return .nil

::class CliUiViewport public
::method init; expose top left rows cols; use strict arg rows=24,cols=80; top=1;left=1
::attribute top
::attribute left
::attribute rows
::attribute cols

::class CliUiFocusRing public
::method init
  expose ids current
  use strict arg ids
  if ids == .nil then ids = .array~new
  current=1
::method current; expose ids current; if ids~items=0 then return .nil; return ids[current]
::method next; expose ids current; if ids~items>0 then current=(current//ids~items)+1; return self~current
::method previous; expose ids current; if ids~items>0 then do; current=current-1; if current<1 then current=ids~items; end; return self~current
