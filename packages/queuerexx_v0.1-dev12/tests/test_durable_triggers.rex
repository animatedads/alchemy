root = "/mnt/data/queuerexx-dev10-trigger-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/logs"
effects = root || "/effects.log"
registry = .QueueTriggerRegistry~new
trigger = .IdempotentFileTrigger~new(root, effects)
registry~register(trigger)
journal = .QueueTriggerDeliveryJournal~new(root)
dispatcher = .QueueDurableTriggerDispatcher~new(root, registry, journal)
data = .Directory~new; data["detail"] = "test"
event = .QueueEvent~new("event-1", .QueueEvent~JOB_COMPLETED, "qid-1", .QueueState~NAME_DONE, .DateTime~new~string, data)

/* Simulate crash after the external effect but before COMPLETED. */
deliveryId = journal~prepare(event, trigger)
call must deliveryId \= "", "prepare"
context = .QueueTriggerDeliveryContext~new(deliveryId, trigger~id, event~id, .false)
call must trigger~fireDelivery(event, context), "initial effect"
call must countLines(effects) == 1, "one initial effect"
call must \journal~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED), "completion intentionally absent"

recovered = dispatcher~recover(10)
call must recovered["count"] == 1, "one recovery"
call must recovered["deliveries"][1]["status"] == .QueueTriggerDeliveryStatus~NAME_COMPLETED, "recovery completed"
call must countLines(effects) == 1, "stable delivery id prevented duplicate effect"
call must journal~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED), "completion persisted"

again = dispatcher~dispatch(event)
call must again~items == 1, "redispatch receipt"
call must again[1]["status"] == .QueueTriggerDeliveryStatus~NAME_ALREADY_COMPLETED, "already completed"
call must countLines(effects) == 1, "redispatch did not duplicate effect"
say "PASS durable idempotent trigger delivery + restart replay"
exit 0

countLines: procedure
  parse arg path
  if \SysFileExists(path) then return 0
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return 0
  n = 0
  do while s~lines > 0
    ignore = s~lineIn
    n += 1
  end
  s~close
  return n

must: procedure
  parse arg conditionValue, message
  if \conditionValue then do
    say "FAIL" message
    exit 1
  end
  return

::class IdempotentFileTrigger subclass QueueDurableTrigger
::attribute root get
::attribute effects get
::method init
  expose root effects
  use strict arg rootArg, effectsArg
  root = rootArg~string; effects = effectsArg~string
::method id
  return "test-idempotent-trigger"
::method eventTypes
  return .Array~of(.QueueEvent~JOB_COMPLETED)
::method fire
  use strict arg event
  return .false
::method fireDelivery
  expose root effects
  use strict arg event, context
  marker = root || "/" || context~deliveryId || ".effect"
  if SysFileExists(marker) then return .true
  call lineout effects, context~deliveryId || " " || event~id
  call lineout effects
  call lineout marker, "done"
  call lineout marker
  return .true

::requires "QueueRexxTriggers.cls"
