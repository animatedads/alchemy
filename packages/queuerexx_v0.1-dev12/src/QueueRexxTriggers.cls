/* QueueRexxTriggers.cls - durable idempotent trigger delivery, v0.1-dev10.
 *
 * A delivery id is stable across restart.  Durable triggers receive that id
 * and are required to make their external effect idempotent with respect to
 * it.  QueueRexx journals PREPARED before firing and COMPLETED afterwards.
 * A crash after the effect but before COMPLETED therefore replays the same
 * delivery id; it never invents a new logical delivery.
 */

::class QueueTriggerDeliveryPhase public
::constant PREPARED 1
::constant COMPLETED 2
::constant NAME_PREPARED "prepared"
::constant NAME_COMPLETED "completed"
::method name class
  use strict arg value
  if value == self~PREPARED then return self~NAME_PREPARED
  if value == self~COMPLETED then return self~NAME_COMPLETED
  return "unknown"

::class QueueTriggerDeliveryStatus public
::constant COMPLETED 1
::constant ALREADY_COMPLETED 2
::constant PREPARE_FAILED 3
::constant FIRE_FAILED 4
::constant COMPLETE_FAILED 5
::constant TRIGGER_NOT_FOUND 6
::constant TRIGGER_NOT_DURABLE 7
::constant NAME_COMPLETED "completed"
::constant NAME_ALREADY_COMPLETED "already_completed"
::constant NAME_PREPARE_FAILED "prepare_failed"
::constant NAME_FIRE_FAILED "fire_failed"
::constant NAME_COMPLETE_FAILED "complete_failed"
::constant NAME_TRIGGER_NOT_FOUND "trigger_not_found"
::constant NAME_TRIGGER_NOT_DURABLE "trigger_not_durable"
::method name class
  use strict arg value
  select
    when value == self~COMPLETED then return self~NAME_COMPLETED
    when value == self~ALREADY_COMPLETED then return self~NAME_ALREADY_COMPLETED
    when value == self~PREPARE_FAILED then return self~NAME_PREPARE_FAILED
    when value == self~FIRE_FAILED then return self~NAME_FIRE_FAILED
    when value == self~COMPLETE_FAILED then return self~NAME_COMPLETE_FAILED
    when value == self~TRIGGER_NOT_FOUND then return self~NAME_TRIGGER_NOT_FOUND
    when value == self~TRIGGER_NOT_DURABLE then return self~NAME_TRIGGER_NOT_DURABLE
    otherwise return "unknown"
  end

::class QueueTriggerDeliveryContext public
::attribute deliveryId get
::attribute triggerId get
::attribute eventId get
::attribute recovery get
::method init
  expose deliveryId triggerId eventId recovery
  use strict arg deliveryArg, triggerArg, eventArg, recoveryArg = .false
  deliveryId = deliveryArg~string; triggerId = triggerArg~string; eventId = eventArg~string; recovery = recoveryArg
::method asDirectory
  expose deliveryId triggerId eventId recovery
  d = .Directory~new
  d["delivery_id"] = deliveryId; d["trigger_id"] = triggerId; d["event_id"] = eventId
  d["recovery"] = .QueueRexxUtil~jsonBoolean(recovery)
  return d

::class QueueDurableTrigger public subclass QueueTrigger
::method fireDelivery abstract

::class QueueTriggerDeliveryReceipt public
::attribute status get
::attribute deliveryId get
::attribute triggerId get
::attribute eventId get
::attribute detail get
::method init
  expose status deliveryId triggerId eventId detail
  use strict arg statusArg, deliveryArg, triggerArg, eventArg, detailArg = ""
  status = statusArg + 0; deliveryId = deliveryArg~string; triggerId = triggerArg~string; eventId = eventArg~string; detail = detailArg~string
::method ok
  expose status
  return status == .QueueTriggerDeliveryStatus~COMPLETED | status == .QueueTriggerDeliveryStatus~ALREADY_COMPLETED
::method asDirectory
  expose status deliveryId triggerId eventId detail
  d = .Directory~new
  d["schema"] = .QueueSchema~TRIGGER_DELIVERY
  d["status"] = .QueueTriggerDeliveryStatus~name(status)
  d["status_code"] = status
  d["delivery_id"] = deliveryId
  d["trigger_id"] = triggerId
  d["event_id"] = eventId
  d["detail"] = detail
  return d

::class QueueTriggerDeliveryJournal public
::constant DIRECTORY_NAME "queuerexx-trigger-delivery"
::attribute root get
::attribute fileSystem get
::method init
  expose root fileSystem
  use strict arg rootArg, fileSystemArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new; else fileSystem = fileSystemArg
::method directory
  expose root
  return root || "/" || .QueueMutationPath~LOGS || "/" || self~DIRECTORY_NAME
::method safeToken private
  use strict arg valueArg
  value = valueArg~string
  out = ""
  allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
  do i = 1 to value~length
    c = value~substr(i,1)
    if allowed~pos(c) > 0 then out ||= c; else out ||= "_"
  end
  if out == "" then out = "unnamed"
  return out
::method deliveryId
  use strict arg event, trigger
  return self~safeToken(event~id) || "--" || self~safeToken(trigger~id)
::method phasePath
  use strict arg deliveryId, phase
  return self~directory || "/" || deliveryId || "." || .QueueTriggerDeliveryPhase~name(phase) || ".json"
::method phaseExists
  use strict arg deliveryId, phase
  return SysFileExists(self~phasePath(deliveryId, phase)) == 1
::method prepare
  use strict arg event, trigger
  deliveryId = self~deliveryId(event, trigger)
  if self~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~PREPARED) then return deliveryId
  d = .Directory~new
  d["delivery_id"] = deliveryId
  d["trigger_id"] = trigger~id
  d["event"] = event~asDirectory
  if \self~writePhase(deliveryId, .QueueTriggerDeliveryPhase~PREPARED, d) then return ""
  return deliveryId
::method complete
  use strict arg deliveryId, triggerId, eventId
  if self~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED) then return .true
  d = .Directory~new
  d["delivery_id"] = deliveryId; d["trigger_id"] = triggerId; d["event_id"] = eventId
  return self~writePhase(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED, d)
::method writeFailure
  expose root fileSystem
  use strict arg deliveryId, triggerId, eventId, detail
  dir = self~directory
  if \fileSystem~ensureDirectory(dir) then return .false
  path = dir || "/" || deliveryId || ".failed." || .DateTime~new~microseconds || ".json"
  d = .Directory~new
  d["schema"] = .QueueSchema~TRIGGER_DELIVERY
  d["delivery_id"] = deliveryId; d["trigger_id"] = triggerId; d["event_id"] = eventId
  d["phase"] = "failed"; d["detail"] = detail; d["recorded_at"] = .DateTime~new~string
  .QueueSerialization~toJsonFile(d, path)
  fileSystem~ensureOwnerLike(dir, root); fileSystem~ensureOwnerLike(path, root)
  return SysFileExists(path) == 1
::method writePhase private
  expose root fileSystem
  use strict arg deliveryId, phase, payload
  dir = self~directory
  if \fileSystem~ensureDirectory(dir) then return .false
  path = self~phasePath(deliveryId, phase)
  if SysFileExists(path) then return .true
  temp = path || ".tmp." || random(0,999999)~right(6,"0")
  d = .Directory~new
  d["schema"] = .QueueSchema~TRIGGER_DELIVERY
  d["delivery_id"] = deliveryId
  d["phase"] = .QueueTriggerDeliveryPhase~name(phase)
  d["recorded_at"] = .DateTime~new~string
  d["delivery"] = payload
  .QueueSerialization~toJsonFile(d, temp)
  if \SysFileExists(temp) then return .false
  if \fileSystem~replace(temp, path) then do; call SysFileDelete temp; return .false; end
  fileSystem~ensureOwnerLike(dir, root); fileSystem~ensureOwnerLike(path, root)
  return .true
::method pendingPrepared
  files = .Array~new
  dir = self~directory
  if \SysFileExists(dir) then return files
  drop found.
  call SysFileTree dir || "/*.prepared.json", "found.", "FO"
  do i = 1 to found.0
    doc = self~readDocument(found.i)
    if doc == .nil | \doc~hasIndex("delivery") then iterate
    deliveryId = doc["delivery_id"]~string
    if self~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED) then iterate
    files~append(doc)
  end
  return files
::method readDocument private
  use strict arg path
  signal on syntax name badDocument
  doc = .QueueSerialization~fromJsonFile(path)
  signal off syntax
  return doc
badDocument:
  signal off syntax
  return .nil

::class QueueDurableTriggerDispatcher public
::attribute registry get
::attribute journal get
::method init
  expose registry journal
  use strict arg rootArg, registryArg, journalArg = .nil
  registry = registryArg
  if journalArg == .nil then journal = .QueueTriggerDeliveryJournal~new(rootArg); else journal = journalArg
::method dispatch
  expose registry
  use strict arg event
  receipts = .Array~new
  do trigger over registry~matching(event~type)
    receipts~append(self~deliver(event, trigger, .false)~asDirectory)
  end
  return receipts
::method deliver
  expose journal
  use strict arg event, trigger, recoveryArg = .false
  deliveryId = journal~deliveryId(event, trigger)
  if journal~phaseExists(deliveryId, .QueueTriggerDeliveryPhase~COMPLETED) then return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~ALREADY_COMPLETED, deliveryId, trigger~id, event~id)
  if \trigger~isA(.QueueDurableTrigger) then return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~TRIGGER_NOT_DURABLE, deliveryId, trigger~id, event~id, "durable dispatcher requires QueueDurableTrigger/fireDelivery")
  preparedId = journal~prepare(event, trigger)
  if preparedId == "" then return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~PREPARE_FAILED, deliveryId, trigger~id, event~id)
  context = .QueueTriggerDeliveryContext~new(deliveryId, trigger~id, event~id, recoveryArg)
  signal on syntax name fireFailure
  fired = trigger~fireDelivery(event, context)
  signal off syntax
  if fired \= .true then do
    journal~writeFailure(deliveryId, trigger~id, event~id, "trigger returned false")
    return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~FIRE_FAILED, deliveryId, trigger~id, event~id, "trigger returned false")
  end
  if \journal~complete(deliveryId, trigger~id, event~id) then return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~COMPLETE_FAILED, deliveryId, trigger~id, event~id, "trigger effect succeeded but completion marker could not be persisted")
  return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~COMPLETED, deliveryId, trigger~id, event~id)
fireFailure:
  signal off syntax
  journal~writeFailure(deliveryId, trigger~id, event~id, "trigger raised ooRexx syntax condition")
  return .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~FIRE_FAILED, deliveryId, trigger~id, event~id, "trigger raised ooRexx syntax condition")
::method recover
  expose registry journal
  use arg maxDeliveriesArg = 100
  maxDeliveries = maxDeliveriesArg + 0; if maxDeliveries < 1 then maxDeliveries = 100
  receipts = .Array~new
  do doc over journal~pendingPrepared
    delivery = doc["delivery"]
    triggerId = delivery["trigger_id"]~string
    trigger = registry~get(triggerId)
    eventDoc = delivery["event"]
    event = .QueueEvent~new(eventDoc["id"], eventDoc["type"], eventDoc["qid"], eventDoc["state"], eventDoc["occurred_at"], eventDoc["data"])
    if trigger == .nil then receipt = .QueueTriggerDeliveryReceipt~new(.QueueTriggerDeliveryStatus~TRIGGER_NOT_FOUND, doc["delivery_id"], triggerId, event~id)
    else receipt = self~deliver(event, trigger, .true)
    receipts~append(receipt~asDirectory)
    if receipts~items >= maxDeliveries then leave
  end
  d = .Directory~new
  d["schema"] = .QueueSchema~TRIGGER_DELIVERY
  d["bounded"] = .JSONBoolean~true
  d["max_deliveries"] = maxDeliveries
  d["deliveries"] = receipts
  d["count"] = receipts~items
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxMutation.cls"
::requires "QueueRexxSerialization.cls"
