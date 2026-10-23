use arg h
p = .AlchemyDotNetObject~new(h)
signal on syntax name caught
x = p~explode
return 'FAIL:NO-CONDITION'
caught:
  c = condition('O')
  return c~condition || ':' || c~description || ':' || c~additional
::requires 'AlchemyDotNetObject.cls'
