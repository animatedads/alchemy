use arg h
p = .ExistingUnknownDotNetThing~new(h, 'PING SELF EXPLODE')
signal on syntax name caught
x = p~explode
return 'FAIL:NO-CONDITION'
caught:
  c = condition('O')
  return c~condition || ':' || c~additional
::requires 'AlchemyDotNetObject.cls'
