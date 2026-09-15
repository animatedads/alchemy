call assertTrue .QueueFabricBuild~API~pos('queue.fabric/') = 1, 'Queue Fabric API family advertised'
call assertTrue .NoSQLServerBuild~RELEASE~length > 0, 'NoSQLServer release identity advertised'
manager = .ObjectQueueManager~new('', .QueueGraphPayloadCodec~new, 'admin')
createOperation = manager~createQueue('PROBE', 'TEMPORARY', 'TEST', 2, 'admin')
call assertTrue createOperation~ok, 'Queue Fabric manager surface works'
adapter = .QueueNoSQLAdapter~new(manager)
queryResult = adapter~query('admin', 'SELECT fabric_version FROM mq_manager')
call assertEqual .Error~SUCCESS, queryResult~status, 'Queue NoSQL projection works under loaded NoSQLServer'
call assertEqual .QueueFabricBuild~VERSION, queryResult~rows[1]['fabric_version'], 'Queue projection retains loaded fabric identity'
say 'PASS test_shannon_queue_compatibility api=' || .QueueFabricBuild~API || ' fabric=' || .QueueFabricBuild~VERSION || ' nosql=' || .NoSQLServerBuild~RELEASE
exit 0

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonQueueService.cls'
::requires 'ObjectQueueNoSQL.cls'
