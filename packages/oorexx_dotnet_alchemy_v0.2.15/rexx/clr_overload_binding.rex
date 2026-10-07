use strict arg handle
proxy = .AlchemyDotNetObject~new(handle)
return proxy~overload("text") || "|" || proxy~overload(proxy)

::requires "AlchemyDotNetObject.cls"
