use strict arg handle
p = .AlchemyDotNetObject~new(handle)
c1 = p~dotNetClass
c2 = p~dotNetClass
b = c1~baseType
same = (c1~alchemyHandle == c2~alchemyHandle)
return c1~name || '|' || b~name || '|' || c1~isInstance(p) || '|' || c1~isSubclassOf(b) || '|' || b~isAssignableFrom(c1) || '|' || same
::requires 'AlchemyDotNetObject.cls'
