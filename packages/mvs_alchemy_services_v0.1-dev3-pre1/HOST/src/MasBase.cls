/* MasBase.cls - MAS BASE-0 host object skeleton.
 * Alchemy Objects v0.8.1 is an external prerequisite; it is not vendored.
 */
::requires 'AlchemyObject.cls'

::class MasMemoryQueue public subclass AlchemyObject
::method init public
  expose queue
  metadata = .directory~new
  metadata['PURPOSE'] = 'MAS BASE-0 in-memory qualification service'
  self~init:super(metadata)
  queue = .queue~new
  self~registerMethodContract('PUT', 'Append opaque bytes', .array~of('BYTES'), 'UINT64', .false)
  self~registerMethodContract('GET', 'Remove oldest opaque byte value', .array~new, 'BYTES', .false)
  self~registerMethodContract('DEPTH', 'Return queue depth', .array~new, 'UINT32', .false)

::method put public
  expose queue
  use strict arg bytes
  queue~queue(bytes)
  self~alchemyTouch('MAS.TEST.QUEUE.PUT')
  return queue~items

::method get public
  expose queue
  if queue~items = 0 then return .nil
  value = queue~pull
  self~alchemyTouch('MAS.TEST.QUEUE.GET')
  return value

::method depth public
  expose queue
  self~alchemyTouch('MAS.TEST.QUEUE.DEPTH')
  return queue~items

::class MasServiceRegistry public subclass AlchemyObject
::method init public
  expose services
  self~init:super
  services = .directory~new
  services['MAS.TEST.QUEUE'] = 'MEMORY_QUEUE'

::method open public
  expose services
  use strict arg serviceName
  key = serviceName~string~translate
  if \services~hasIndex(key) then return .nil
  if services[key] == 'MEMORY_QUEUE' then return .MasMemoryQueue~new
  return .nil
