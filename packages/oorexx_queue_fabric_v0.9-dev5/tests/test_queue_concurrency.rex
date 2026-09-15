producerCount = 8
perProducer = 250
overrideCount = value("QUEUE_CONCURRENCY_PER_PRODUCER",, "ENVIRONMENT")
if overrideCount \= "" then do
  if datatype(overrideCount, "W") & overrideCount > 0 then perProducer = overrideCount
end
expected = producerCount * perProducer
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
createResult = manager~createQueue("CONCURRENT", "TEMPORARY", "OPS", 0, "admin")
if \createResult~ok then exit 1

messages = .array~new
do workerNo = 1 to producerCount
  worker = .ProducerWorker~new(manager, workerNo, perProducer)
  message = .Message~new(worker, "RUN")
  message~start
  messages~append(message)
end
producerErrors = 0
do message over messages
  message~wait
  if message~errorCondition \== .nil then do
    say "producer activity condition" message~errorCondition
    exit 1
  end
  producerErrors += message~result
end
call assert producerErrors = 0, "all concurrent puts succeed"
call assert manager~depth("CONCURRENT", "admin")~value["ready"] = expected, "all produced packages visible"

messages = .array~new
do workerNo = 1 to producerCount
  worker = .ConsumerWorker~new(manager)
  message = .Message~new(worker, "RUN")
  message~start
  messages~append(message)
end
seen = .table~new
consumed = 0
duplicates = 0
do message over messages
  message~wait
  if message~errorCondition \== .nil then do
    say "consumer activity condition" message~errorCondition
    exit 1
  end
  ids = message~result
  consumed += ids~items
  do id over ids
    if seen~hasIndex(id) then duplicates += 1
    else seen[id] = .true
  end
end
call assert consumed = expected, "all packages consumed exactly once by count"
call assert duplicates = 0, "no package id consumed twice"
call assert seen~items = expected, "all consumed package ids unique"
call assert manager~depth("CONCURRENT", "admin")~value["total"] = 0, "queue drains to zero"

say "OBJECT QUEUE FABRIC V0.8 CONCURRENCY: OK"
say "produced=" || expected "consumed=" || consumed "duplicates=" || duplicates
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::class ProducerWorker
::method init
  expose manager workerNo loops
  use arg manager, workerNo, loops
::method run
  expose manager workerNo loops
  errors = 0
  do i = 1 to loops
    operationResult = manager~put("CONCURRENT", "worker-" || workerNo || "-" || i, .nil, "admin")
    if \operationResult~ok then errors += 1
  end
  return errors

::class ConsumerWorker
::method init
  expose manager
  use arg manager
::method run
  expose manager
  ids = .array~new
  do forever
    operationResult = manager~get("CONCURRENT", "admin")
    if \operationResult~ok then do
      if operationResult~code = "QUEUE_EMPTY" then leave
      raise syntax 88.900 array("consumer get failed " || operationResult~code)
    end
    ids~append(operationResult~value~packageId)
  end
  return ids

::requires "ObjectQueueFabric.cls"
