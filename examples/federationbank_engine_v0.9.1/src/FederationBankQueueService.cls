/* Queue-backed ingress/egress boundary for FederationBank banking operations. */
::class FederationBankQueueService public
::constant OPS_QUEUE "FB.BANKING.OPS"
::constant RESULTS_QUEUE "FB.BANKING.RESULTS"
::constant SECURITY_DOMAIN "FEDERATIONBANK-IOM"
::constant API_PRINCIPAL "bank-api"
::constant WORKER_PRINCIPAL "bank-worker"
::constant ADMIN_PRINCIPAL "bank-admin"
::method init
  expose engine manager durable persistent
  use arg engineArg, durableRoot = "", managerArg = .nil
  if engineArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ENGINE_REQUIRED")
  engine = engineArg
  if managerArg == .nil then manager = .ObjectQueueManager~new(durableRoot, .QueueGraphPayloadCodec~new, self~ADMIN_PRINCIPAL)
  else manager = managerArg
  durable = durableRoot~string <> ""
  if durable then lifecycle = .QueueLifecycle~PERMANENT
  else lifecycle = .QueueLifecycle~TEMPORARY
  persistent = durable
  ignored = self~must(manager~createQueue(self~OPS_QUEUE, lifecycle, self~SECURITY_DOMAIN, 10000, self~ADMIN_PRINCIPAL), "create ops")
  ignored = self~must(manager~createQueue(self~RESULTS_QUEUE, lifecycle, self~SECURITY_DOMAIN, 10000, self~ADMIN_PRINCIPAL), "create results")
  ignored = self~must(manager~grant(self~OPS_QUEUE, self~API_PRINCIPAL, .QueueAccess~PUT, self~ADMIN_PRINCIPAL), "grant api put")
  ignored = self~must(manager~grant(self~OPS_QUEUE, self~WORKER_PRINCIPAL, .QueueAccess~GET, self~ADMIN_PRINCIPAL), "grant worker get")
  ignored = self~must(manager~grant(self~OPS_QUEUE, self~WORKER_PRINCIPAL, .QueueAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant worker browse")
  ignored = self~must(manager~grant(self~RESULTS_QUEUE, self~WORKER_PRINCIPAL, .QueueAccess~PUT, self~ADMIN_PRINCIPAL), "grant worker result put")
  ignored = self~must(manager~grant(self~RESULTS_QUEUE, self~API_PRINCIPAL, .QueueAccess~GET, self~ADMIN_PRINCIPAL), "grant api result get")
  ignored = self~must(manager~grant(self~RESULTS_QUEUE, self~API_PRINCIPAL, .QueueAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant api result browse")
::method manager
  expose manager
  return manager
::method must private
  use arg result, label
  if result~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_QUEUE_INIT_FAILED", label, result~code, result~detail)
  return result
::method submit
  expose manager persistent
  use arg command
  if command == .nil then return .QueueOperationResult~failure("COMMAND_REQUIRED")
  payload = command~asPayload
  options = .table~new
  options["persistent"] = persistent
  options["correlationId"] = command~commandId
  headers = .table~new
  headers["schema"] = .FederationBankBuild~API_VERSION || "/queue-command"
  headers["operation"] = command~operation
  headers["customerId"] = command~customerId
  headers["currency"] = command~currency
  headers["bookingEntity"] = .FederationBankBuild~BOOKING_ENTITY
  headers["bookingJurisdiction"] = .FederationBankBuild~BOOKING_JURISDICTION
  headers["idempotencyKey"] = command~idempotencyKey
  headers["actorId"] = command~actorId
  options["headers"] = headers
  return manager~put(self~OPS_QUEUE, payload, options, self~API_PRINCIPAL)
::method resultPayload private
  use arg command, bankResult
  d = .directory~new
  d["schema"] = .FederationBankBuild~API_VERSION || "/queue-result"
  d["commandId"] = command~commandId
  d["operation"] = command~operation
  d["idempotencyKey"] = command~idempotencyKey
  d["ok"] = bankResult~ok
  d["code"] = bankResult~code
  d["detail"] = bankResult~detail
  if bankResult~value <> .nil then do
    if bankResult~value~isA(.Directory) then do key over bankResult~value
      value = bankResult~value[key]
      if value == .nil then d[key] = ""
      else if value~class~id = "String" then d[key] = value
    end
  end
  return d
::method processOne
  expose manager engine persistent
  claim = manager~claim(self~OPS_QUEUE, self~WORKER_PRINCIPAL)
  if claim~ok = .false then return .FederationBankResult~failure("QUEUE_CLAIM_FAILED", claim~code || ":" || claim~detail, claim)
  package = claim~value
  command = .FederationBankCommand~fromPayload(package~payload)
  handled = engine~handle(command)
  resultOptions = .table~new
  resultOptions["persistent"] = persistent
  resultOptions["correlationId"] = command~commandId
  resultHeaders = .table~new
  resultHeaders["commandId"] = command~commandId
  resultHeaders["operation"] = command~operation
  resultHeaders["idempotencyKey"] = command~idempotencyKey
  resultHeaders["outcome"] = handled~code
  resultOptions["headers"] = resultHeaders
  published = manager~put(self~RESULTS_QUEUE, self~resultPayload(command, handled), resultOptions, self~WORKER_PRINCIPAL)
  if published~ok = .false then do
    ignored = manager~nack(self~OPS_QUEUE, package~packageId, package~claimToken, self~WORKER_PRINCIPAL)
    return .FederationBankResult~failure("RESULT_PUBLISH_FAILED", published~code || ":" || published~detail, published)
  end
  acked = manager~ack(self~OPS_QUEUE, package~packageId, package~claimToken, self~WORKER_PRINCIPAL)
  if acked~ok = .false then return .FederationBankResult~failure("QUEUE_ACK_FAILED", acked~code || ":" || acked~detail, acked)
  return handled
::method getResult
  expose manager
  got = manager~get(self~RESULTS_QUEUE, self~API_PRINCIPAL)
  return got

::requires "FederationBankEngine.cls"
::requires "ObjectQueueFabric.cls"
