/* Optional binding to ooRexx JSON-RPC Fabric 0.1-dev3.
 * Transport/routing remains wholly external in ConnectSelector.
 * This adapter only binds the explicitly published time operations
 * and projects domain result records to JSON typed values.
 */
::requires 'TimeServiceEndpoint.cls'
::requires 'JsonRpcFabric.cls'

::class 'TimeJsonRpcHandler' public
::method init
  expose endpoint
  use strict arg endpoint

::method invoke
  expose endpoint
  use strict arg name, args, context
  if name \= 'time.zone.resolve' & name \= 'time.zone.compare' & name \= 'time.recurrence.expand' & name \= 'time.event.resolve' & name \= 'time.authority.info' & name \= 'time.impact.analyze' then
    return .JsonRpcFault~new(-32601,'Method not found')
  reply = endpoint~request(name,args)
  if \reply~ok then do
    if reply~fault == 'NOT_FOUND' then return .JsonRpcFault~new(-32601,'Method not found')
    return .JsonRpcFault~new(-32602,'Invalid arguments or timezone coverage')
  end
  return self~encodeValue(reply~result)

/* This is schema-aware marshaling, not generic string guessing: IDs that
 * look numeric (e.g. '007') remain strings. Only declared fields are numbers. */
::method encodeValue private
  use strict arg value, key = ''
  numeric digits 30
  if value == .nil then return .nil
  if value~isA(.Directory) | value~isA(.Table) then do
    entries=.directory~new
    do field over value~allIndexes
      entries[field]=self~encodeValue(value[field],field)
    end
    return entries
  end
  if value~isA(.Array) then do
    entries=.array~new
    do member over value
      entries~append(self~encodeValue(member))
    end
    return entries
  end
  if value~isA(.JsonString) then return value
  if value~isA(.String) then do
    if key == 'instantPosixSeconds' | key == 'offsetSeconds' | key == 'fromOffsetSeconds' | key == 'toOffsetSeconds' |,
       key == 'differenceSeconds' | key == 'interval' | key == 'generatedCount' |,
       key == 'elapsedDurationSeconds' | key == 'catalogRevision' | key == 'authoritySequence' | key == 'revision' |,
       key == 'fromRevision' | key == 'toRevision' | key == 'scannedDays' |,
       key == 'changedDays' | key == 'unchangedDays' | key == 'utcDeltaSeconds' then do
      if \datatype(value,'W') then raise syntax 93.900 array ('expected numeric field' key)
      return value
    end
    return .JsonString~new(value)
  end
  return value
