use arg handle
proxy = .AlchemyDotNetObject~new(handle)
generation = proxy~installRexxBehaviour
return proxy~speak
::requires 'AlchemyDotNetObject.cls'
