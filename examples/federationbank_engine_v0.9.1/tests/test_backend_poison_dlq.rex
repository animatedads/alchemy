parse source . . script
root = value("FB_TEST_QUEUE_ROOT",,"ENVIRONMENT")
if root = "" then do; say "FAIL FB_TEST_QUEUE_ROOT required"; exit 1; end
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology = .FederationBankServiceTopology~new(manager)
usage = .FederationBankPaymentsUsageProjection~new(topology~topics)
/* Dummy engines are sufficient because malformed payload is rejected before domain invocation. */
runtime = .FederationBankBackendRuntime~new(topology, .nil, .nil, .nil)

bad = .directory~new
bad["schema"] = "not-a-bank-command"
opts = .table~new
opts["persistent"] = .true
put = manager~put(.FederationBankServiceTopology~PAYMENTS_COMMANDS, bad, opts, .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
call qmust put, "put poison command"

first = runtime~processPaymentsOne
call assert first~ok = .false, "first malformed attempt rejected"
call assert first~code = "MALFORMED_PAYMENT_COMMAND", "malformed code first attempt"
call assert manager~depth(.FederationBankServiceTopology~PAYMENTS_COMMANDS,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value["ready"] = 1, "first rollback requeues"
firstPackage = manager~browse(.FederationBankServiceTopology~PAYMENTS_COMMANDS,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value
call assert firstPackage~backoutCount = 1, "first rollback increments backout"

second = runtime~processPaymentsOne
call assert second~ok = .false, "second malformed attempt rejected"
call assert manager~depth(.FederationBankServiceTopology~PAYMENTS_COMMANDS,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value["total"] = 0, "source drained at threshold"
call assert manager~depth(.FederationBankServiceTopology~BACKEND_DLQ,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value["ready"] = 1, "poison command moved to backend DLQ"
dlq = manager~browse(.FederationBankServiceTopology~BACKEND_DLQ,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value
call assert dlq~backoutCount = 2, "DLQ preserves backout count"
call assert dlq~deadLetterReason = "BACKOUT_THRESHOLD", "DLQ records threshold reason"
call assert dlq~deadLetterSourceQueue = .FederationBankServiceTopology~PAYMENTS_COMMANDS, "DLQ records source queue"

/* Restart proves the DLQ disposition itself is durable. */
manager2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, .FederationBankServiceTopology~ADMIN_PRINCIPAL)
topology2 = .FederationBankServiceTopology~new(manager2)
call assert manager2~depth(.FederationBankServiceTopology~BACKEND_DLQ,.FederationBankServiceTopology~ADMIN_PRINCIPAL)~value["ready"] = 1, "DLQ survives queue-manager restart"
say "PASS malformed backend command bounded to durable DLQ"
exit 0
qmust: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
