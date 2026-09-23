/* Alarm-backed delayed reminder service for the LLM PA.
 * The Alarm owns elapsed time. When it fires it enqueues a fresh PA request;
 * it never sends directly to Codex and never carries model/tool authority.
 */

::class LlmPaReminderService public
::method init
  expose binding alarms targets records
  use arg bindingArg
  if bindingArg == .nil then raise syntax 88.900 array("LLM PA reminder service requires a queue binding")
  binding = bindingArg
  alarms = .table~new
  targets = .table~new
  records = .table~new

::method schedule
  use arg expressionArg, parentRequestId = ""
  parsed = .LlmPaReminderSpec~parse(expressionArg)
  if \parsed~ok then return parsed
  spec = parsed~value
  return self~scheduleDecision(spec["delay_seconds"], spec["message"], parentRequestId, expressionArg, "deterministic")

/* Arm one already-interpreted one-shot reminder. The caller may be Gemma's
 * constrained scheduling decision or the explicit deterministic -remind-after
 * parser. This method validates the decision before constructing Alarm. */
::method scheduleDecision
  expose alarms targets records
  use arg delaySecondsArg, messageArg, parentRequestId = "", expressionArg = "", decisionSourceArg = "gemma"
  delayText = delaySecondsArg~string~strip
  if datatype(delayText, "W") = 0 then return .LlmPaResult~failure("REMINDER_DELAY_INVALID", delayText)
  delay = delayText + 0
  if delay < 1 then return .LlmPaResult~failure("REMINDER_DELAY_INVALID", delay)
  if delay > 31536000 then return .LlmPaResult~failure("REMINDER_DELAY_TOO_LONG", delay)
  message = messageArg~string~strip
  if message = "" then return .LlmPaResult~failure("REMINDER_MESSAGE_REQUIRED")
  reminderId = .LlmPaReminderSpec~reminderId
  rec = .directory~new
  rec["reminder_id"] = reminderId
  rec["parent_request_id"] = parentRequestId~string
  rec["expression"] = expressionArg~string
  rec["delay_seconds"] = delay
  rec["message"] = message
  rec["decision_source"] = decisionSourceArg~string
  rec["scheduled_at"] = .LlmPaUtil~timestamp
  rec["scheduled_microseconds"] = .LlmPaClock~absoluteMicroseconds
  rec["due_microseconds"] = rec["scheduled_microseconds"] + (delay * 1000000)
  rec["status"] = "ARMED"
  rec["one_shot"] = .true
  rec["event_type"] = "PA_WAKE"
  records[reminderId] = rec

  target = .LlmPaReminderAlarmTarget~new(self, reminderId)
  alarm = .Alarm~new(delay, target, "triggered")
  targets[reminderId] = target
  alarms[reminderId] = alarm
  return .LlmPaResult~success(rec)

/* Internal/runtime cancellation primitive. It is intentionally not exposed as
 * a PA command in this cut; it exists so lifecycle owners can retire an Alarm
 * explicitly without manufacturing a fire event. */
::method cancel
  expose alarms targets records
  use arg reminderIdArg
  reminderId = reminderIdArg~string
  if \records~hasIndex(reminderId) then return .LlmPaResult~failure("REMINDER_NOT_FOUND", reminderId)
  rec = records[reminderId]
  if rec["status"] \= "ARMED" then return .LlmPaResult~failure("REMINDER_NOT_ARMED", reminderId)
  alarm = alarms~at(reminderId)
  if alarm \== .nil then alarm~cancel
  alarms[reminderId] = .nil
  targets[reminderId] = .nil
  rec["status"] = "CANCELLED"
  rec["cancelled_at"] = .LlmPaUtil~timestamp
  return .LlmPaResult~success(rec)

::method fired public unguarded
  expose binding alarms targets records
  use arg reminderIdArg
  reminderId = reminderIdArg~string
  if \records~hasIndex(reminderId) then return .LlmPaResult~failure("REMINDER_NOT_FOUND", reminderId)
  rec = records[reminderId]
  if rec["status"] \= "ARMED" then return .LlmPaResult~failure("REMINDER_NOT_ARMED", reminderId)
  rec["status"] = "FIRED"
  rec["fired_at"] = .LlmPaUtil~timestamp
  alarms[reminderId] = .nil
  targets[reminderId] = .nil
  queued = binding~submitAlarm("alarm_fire", rec["message"], reminderId, "alarm:" || reminderId)
  if \queued~ok then do
    rec["status"] = "FIRE_QUEUE_FAILED"
    rec["fire_error"] = queued~code
    return queued
  end
  rec["fire_request_id"] = queued~value["request_id"]
  rec["fire_package_id"] = queued~value["package_id"]
  return .LlmPaResult~success(rec)

::method record
  expose records
  use arg reminderIdArg
  reminderId = reminderIdArg~string
  if \records~hasIndex(reminderId) then return .LlmPaResult~failure("REMINDER_NOT_FOUND", reminderId)
  return .LlmPaResult~success(records[reminderId])


::method calendar
  expose records
  out = .array~new
  nowMicros = .LlmPaClock~absoluteMicroseconds
  do key over records~allIndexes
    rec = records[key]
    if rec["status"] \= "ARMED" then iterate
    row = .LlmPaUtil~copyDirectory(rec)
    remainingMicros = row["due_microseconds"] - nowMicros
    if remainingMicros <= 0 then remainingSeconds = 0
    else remainingSeconds = trunc((remainingMicros + 999999) / 1000000)
    row["remaining_seconds"] = remainingSeconds
    out~append(row)
  end
  return .LlmPaResult~success(out)

::method armedCount
  expose records
  count = 0
  do key over records~allIndexes
    rec = records[key]
    if rec["status"] = "ARMED" then count += 1
  end
  return count

::class LlmPaReminderSpec public
::method parse class
  use arg expressionArg
  expression = expressionArg~string~strip
  if expression = "" then return .LlmPaResult~failure("REMINDER_EXPRESSION_REQUIRED")
  parse var expression inWord amount unit message
  if inWord~translate \= "IN" then return .LlmPaResult~failure("REMINDER_REQUIRES_IN", expression)
  if datatype(amount, "W") = 0 | amount < 1 then return .LlmPaResult~failure("REMINDER_DELAY_INVALID", amount)
  unitLower = unit~lower
  select
    when unitLower = "second" | unitLower = "seconds" | unitLower = "sec" | unitLower = "secs" then multiplier = 1
    when unitLower = "minute" | unitLower = "minutes" | unitLower = "min" | unitLower = "mins" then multiplier = 60
    when unitLower = "hour" | unitLower = "hours" | unitLower = "hr" | unitLower = "hrs" then multiplier = 3600
    when unitLower = "day" | unitLower = "days" then multiplier = 86400
    otherwise return .LlmPaResult~failure("REMINDER_UNIT_INVALID", unit)
  end
  message = message~strip
  if message = "" then return .LlmPaResult~failure("REMINDER_MESSAGE_REQUIRED")
  delay = amount * multiplier
  /* Bound one Alarm to 365 days. Long-term calendars belong to a scheduler,
   * not an in-process personal-assistant alarm. */
  if delay > 31536000 then return .LlmPaResult~failure("REMINDER_DELAY_TOO_LONG", delay)
  d = .directory~new
  d["delay_seconds"] = delay
  d["amount"] = amount
  d["unit"] = unitLower
  d["message"] = message
  return .LlmPaResult~success(d)

::method reminderId class
  return "rem-" || date("S") || "-" || time("L")~changestr(":", "")~changestr(".", "") || "-" || random(100000, 999999)

::class LlmPaReminderAlarmTarget public inherit AlarmNotification
::method init public
  expose service reminderId
  use arg serviceArg, reminderIdArg
  service = serviceArg
  reminderId = reminderIdArg~string

::method triggered public unguarded
  expose service reminderId
  use arg alarm
  if service == .nil then return .false
  ignore = service~fired(reminderId)
  return .true

::requires "LlmPaCore.cls"
