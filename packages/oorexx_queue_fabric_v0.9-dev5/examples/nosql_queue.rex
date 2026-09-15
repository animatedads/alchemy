/* Object Queue Fabric v0.8: NoSQLServer v0.73 metadata projection example. */

manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call must manager~createQueue("WORK", "TEMPORARY", "OPS", 10, "admin"), "create WORK"
call must manager~grant("WORK", "observer", .QueueAccess~BROWSE, "admin"), "grant BROWSE"
call must manager~grant("WORK", "producer", .QueueAccess~PUT, "admin"), "grant PUT"

options = .table~new
options["priority"] = 4
options["routingKey"] = "image"
call must manager~put("WORK", .array~of("object", 42), options, "producer"), "put package"

adapter = .QueueNoSQLAdapter~new(manager)
queryResult = adapter~query("observer", -
  "SELECT package_id,queue_name,priority,routing_key,payload_class FROM mq_packages")
if queryResult~status \= .Error~SUCCESS then do
  say "SQL FAILED:" queryResult~status queryResult~message
  exit 1
end

do row over queryResult~rows
  say row["package_id"] row["queue_name"] row["priority"] row["routing_key"] row["payload_class"]
end
exit 0

must: procedure
  use arg operationResult, label
  if \operationResult~ok then do
    say "FAILED:" label operationResult~code operationResult~detail
    exit 1
  end
  return

::requires "ObjectQueueNoSQL.cls"
