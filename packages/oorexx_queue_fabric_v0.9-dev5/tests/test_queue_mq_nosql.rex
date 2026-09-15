/* ObjectQueueFabric v0.9 NoSQL management projection acceptance. */
assertions = 0
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertOk manager~createQueue("WORK", "TEMPORARY", "OPS", 10, "admin"), "create WORK"
call assertOk manager~createQueue("DLQ", "TEMPORARY", "OPS", 10, "admin"), "create DLQ"
call assertOk manager~createQueue("BO", "TEMPORARY", "OPS", 10, "admin"), "create BO"
call assertOk manager~setDeadLetterQueue("DLQ", "admin"), "set DLQ"
call assertOk manager~configureBackout("WORK", 3, "BO", "admin"), "set backout"
options = .table~new; options["expirySeconds"] = 60
call assertOk manager~put("WORK", "payload", options, "admin"), "put expiring payload"

adapter = .QueueNoSQLAdapter~new(manager)
qr = adapter~query("admin", "SELECT queue_name,backout_threshold,backout_queue,expiring_depth,earliest_expiry_tick FROM mq_queues WHERE queue_name='WORK'")
call assertEqual .Error~SUCCESS, qr~status, "queue projection query"
call assertEqual 1, qr~rows~items, "queue projection row"
call assertEqual 3, qr~rows[1]["backout_threshold"], "backout threshold projected"
call assertEqual "BO", qr~rows[1]["backout_queue"], "backout queue projected"
call assertEqual 1, qr~rows[1]["expiring_depth"], "expiring depth projected"
call assertTrue qr~rows[1]["earliest_expiry_tick"] \= 0, "earliest expiry watermark projected"

pr = adapter~query("admin", "SELECT expiry_tick,backout_count,dead_letter_reason,dead_letter_source_queue FROM mq_packages WHERE queue_name='WORK'")
call assertEqual .Error~SUCCESS, pr~status, "package projection query"
call assertEqual 1, pr~rows~items, "package projection row"
call assertTrue pr~rows[1]["expiry_tick"] \= 0, "expiry tick projected"
call assertEqual 0, pr~rows[1]["backout_count"], "backout count projected"
call assertEqual "", pr~rows[1]["dead_letter_reason"], "empty disposition projected"

mr = adapter~query("admin", "SELECT fabric_version,dead_letter_queue,active_uow_count,recovery_warning_count FROM mq_manager")
call assertEqual .Error~SUCCESS, mr~status, "manager projection query"
call assertEqual 1, mr~rows~items, "admin manager row"
call assertEqual "0.9", mr~rows[1]["fabric_version"], "fabric version projected"
call assertEqual "DLQ", mr~rows[1]["dead_letter_queue"], "DLQ projected"
call assertEqual 0, mr~rows[1]["active_uow_count"], "UOW count projected"

uow = manager~beginUnitOfWork("admin")~value
mr2 = adapter~query("admin", "SELECT active_uow_count FROM mq_manager")
call assertEqual 1, mr2~rows[1]["active_uow_count"], "active UOW becomes queryable"
call assertOk manager~rollbackUnitOfWork(uow), "rollback empty UOW"

say "OBJECT QUEUE FABRIC V0.9 NOSQL: OK"
say "assertions=" || assertions
exit 0

assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "ObjectQueueNoSQL.cls"
