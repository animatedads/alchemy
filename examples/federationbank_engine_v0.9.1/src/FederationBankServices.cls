/* FederationBank v0.9.1 split backend services.
 * Three independent authorities joined only by Queue Fabric:
 *   Account Engine -> Payments Engine -> Ledger Engine.
 * Queue retained topics provide restartable projection facts; they are not
 * a substitute for the Ledger SQL monetary truth.
 */

::class FederationBankServiceTopology public
::constant SECURITY_DOMAIN "FEDERATIONBANK-IOM"
::constant ADMIN_PRINCIPAL "fb-admin"
::constant CHANNEL_PRINCIPAL "fb-channel"
::constant ACCOUNT_WORKER "fb-account-worker"
::constant PAYMENTS_WORKER "fb-payments-worker"
::constant LEDGER_WORKER "fb-ledger-worker"
::constant ATM_GATEWAY "fb-atm-gateway"

::constant ACCOUNT_COMMANDS "FB.ACCOUNT.COMMANDS"
::constant ACCOUNT_RESULTS "FB.ACCOUNT.RESULTS"
::constant PAYMENTS_COMMANDS "FB.PAYMENTS.COMMANDS"
::constant PAYMENTS_RESULTS "FB.PAYMENTS.RESULTS"
::constant LEDGER_COMMANDS "FB.LEDGER.COMMANDS"
::constant LEDGER_RESULTS "FB.LEDGER.RESULTS"
::constant ACCOUNT_TO_PAYMENTS "FB.ACCOUNT.PROJECTIONS.PAYMENTS"
::constant ACCOUNT_TO_LEDGER "FB.ACCOUNT.PROJECTIONS.LEDGER"
::constant BENEFICIARY_TO_PAYMENTS "FB.BENEFICIARIES.TO.PAYMENTS"
::constant BACKEND_DLQ "FB.BACKEND.DLQ"
::constant USAGE_TOPIC "FB.PAYMENTS.USAGE"
::constant USAGE_TOPIC_ROOT "payments/usage"
::constant ACCOUNT_STATE_TOPIC "FB.ACCOUNTS.STATE"
::constant ACCOUNT_STATE_TOPIC_ROOT "accounts/state"
::constant BENEFICIARY_STATE_TOPIC "FB.BENEFICIARIES.STATE"
::constant BENEFICIARY_STATE_TOPIC_ROOT "beneficiaries/state"
::constant ATM_SESSION_TOPIC "FB.ATM.SESSIONS"
::constant ATM_SESSION_TOPIC_ROOT "atm/sessions"
::constant ATM_OFFLINE_AUTHORITY_TOPIC "FB.ATM.OFFLINE.AUTHORITY"
::constant ATM_OFFLINE_AUTHORITY_TOPIC_ROOT "atm/offline-authority"

::method init
  expose manager topics persistent
  use arg managerArg
  if managerArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_QUEUE_MANAGER_REQUIRED")
  manager = managerArg
  persistent = manager~durableStore <> .nil
  if persistent then lifecycle = .QueueLifecycle~PERMANENT
  else lifecycle = .QueueLifecycle~TEMPORARY

  do q over .array~of(self~ACCOUNT_COMMANDS, self~ACCOUNT_RESULTS, self~PAYMENTS_COMMANDS, self~PAYMENTS_RESULTS, self~LEDGER_COMMANDS, self~LEDGER_RESULTS, self~ACCOUNT_TO_PAYMENTS, self~ACCOUNT_TO_LEDGER, self~BENEFICIARY_TO_PAYMENTS, self~BACKEND_DLQ)
    if manager~queue(q) == .nil then ignored = self~must(manager~createQueue(q, lifecycle, self~SECURITY_DOMAIN, 10000, self~ADMIN_PRINCIPAL), "create " || q)
  end
  ignored = self~must(manager~setDeadLetterQueue(self~BACKEND_DLQ, self~ADMIN_PRINCIPAL), "set backend DLQ")
  do q over .array~of(self~ACCOUNT_COMMANDS, self~PAYMENTS_COMMANDS, self~LEDGER_COMMANDS, self~ACCOUNT_TO_PAYMENTS, self~ACCOUNT_TO_LEDGER, self~BENEFICIARY_TO_PAYMENTS, self~LEDGER_RESULTS)
    ignored = self~must(manager~configureBackout(q, 2, self~BACKEND_DLQ, self~ADMIN_PRINCIPAL), "configure backout " || q)
  end

  /* Channel can ask Account/Payments and read their outcomes, but is
     deliberately never granted PUT to Ledger. */
  ignored = self~grant(self~ACCOUNT_COMMANDS, self~CHANNEL_PRINCIPAL, .QueueAccess~PUT)
  ignored = self~grant(self~ACCOUNT_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~GET)
  ignored = self~grant(self~ACCOUNT_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~BROWSE)
  ignored = self~grant(self~PAYMENTS_COMMANDS, self~CHANNEL_PRINCIPAL, .QueueAccess~PUT)
  ignored = self~grant(self~PAYMENTS_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~GET)
  ignored = self~grant(self~PAYMENTS_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~BROWSE)

  ignored = self~grant(self~ACCOUNT_COMMANDS, self~ACCOUNT_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~ACCOUNT_RESULTS, self~ACCOUNT_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~ACCOUNT_TO_PAYMENTS, self~ACCOUNT_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~ACCOUNT_TO_LEDGER, self~ACCOUNT_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~BENEFICIARY_TO_PAYMENTS, self~ACCOUNT_WORKER, .QueueAccess~PUT)

  ignored = self~grant(self~ACCOUNT_TO_PAYMENTS, self~PAYMENTS_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~BENEFICIARY_TO_PAYMENTS, self~PAYMENTS_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~PAYMENTS_COMMANDS, self~PAYMENTS_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~LEDGER_COMMANDS, self~PAYMENTS_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~LEDGER_RESULTS, self~PAYMENTS_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~PAYMENTS_RESULTS, self~PAYMENTS_WORKER, .QueueAccess~PUT)

  ignored = self~grant(self~ACCOUNT_TO_LEDGER, self~LEDGER_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~LEDGER_COMMANDS, self~LEDGER_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~LEDGER_RESULTS, self~LEDGER_WORKER, .QueueAccess~PUT)

  topics = .QueueTopicFabric~new(manager)
  if topics~topic(self~USAGE_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~USAGE_TOPIC, self~USAGE_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define usage topic")
  ignored = self~must(topics~grantTopicAccess(self~USAGE_TOPIC, self~PAYMENTS_WORKER, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant usage publish")
  ignored = self~must(topics~grantTopicAccess(self~USAGE_TOPIC, self~PAYMENTS_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant usage browse")

  if topics~topic(self~ACCOUNT_STATE_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~ACCOUNT_STATE_TOPIC, self~ACCOUNT_STATE_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define account state topic")
  ignored = self~must(topics~grantTopicAccess(self~ACCOUNT_STATE_TOPIC, self~ACCOUNT_WORKER, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant account-state publish")
  ignored = self~must(topics~grantTopicAccess(self~ACCOUNT_STATE_TOPIC, self~PAYMENTS_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant payments account-state browse")
  ignored = self~must(topics~grantTopicAccess(self~ACCOUNT_STATE_TOPIC, self~LEDGER_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant ledger account-state browse")
  if topics~subscription("FB.ACCOUNTS.TO.PAYMENTS") == .nil then ignored = self~must(topics~subscribe("FB.ACCOUNTS.TO.PAYMENTS", self~ACCOUNT_STATE_TOPIC, "#", self~ACCOUNT_TO_PAYMENTS, lifecycle, self~ADMIN_PRINCIPAL), "subscribe Payments to account state")
  if topics~subscription("FB.ACCOUNTS.TO.LEDGER") == .nil then ignored = self~must(topics~subscribe("FB.ACCOUNTS.TO.LEDGER", self~ACCOUNT_STATE_TOPIC, "#", self~ACCOUNT_TO_LEDGER, lifecycle, self~ADMIN_PRINCIPAL), "subscribe Ledger to account state")

  if topics~topic(self~ATM_SESSION_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~ATM_SESSION_TOPIC, self~ATM_SESSION_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define ATM session topic")
  ignored = self~must(topics~grantTopicAccess(self~ATM_SESSION_TOPIC, self~ATM_GATEWAY, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant ATM session publish")
  ignored = self~must(topics~grantTopicAccess(self~ATM_SESSION_TOPIC, self~ATM_GATEWAY, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant ATM session browse")

  if topics~topic(self~ATM_OFFLINE_AUTHORITY_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~ATM_OFFLINE_AUTHORITY_TOPIC, self~ATM_OFFLINE_AUTHORITY_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define ATM offline authority topic")
  ignored = self~must(topics~grantTopicAccess(self~ATM_OFFLINE_AUTHORITY_TOPIC, self~ATM_GATEWAY, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant ATM offline authority publish")
  ignored = self~must(topics~grantTopicAccess(self~ATM_OFFLINE_AUTHORITY_TOPIC, self~ATM_GATEWAY, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant ATM offline authority browse")

  if topics~topic(self~BENEFICIARY_STATE_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~BENEFICIARY_STATE_TOPIC, self~BENEFICIARY_STATE_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define beneficiary state topic")
  ignored = self~must(topics~grantTopicAccess(self~BENEFICIARY_STATE_TOPIC, self~ACCOUNT_WORKER, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant beneficiary-state publish")
  ignored = self~must(topics~grantTopicAccess(self~BENEFICIARY_STATE_TOPIC, self~ACCOUNT_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant account beneficiary-state browse")
  ignored = self~must(topics~grantTopicAccess(self~BENEFICIARY_STATE_TOPIC, self~PAYMENTS_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant payments beneficiary-state browse")
  if topics~subscription("FB.BENEFICIARIES.TO.PAYMENTS") == .nil then ignored = self~must(topics~subscribe("FB.BENEFICIARIES.TO.PAYMENTS", self~BENEFICIARY_STATE_TOPIC, "#", self~BENEFICIARY_TO_PAYMENTS, lifecycle, self~ADMIN_PRINCIPAL), "subscribe Payments to beneficiary state")

::method manager
  expose manager
  return manager
::method topics
  expose topics
  return topics
::method persistent
  expose persistent
  return persistent
::method publishAccountProjection
  expose topics persistent
  use arg projection, correlationId = ""
  if projection == .nil then return .QueueOperationResult~failure("ACCOUNT_PROJECTION_REQUIRED")
  schema = projection["schema"]~string
  options = .table~new
  options["retain"] = .true
  options["persistent"] = persistent
  if correlationId <> "" then options["correlationId"] = correlationId
  if schema = "federationbank.beneficiary.projection/0.4" then do
    beneficiaryId = projection["beneficiaryId"]~string
    customerId = projection["customerId"]~string
    if beneficiaryId = "" | customerId = "" then return .QueueOperationResult~failure("BENEFICIARY_PROJECTION_ID_REQUIRED")
    token = (customerId || "_" || beneficiaryId)~changestr("/", "_")~changestr(" ", "_")
    options["subtopic"] = "beneficiary/" || token
    return topics~publish(self~BENEFICIARY_STATE_TOPIC, projection, options, self~ACCOUNT_WORKER)
  end
  accountId = projection["accountId"]~string
  if accountId = "" then return .QueueOperationResult~failure("ACCOUNT_ID_REQUIRED")
  token = accountId~changestr("/", "_")~changestr(" ", "_")
  options["subtopic"] = "account/" || token
  return topics~publish(self~ACCOUNT_STATE_TOPIC, projection, options, self~ACCOUNT_WORKER)
::method must private
  use arg result, label
  if result~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_TOPOLOGY_FAILED", label, result~code, result~detail)
  return result
::method grant private
  expose manager
  use arg queueName, principal, action
  ignored = self~must(manager~grant(queueName, principal, action, self~ADMIN_PRINCIPAL), "grant " || queueName || " " || principal || " " || action)
  return .true


/* Durable, idempotent Payments rolling-usage projection.
 * One retained publication exists per committed banking transaction.  The
 * aggregate is rebuilt by summing retained facts, so a worker restart does
 * not reset corporate daily-limit usage.  Re-delivery of the same tx is a
 * no-op because transactionId is the retained concrete-topic identity. */
::class FederationBankPaymentsUsageProjection public
::method init
  expose topics totals applied
  use arg topicFabricArg
  if topicFabricArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_USAGE_TOPIC_FABRIC_REQUIRED")
  topics = topicFabricArg
  totals = .directory~new
  applied = .directory~new
  self~rebuild
::method safeToken private
  use arg value
  t = value~string
  t = t~changestr("/", "_")
  t = t~changestr(" ", "_")
  return t
::method dayKey private
  use arg customerId, currency, dayText
  return customerId~string || "|" || currency~string~upper || "|" || dayText~string
::method rebuild
  expose topics totals applied
  totals = .directory~new
  applied = .directory~new
  do publication over topics~retainedPublications
    if publication~topicName <> .FederationBankServiceTopology~USAGE_TOPIC then iterate
    p = publication~payload
    if p == .nil then iterate
    if \p~isA(.Directory) then iterate
    if \p~hasIndex("schema") then iterate
    if p["schema"] <> "federationbank.payments.usage-committed/0.3" then iterate
    tx = p["transactionId"]~string
    if tx = "" then iterate
    if applied~hasIndex(tx) then iterate
    day = p["day"]~string
    key = self~dayKey(p["customerId"], p["currency"], day)
    current = 0
    if totals~hasIndex(key) then current = totals[key]
    totals[key] = current + (p["amountMinor"] + 0)
    applied[tx] = p
  end
  return self
::method usedMinor
  expose totals
  use arg customerId, currency, atTime
  day = atTime~utcIsoDate~left(10)
  key = self~dayKey(customerId, currency, day)
  if totals~hasIndex(key) then return totals[key]
  return 0
::method hasTransaction
  expose applied
  use arg transactionId
  return applied~hasIndex(transactionId~string)
::method recordCommitted
  expose topics totals applied
  use arg customerId, currency, amountMinor, atTime, transactionId
  tx = transactionId~string
  if tx = "" then return .FederationBankResult~failure("USAGE_TRANSACTION_ID_REQUIRED")
  if applied~hasIndex(tx) then return .FederationBankResult~success(self~usedMinor(customerId, currency, atTime), "already projected")
  amount = amountMinor + 0
  if amount < 0 then return .FederationBankResult~failure("USAGE_AMOUNT_INVALID", amount)
  day = atTime~utcIsoDate~left(10)
  payload = .directory~new
  payload["schema"] = "federationbank.payments.usage-committed/0.3"
  payload["transactionId"] = tx
  payload["customerId"] = customerId~string
  payload["currency"] = currency~string~upper
  payload["day"] = day
  payload["amountMinor"] = amount
  payload["committedAt"] = atTime~utcIsoDate
  options = .table~new
  options["subtopic"] = "tx/" || self~safeToken(tx)
  options["retain"] = .true
  options["persistent"] = .true
  options["correlationId"] = tx
  published = topics~publish(.FederationBankServiceTopology~USAGE_TOPIC, payload, options, .FederationBankServiceTopology~PAYMENTS_WORKER)
  if published~ok = .false then return .FederationBankResult~failure("USAGE_EVENT_PUBLISH_FAILED", published~code || ":" || published~detail, published)
  key = self~dayKey(customerId, currency, day)
  current = 0
  if totals~hasIndex(key) then current = totals[key]
  totals[key] = current + amount
  applied[tx] = payload
  return .FederationBankResult~success(totals[key])


/* Account Engine: independent account-lifecycle service facade.
 * It wraps FederationBankAccountAuthority, not the legacy combined Engine.
 */
::class FederationBankAccountEngine public
::method init
  expose authority
  use arg accountAuthority
  if accountAuthority == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_AUTHORITY_REQUIRED")
  authority = accountAuthority
::method authority
  expose authority
  return authority
::method handle
  expose authority
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  select
    when command~operation = "OPEN_ACCOUNT" then nop
    when command~operation = "ADD_BENEFICIARY" then nop
    when command~operation = "AMEND_BENEFICIARY" then nop
    when command~operation = "SUSPEND_BENEFICIARY" then nop
    otherwise return .FederationBankResult~failure("ACCOUNT_ENGINE_OPERATION_UNSUPPORTED", command~operation)
  end
  return authority~handle(command)
::method projectionFrom
  use arg command, handledArg
  if handledArg == .nil then return .nil
  if handledArg~ok = .false then return .nil
  if command~operation = "OPEN_ACCOUNT" then do
    d = .directory~new
    d["schema"] = "federationbank.account.projection/0.3"
    d["customerId"] = command~customerId
    d["accountId"] = command~accountId
    d["currency"] = command~currency
    d["productCode"] = command~productCode
    d["bookingJurisdiction"] = .FederationBankBuild~BOOKING_JURISDICTION
    d["regulatoryProfileId"] = handledArg~value["regulatoryProfileId"]
    d["status"] = "OPEN"
    d["segment"] = command~applicantSegment
    d["domicile"] = command~applicantDomicile
    d["residence"] = command~applicantResidence
    d["riskTier"] = command~applicantRiskTier
    d["legalName"] = command~legalName
    d["dateOfBirth"] = command~dateOfBirth
    d["postcode"] = command~postcode
    d["addressCountry"] = command~addressCountry
    d["limitPolicyId"] = .FederationBankBuild~LIMIT_POLICY_DEFAULT
    d["sourceCommandId"] = command~commandId
    d["sourceIdempotencyKey"] = command~idempotencyKey
    return d
  end
  d = .directory~new
  d["schema"] = "federationbank.beneficiary.projection/0.4"
  d["customerId"] = command~customerId
  d["accountId"] = command~accountId
  d["beneficiaryId"] = handledArg~value["beneficiaryId"]
  d["displayName"] = handledArg~value["beneficiaryDisplayName"]
  d["accountReference"] = handledArg~value["beneficiaryAccountReference"]
  d["bankCode"] = handledArg~value["beneficiaryBankCode"]
  d["country"] = handledArg~value["beneficiaryCountry"]
  d["currency"] = handledArg~value["beneficiaryCurrency"]
  d["status"] = handledArg~value["beneficiaryStatus"]
  d["version"] = handledArg~value["beneficiaryVersion"]
  d["updatedAt"] = handledArg~value["createdAt"]
  d["sourceCommandId"] = command~commandId
  d["sourceIdempotencyKey"] = command~idempotencyKey
  return d


/* Payments Engine owns customer-facing payment authority, never balances. */
::class FederationBankPaymentsEngine public
::method init
  expose customers accounts profiles policyGate legalGate bouncer usage beneficiaries feePolicyGate fxPolicyGate fxQuotePort
  use arg customersArg, accountsArg, profilesArg, policyGateArg, legalGateArg, bouncerArg, usageArg, beneficiariesArg = .nil, feePolicyGateArg = .nil, fxPolicyGateArg = .nil, fxQuotePortArg = .nil
  customers = customersArg
  accounts = accountsArg
  profiles = profilesArg
  policyGate = policyGateArg
  legalGate = legalGateArg
  bouncer = bouncerArg
  usage = usageArg
  if beneficiariesArg == .nil then beneficiaries = .FederationBankBeneficiaryRegistry~new
  else beneficiaries = beneficiariesArg
  feePolicyGate = feePolicyGateArg
  fxPolicyGate = fxPolicyGateArg
  fxQuotePort = fxQuotePortArg
::method beneficiaries
  expose beneficiaries
  return beneficiaries
::method rebuildAccountProjections
  use arg topicFabric
  if topicFabric == .nil then return .FederationBankResult~failure("ACCOUNT_TOPIC_FABRIC_REQUIRED")
  count = 0
  do publication over topicFabric~retainedPublications
    if publication~topicName <> .FederationBankServiceTopology~ACCOUNT_STATE_TOPIC then iterate
    applied = self~applyAccountProjection(publication~payload)
    if applied~ok = .false then return applied
    count += 1
  end
  return .FederationBankResult~success(count)
::method applyAccountProjection
  expose customers accounts
  use arg p
  if p == .nil then return .FederationBankResult~failure("ACCOUNT_PROJECTION_REQUIRED")
  if p["schema"] <> "federationbank.account.projection/0.3" then return .FederationBankResult~failure("ACCOUNT_PROJECTION_SCHEMA_INVALID")
  customer = customers~customer(p["customerId"])
  if customer == .nil then do
    customer = .FederationBankCustomer~new(p["customerId"], p["segment"], p["domicile"], p["residence"], p["riskTier"], p["limitPolicyId"], p["legalName"], p["dateOfBirth"], p["postcode"], p["addressCountry"])
    addedCustomer = customers~add(customer)
    if addedCustomer~ok = .false then return addedCustomer
  end
  if accounts~account(p["accountId"]) == .nil then do
    account = .FederationBankAccount~new(p["accountId"], p["customerId"], p["currency"], p["productCode"], p["bookingJurisdiction"], p["regulatoryProfileId"])
    added = accounts~addAccount(account)
    if added~ok = .false then return added
  end
  return .FederationBankResult~success(.true)
::method rebuildBeneficiaryProjections
  use arg topicFabric
  if topicFabric == .nil then return .FederationBankResult~failure("BENEFICIARY_TOPIC_FABRIC_REQUIRED")
  count = 0
  do publication over topicFabric~retainedPublications
    if publication~topicName <> .FederationBankServiceTopology~BENEFICIARY_STATE_TOPIC then iterate
    applied = self~applyBeneficiaryProjection(publication~payload)
    if applied~ok = .false then return applied
    count += 1
  end
  return .FederationBankResult~success(count)
::method applyBeneficiaryProjection
  expose beneficiaries accounts
  use arg p
  if p == .nil then return .FederationBankResult~failure("BENEFICIARY_PROJECTION_REQUIRED")
  if \p~isA(.Directory) then return .FederationBankResult~failure("BENEFICIARY_PROJECTION_INVALID")
  if p["schema"] <> "federationbank.beneficiary.projection/0.4" then return .FederationBankResult~failure("BENEFICIARY_PROJECTION_SCHEMA_INVALID")
  if accounts~account(p["accountId"]) == .nil then return .FederationBankResult~failure("BENEFICIARY_OWNER_ACCOUNT_PROJECTION_MISSING", p["accountId"])
  iso = p["updatedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  if iso = "" then atTime = .DateTime~new
  else atTime = .DateTime~fromIsoDate(iso)
  beneficiary = .FederationBankBeneficiary~new(p["beneficiaryId"], p["customerId"], p["accountId"], p["displayName"], p["accountReference"], p["bankCode"], p["country"], p["currency"], p["status"], p["version"], atTime)
  return beneficiaries~upsert(beneficiary)
::method authorizeTransfer
  expose customers accounts profiles policyGate legalGate bouncer usage feePolicyGate
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "TRANSFER" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  source = accounts~account(command~sourceAccountId)
  target = accounts~account(command~targetAccountId)
  security = bouncer~evaluate(command, source, target, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if source == .nil | target == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND")
  profile = profiles~byCurrency(source~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", source~currency)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  feeAmount = 0
  feeClass = "NONE"
  feePolicyId = ""
  feePolicyVersion = ""
  feePolicyRuleId = ""
  feePolicyIdentity = ""
  if feePolicyGate <> .nil then do
    fee = feePolicyGate~evaluate(command, customer)
    if fee~ok = .false then return fee
    feeAmount = fee~value["feeAmountMinor"] + 0
    feeClass = fee~value["feeClass"]
    feePolicyId = fee~value["policyId"]
    feePolicyVersion = fee~value["policyVersion"]
    feePolicyRuleId = fee~value["ruleId"]
    feePolicyIdentity = fee~value["policyIdentity"]
  end
  legalFacts = .directory~new
  legalFacts["feeAmountMinor"] = feeAmount
  legalFacts["feeClass"] = feeClass
  legal = legalGate~evaluate(command, customer, source, profile, legalFacts)
  if legal~ok = .false then return legal

  d = command~asPayload
  if feePolicyGate == .nil then d["schema"] = "federationbank.ledger.post-transfer/0.3"
  else d["schema"] = "federationbank.ledger.post-transfer/0.6"
  d["transactionId"] = command~idempotencyKey
  d["securityPolicyId"] = assessment~policy~policyId
  d["securityPolicyVersion"] = assessment~policy~version
  d["securityDisposition"] = assessment~disposition
  d["securityTraceIdentity"] = assessment~trace~traceIdentity
  d["corporatePolicyId"] = policy~value["policyId"]
  d["corporatePolicyVersion"] = policy~value["policyVersion"]
  d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["feePolicyId"] = feePolicyId
  d["feePolicyVersion"] = feePolicyVersion
  d["feePolicyRuleId"] = feePolicyRuleId
  d["feePolicyIdentity"] = feePolicyIdentity
  d["feeAmountMinor"] = feeAmount
  d["feeClass"] = feeClass
  d["totalDebitMinor"] = command~amountMinor + feeAmount
  d["dailyUsageBeforeMinor"] = dailyBefore
  d["legalProfileId"] = legal~value["legalProfileId"]
  d["legalGenerationId"] = legal~value["generationId"]
  d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId
  d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true, "PAYMENT_AUTHORISED", "Awaiting Ledger commit", d)
::method authorizeFx
  expose customers accounts profiles policyGate legalGate bouncer usage fxPolicyGate fxQuotePort
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "FX_CONVERT" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  if fxPolicyGate == .nil | fxQuotePort == .nil then return .FederationBankResult~failure("FX_SERVICE_UNAVAILABLE")
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  source = accounts~account(command~sourceAccountId)
  target = accounts~account(command~targetAccountId)
  security = bouncer~evaluateFx(command, source, target, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if source == .nil | target == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND")
  sourceProfile = profiles~byCurrency(source~currency)
  targetProfile = profiles~byCurrency(target~currency)
  if sourceProfile == .nil | targetProfile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND")
  dailyBefore = usage~usedMinor(customer~customerId, source~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  fxPolicy = fxPolicyGate~evaluate(command, customer, target~currency)
  if fxPolicy~ok = .false then return fxPolicy
  if fxPolicy~value["allowed"] = .false then return .FederationBankResult~failure("FX_POLICY_DENIED", fxPolicy~value["reason"] || ":" || fxPolicy~value["ruleId"], fxPolicy~value)
  quoted = fxQuotePort~quote(command, source, target)
  if quoted~ok = .false then return quoted
  quote = quoted~value
  if quote~sourceCurrency <> source~currency | quote~targetCurrency <> target~currency then return .FederationBankResult~failure("FX_QUOTE_PAIR_MISMATCH")
  if quote~validUntil < command~requestedAt then return .FederationBankResult~failure("FX_QUOTE_EXPIRED", quote~quoteId)
  targetAmount = quote~targetAmountMinor(command~amountMinor, fxPolicy~value["markupBasisPoints"])
  if targetAmount <= 0 then return .FederationBankResult~failure("FX_TARGET_AMOUNT_INVALID")
  legalFacts = .directory~new
  legalFacts["targetCurrency"] = target~currency
  legalFacts["fxQuoteId"] = quote~quoteId
  sourceLegal = legalGate~evaluate(command, customer, source, sourceProfile, legalFacts)
  if sourceLegal~ok = .false then return sourceLegal
  targetCommand = .FederationBankCommand~new(command~commandId || "-TARGET", "FX_CONVERT", command~idempotencyKey, command~customerId, target~accountId, source~accountId, target~currency, targetAmount, command~channel, command~actorId, command~requestedAt, "", "", "", "", "", "", "", customer~residence, customer~domicile, customer~segment, customer~riskTier, command~details)
  targetLegal = legalGate~evaluate(targetCommand, customer, target, targetProfile, legalFacts)
  if targetLegal~ok = .false then return targetLegal
  d = command~asPayload
  d["schema"] = "federationbank.ledger.fx/0.7"
  d["transactionId"] = command~idempotencyKey
  d["targetCurrency"] = target~currency
  d["targetAmountMinor"] = targetAmount
  d["securityPolicyId"] = assessment~policy~policyId
  d["securityPolicyVersion"] = assessment~policy~version
  d["securityDisposition"] = assessment~disposition
  d["corporatePolicyId"] = policy~value["policyId"]
  d["corporatePolicyVersion"] = policy~value["policyVersion"]
  d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["fxPolicyId"] = fxPolicy~value["policyId"]
  d["fxPolicyVersion"] = fxPolicy~value["policyVersion"]
  d["fxPolicyRuleId"] = fxPolicy~value["ruleId"]
  d["fxMarkupBasisPoints"] = fxPolicy~value["markupBasisPoints"]
  d["fxQuoteId"] = quote~quoteId
  d["fxQuoteProviderId"] = quote~providerId
  d["fxRateNumerator"] = quote~rateNumerator
  d["fxRateDenominator"] = quote~rateDenominator
  d["legalProfileId"] = sourceLegal~value["legalProfileId"]
  d["legalGenerationId"] = sourceLegal~value["generationId"]
  d["legalGenerationVersion"] = sourceLegal~value["generationVersion"]
  d["regulatoryProfileId"] = sourceProfile~profileId
  d["targetLegalProfileId"] = targetLegal~value["legalProfileId"]
  d["targetLegalGenerationId"] = targetLegal~value["generationId"]
  d["targetLegalGenerationVersion"] = targetLegal~value["generationVersion"]
  d["targetRegulatoryProfileId"] = targetProfile~profileId
  d["dailyUsageBeforeMinor"] = dailyBefore
  d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true, "FX_AUTHORISED", "Awaiting Ledger multi-currency commit", d)

::method authorizeOfflineAuthority
  expose customers accounts profiles policyGate legalGate bouncer usage
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "ATM_OFFLINE_AUTHORITY_ISSUE" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  account = accounts~account(command~sourceAccountId)
  security = bouncer~evaluateOfflineAuthorityIssue(command, account, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND", command~sourceAccountId)
  profile = profiles~byCurrency(account~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", account~currency)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legalFacts = .directory~new; legalFacts["authorityMode"] = command~detail("authorityMode")
  legal = legalGate~evaluate(command, customer, account, profile, legalFacts)
  if legal~ok = .false then return legal
  d = command~asPayload
  d["schema"] = "federationbank.atm.offline-authority-decision/0.9"
  d["authorityMode"] = command~detail("authorityMode")~string~upper
  d["terminalId"] = command~detail("terminalId")
  d["atmNetworkId"] = command~detail("atmNetworkId")
  d["rulesetId"] = command~detail("rulesetId")
  d["rulesVersion"] = command~detail("rulesVersion")
  d["securityPolicyId"] = assessment~policy~policyId
  d["securityPolicyVersion"] = assessment~policy~version
  d["securityDisposition"] = assessment~disposition
  d["corporatePolicyId"] = policy~value["policyId"]
  d["corporatePolicyVersion"] = policy~value["policyVersion"]
  d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["legalProfileId"] = legal~value["legalProfileId"]
  d["legalGenerationId"] = legal~value["generationId"]
  d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId
  d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true, "ATM_OFFLINE_AUTHORITY_AUTHORISED", "Bounded offline ATM authority may be issued", d)

::method authorizeOfflineCashAdvice
  expose customers accounts profiles policyGate legalGate bouncer usage
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "OFFLINE_WITHDRAWAL_ADVICE" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  account = accounts~account(command~sourceAccountId)
  security = bouncer~evaluateOfflineCashAdvice(command, account, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND", command~sourceAccountId)
  profile = profiles~byCurrency(account~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", account~currency)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legalFacts = .directory~new
  legalFacts["debitAuthority"] = .FederationBankDebitAuthority~SETTLEMENT_MUST_POST
  legal = legalGate~evaluate(command, customer, account, profile, legalFacts)
  if legal~ok = .false then return legal
  d = command~asPayload
  d["schema"] = "federationbank.ledger.offline-cash/0.7"
  d["transactionId"] = command~idempotencyKey
  d["debitAuthority"] = .FederationBankDebitAuthority~SETTLEMENT_MUST_POST
  do key over .array~of("terminalId", "atmNetworkId", "offlineAuthorityId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence", "dispensedMinor", "authorityMode", "dispensedAt", "adviceReceivedAt", "authorityIssuedAt", "authorityExpiresAt", "authorityIssuedTerminalSequence", "reconciliationWindowSeconds", "terminalClockSkewSeconds", "offlineEvidenceDisposition", "recoverySessionId")
    d[key] = command~detail(key)
  end
  d["securityPolicyId"] = assessment~policy~policyId
  d["securityPolicyVersion"] = assessment~policy~version
  d["securityDisposition"] = assessment~disposition
  d["corporatePolicyId"] = policy~value["policyId"]
  d["corporatePolicyVersion"] = policy~value["policyVersion"]
  d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["legalProfileId"] = legal~value["legalProfileId"]
  d["legalGenerationId"] = legal~value["generationId"]
  d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId
  d["dailyUsageBeforeMinor"] = dailyBefore
  d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true, "OFFLINE_CASH_ADVICE_AUTHORISED", "Physical cash fact must be settled by Ledger", d)

::method authorizeAtmWithdrawalCommit
  expose customers accounts profiles policyGate legalGate bouncer usage
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "WITHDRAW_COMMIT" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  account = accounts~account(command~sourceAccountId)
  security = bouncer~evaluateAtmPhysical(command, account, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  profile = profiles~byCurrency(command~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", command~currency)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legal = legalGate~evaluate(command, customer, account, profile)
  if legal~ok = .false then return legal
  d = command~asPayload
  d["schema"] = "federationbank.ledger.atm-withdrawal/0.8"
  d["transactionId"] = command~idempotencyKey
  d["debitAuthority"] = .FederationBankDebitAuthority~RESERVATION_CONSUME
  do key over .array~of("terminalId","atmNetworkId","rulesetId","rulesVersion","physicalTransactionId","terminalSequence","authorizationId","holdId","dispensedMinor","dispensedAt","adviceReceivedAt","authorityIssuedAt","authorityExpiresAt","authorityIssuedTerminalSequence","reconciliationWindowSeconds","terminalClockSkewSeconds","offlineEvidenceDisposition","recoverySessionId")
    d[key] = command~detail(key)
  end
  d["securityPolicyId"] = assessment~policy~policyId; d["securityPolicyVersion"] = assessment~policy~version; d["securityDisposition"] = assessment~disposition
  d["corporatePolicyId"] = policy~value["policyId"]; d["corporatePolicyVersion"] = policy~value["policyVersion"]; d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["legalProfileId"] = legal~value["legalProfileId"]; d["legalGenerationId"] = legal~value["generationId"]; d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId; d["dailyUsageBeforeMinor"] = dailyBefore; d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true,"ATM_WITHDRAWAL_COMMIT_AUTHORISED","Awaiting Ledger reservation consumption",d)

::method authorizeAtmDepositCommit
  expose customers accounts profiles policyGate legalGate bouncer
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "DEPOSIT_COMMIT" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  account = accounts~account(command~sourceAccountId)
  security = bouncer~evaluateAtmPhysical(command, account, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED",assessment~disposition,assessment)
  profile = profiles~byCurrency(command~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND",command~currency)
  policy = policyGate~evaluate(command, customer, 0)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED",policy~value["reason"] || ":" || policy~value["ruleId"],policy~value)
  legal = legalGate~evaluate(command, customer, account, profile)
  if legal~ok = .false then return legal
  d = command~asPayload; d["schema"] = "federationbank.ledger.atm-deposit/0.8"; d["transactionId"] = command~idempotencyKey
  do key over .array~of("terminalId","atmNetworkId","rulesetId","rulesVersion","physicalTransactionId","terminalSequence")
    d[key] = command~detail(key)
  end
  d["securityPolicyId"] = assessment~policy~policyId; d["securityPolicyVersion"] = assessment~policy~version; d["securityDisposition"] = assessment~disposition
  d["corporatePolicyId"] = policy~value["policyId"]; d["corporatePolicyVersion"] = policy~value["policyVersion"]; d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["legalProfileId"] = legal~value["legalProfileId"]; d["legalGenerationId"] = legal~value["generationId"]; d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId; d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true,"ATM_DEPOSIT_COMMIT_AUTHORISED","Awaiting Ledger physical-cash deposit commit",d)

::method authorizeHold
  expose customers accounts profiles policyGate legalGate bouncer usage
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~operation <> "PLACE_HOLD" & command~operation <> "RELEASE_HOLD" then return .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  account = accounts~account(command~sourceAccountId)
  security = bouncer~evaluateHold(command, account, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND", command~sourceAccountId)
  profile = profiles~byCurrency(account~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", account~currency)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legal = legalGate~evaluate(command, customer, account, profile)
  if legal~ok = .false then return legal
  d = command~asPayload
  d["schema"] = "federationbank.ledger.hold/0.5"
  d["holdId"] = command~detail("holdId")
  d["securityPolicyId"] = assessment~policy~policyId
  d["securityPolicyVersion"] = assessment~policy~version
  d["securityDisposition"] = assessment~disposition
  d["securityTraceIdentity"] = assessment~trace~traceIdentity
  d["corporatePolicyId"] = policy~value["policyId"]
  d["corporatePolicyVersion"] = policy~value["policyVersion"]
  d["corporatePolicyRuleId"] = policy~value["ruleId"]
  d["legalProfileId"] = legal~value["legalProfileId"]
  d["legalGenerationId"] = legal~value["generationId"]
  d["legalGenerationVersion"] = legal~value["generationVersion"]
  d["regulatoryProfileId"] = profile~profileId
  d["authorisedAt"] = .DateTime~new~utcIsoDate
  return .FederationBankResult~new(.true, "HOLD_AUTHORISED", "Awaiting Ledger reservation commit", d)
::method completeAtmWithdrawalResult
  expose usage
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.atm-withdrawal-result/0.8" then return .FederationBankResult~failure("LEDGER_ATM_WITHDRAWAL_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"],ledgerResult["detail"],ledgerResult)
  iso=ledgerResult["requestedAt"]~string; if iso~right(1)="Z" then iso=iso~left(iso~length-1)
  projected=usage~recordCommitted(ledgerResult["customerId"],ledgerResult["currency"],ledgerResult["amountMinor"],.DateTime~fromIsoDate(iso),ledgerResult["transactionId"])
  if projected~ok=.false then return projected
  out=ledgerResult~copy; out["dailyUsageAfterMinor"]=projected~value; out["outcome"]="ACCEPTED"
  return .FederationBankResult~new(.true,"ATM_WITHDRAWAL_COMMITTED","Ledger consumed ATM reservation after physical dispense",out)
::method completeAtmDepositResult
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.atm-deposit-result/0.8" then return .FederationBankResult~failure("LEDGER_ATM_DEPOSIT_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"],ledgerResult["detail"],ledgerResult)
  out=ledgerResult~copy; out["outcome"]="ACCEPTED"
  return .FederationBankResult~new(.true,"ATM_DEPOSIT_COMMITTED","Ledger recorded cash physically received by terminal",out)

::method completeFxResult
  expose usage
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.fx-result/0.7" then return .FederationBankResult~failure("LEDGER_FX_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"], ledgerResult["detail"], ledgerResult)
  iso = ledgerResult["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  atTime = .DateTime~fromIsoDate(iso)
  projected = usage~recordCommitted(ledgerResult["customerId"], ledgerResult["currency"], ledgerResult["amountMinor"], atTime, ledgerResult["transactionId"])
  if projected~ok = .false then return projected
  out = ledgerResult~copy
  out["dailyUsageAfterMinor"] = projected~value
  out["outcome"] = "ACCEPTED"
  return .FederationBankResult~new(.true, "FX_COMMITTED", "Ledger committed currency-balanced FX conversion", out)
::method completeOfflineCashResult
  expose usage
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.offline-cash-result/0.7" then return .FederationBankResult~failure("LEDGER_OFFLINE_CASH_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"], ledgerResult["detail"], ledgerResult)
  iso = ledgerResult["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  atTime = .DateTime~fromIsoDate(iso)
  projected = usage~recordCommitted(ledgerResult["customerId"], ledgerResult["currency"], ledgerResult["amountMinor"], atTime, ledgerResult["transactionId"])
  if projected~ok = .false then return projected
  out = ledgerResult~copy
  out["dailyUsageAfterMinor"] = projected~value
  out["outcome"] = "ACCEPTED"
  return .FederationBankResult~new(.true, "OFFLINE_CASH_SETTLED", "Ledger recorded cash already dispensed under delegated authority", out)
::method completeHoldResult
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.hold-result/0.5" then return .FederationBankResult~failure("LEDGER_HOLD_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"], ledgerResult["detail"], ledgerResult)
  out = ledgerResult~copy
  out["outcome"] = "ACCEPTED"
  if ledgerResult["operation"] = "PLACE_HOLD" then return .FederationBankResult~new(.true, "HOLD_PLACED", "Ledger committed reservation", out)
  return .FederationBankResult~new(.true, "HOLD_RELEASED", "Ledger released reservation", out)
::method completeLedgerResult
  expose usage
  use arg ledgerResult
  if ledgerResult == .nil then return .FederationBankResult~failure("LEDGER_RESULT_REQUIRED")
  if ledgerResult["schema"] <> "federationbank.ledger.result/0.3" & ledgerResult["schema"] <> "federationbank.ledger.result/0.6" then return .FederationBankResult~failure("LEDGER_RESULT_SCHEMA_INVALID")
  if ledgerResult["ok"] = .false then return .FederationBankResult~failure(ledgerResult["code"], ledgerResult["detail"], ledgerResult)
  iso = ledgerResult["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  atTime = .DateTime~fromIsoDate(iso)
  projected = usage~recordCommitted(ledgerResult["customerId"], ledgerResult["currency"], ledgerResult["amountMinor"], atTime, ledgerResult["transactionId"])
  if projected~ok = .false then return projected
  out = ledgerResult~copy
  out["dailyUsageAfterMinor"] = projected~value
  out["outcome"] = "ACCEPTED"
  return .FederationBankResult~new(.true, "TRANSFER_COMMITTED", "Ledger committed transfer", out)


/* Ledger Engine is intentionally boring.  It accepts only internal posting
 * instructions whose policy/legal/security evidence is already attached,
 * then makes monetary truth atomically in DB Skeleton. */
::class FederationBankLedgerEngine public
::method init
  expose ledger profiles
  use arg ledgerArg, profilesArg
  ledger = ledgerArg
  profiles = profilesArg
::method rebuildAccountProjections
  use arg topicFabric
  if topicFabric == .nil then return .FederationBankResult~failure("ACCOUNT_TOPIC_FABRIC_REQUIRED")
  count = 0
  do publication over topicFabric~retainedPublications
    if publication~topicName <> .FederationBankServiceTopology~ACCOUNT_STATE_TOPIC then iterate
    applied = self~applyAccountProjection(publication~payload)
    if applied~ok = .false then return applied
    count += 1
  end
  return .FederationBankResult~success(count)
::method applyAccountProjection
  expose ledger
  use arg p
  if p == .nil then return .FederationBankResult~failure("ACCOUNT_PROJECTION_REQUIRED")
  if p["schema"] <> "federationbank.account.projection/0.3" then return .FederationBankResult~failure("ACCOUNT_PROJECTION_SCHEMA_INVALID")
  if ledger~account(p["accountId"]) <> .nil then return .FederationBankResult~success(.true, "already projected")
  account = .FederationBankAccount~new(p["accountId"], p["customerId"], p["currency"], p["productCode"], p["bookingJurisdiction"], p["regulatoryProfileId"])
  return ledger~addAccount(account)
::method manageHold
  expose ledger profiles
  use arg instruction
  if instruction == .nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"] <> "federationbank.ledger.hold/0.5" then return .FederationBankResult~failure("LEDGER_HOLD_INSTRUCTION_SCHEMA_INVALID")
  op = instruction["operation"]~string~upper
  if op <> "PLACE_HOLD" & op <> "RELEASE_HOLD" then return .FederationBankResult~failure("LEDGER_HOLD_OPERATION_INVALID", op)
  profile = profiles~byCurrency(instruction["currency"])
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", instruction["currency"])
  if instruction["regulatoryProfileId"] <> profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  if ledger~store <> .nil then do
    recovered = ledger~store~recoverReceipt(instruction["idempotencyKey"])
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      if recovered~value["operation"] <> op then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION", recovered~value["operation"] || "/" || op)
      h = ledger~hold(instruction["holdId"])
      if h == .nil then do
        hydrated = ledger~hydrateHoldsFromStore
        if hydrated~ok = .false then return hydrated
        h = ledger~hold(instruction["holdId"])
      end
      if h == .nil then return .FederationBankResult~failure("HOLD_REPLAY_STATE_MISSING", instruction["holdId"])
      out = instruction~copy
      out["schema"] = "federationbank.ledger.hold-result/0.5"
      out["ok"] = .true
      out["code"] = "HOLD_REPLAY_RECOVERED"
      out["detail"] = "durable Ledger hold receipt recovered"
      hd = h~asDirectory
      do key over hd
        out[key] = hd[key]
      end
      out["bookBalanceMinor"] = ledger~balanceMinor(h~accountId)
      out["availableBalanceMinor"] = ledger~availableBalanceMinor(h~accountId)
      out["recoveredFromDurableReceipt"] = "true"
      return .FederationBankResult~success(out)
    end
  end
  evidence = .directory~new
  do key over .array~of("securityPolicyId", "securityPolicyVersion", "securityDisposition", "corporatePolicyId", "corporatePolicyVersion", "corporatePolicyRuleId", "legalProfileId", "legalGenerationId", "legalGenerationVersion", "regulatoryProfileId")
    evidence[key] = instruction[key]
  end
  receipt = instruction~copy
  receipt["outcome"] = "ACCEPTED"
  receipt["transactionId"] = instruction["holdId"]
  receipt["accountId"] = instruction["sourceAccountId"]
  receipt["createdAt"] = instruction["requestedAt"]
  iso = instruction["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  atTime = .DateTime~fromIsoDate(iso)
  if op = "PLACE_HOLD" then changed = ledger~placeHold(instruction["holdId"], instruction["sourceAccountId"], instruction["customerId"], instruction["amountMinor"], instruction["currency"], atTime, evidence, receipt)
  else changed = ledger~releaseHold(instruction["holdId"], instruction["customerId"], atTime, evidence, receipt)
  if changed~ok = .false then return changed
  out = instruction~copy
  out["schema"] = "federationbank.ledger.hold-result/0.5"
  out["ok"] = .true
  out["code"] = op || "_COMMITTED"
  out["detail"] = "Ledger reservation state committed"
  do key over changed~value
    out[key] = changed~value[key]
  end
  return .FederationBankResult~success(out)
::method feeIncomeAccountId
  use arg currency, feeClass = "STANDARD_TRANSFER"
  cur = currency~string~upper
  classToken = feeClass~string~upper~changestr("/", "_")~changestr(" ", "_")
  if classToken = "" | classToken = "NONE" then classToken = "STANDARD_TRANSFER"
  return "FB-FEE-INCOME-" || cur || "-" || classToken
::method ensureFeeIncomeAccount private
  expose ledger profiles
  use arg currency, feeClass
  accountId = self~feeIncomeAccountId(currency, feeClass)
  existing = ledger~account(accountId)
  if existing <> .nil then return .FederationBankResult~success(existing)
  profile = profiles~byCurrency(currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", currency)
  account = .FederationBankAccount~new(accountId, "FEDERATIONBANK", currency, "INTERNAL_FEE_INCOME", .FederationBankBuild~BOOKING_JURISDICTION, profile~profileId, .true, .true)
  added = ledger~addAccount(account)
  if added~ok = .false then return added
  return .FederationBankResult~success(account)
::method fxPositionAccountId
  use arg currency
  return "FB-FX-POSITION-" || currency~string~upper
::method ensureFxPositionAccount private
  expose ledger profiles
  use arg currency
  accountId = self~fxPositionAccountId(currency)
  existing = ledger~account(accountId)
  if existing <> .nil then return .FederationBankResult~success(existing)
  profile = profiles~byCurrency(currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", currency)
  account = .FederationBankAccount~new(accountId, "FEDERATIONBANK", currency, "INTERNAL_FX_POSITION", .FederationBankBuild~BOOKING_JURISDICTION, profile~profileId, .true, .true)
  added = ledger~addAccount(account)
  if added~ok = .false then return added
  return .FederationBankResult~success(account)
::method atmCashAccountId
  use arg terminalId, currency
  token = terminalId~string~upper~changestr("/", "_")~changestr(" ", "_")~changestr("-", "_")
  return "FB-ATM-CASH-" || token || "-" || currency~string~upper
::method ensureAtmCashAccount private
  expose ledger profiles
  use arg terminalId, currency
  accountId = self~atmCashAccountId(terminalId, currency)
  existing = ledger~account(accountId)
  if existing <> .nil then return .FederationBankResult~success(existing)
  profile = profiles~byCurrency(currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", currency)
  account = .FederationBankAccount~new(accountId, "FEDERATIONBANK", currency, "INTERNAL_ATM_CASH", .FederationBankBuild~BOOKING_JURISDICTION, profile~profileId, .true, .true)
  added = ledger~addAccount(account)
  if added~ok = .false then return added
  return .FederationBankResult~success(account)
::method queryHold
  expose ledger
  use arg holdId
  h=ledger~hold(holdId)
  if h==.nil & ledger~store<>.nil then do
    hydrated=ledger~hydrateHoldsFromStore
    if \hydrated~ok then return hydrated
    h=ledger~hold(holdId)
  end
  if h==.nil then return .FederationBankResult~failure("HOLD_NOT_FOUND",holdId)
  return .FederationBankResult~success(h~asDirectory)
::method queryTransactionStatus
  expose ledger
  use arg idempotencyKey
  if ledger~store==.nil then return .FederationBankResult~new(.true,"TRANSACTION_UNKNOWN","",.directory~new)
  r=ledger~store~recoverReceipt(idempotencyKey)
  if \r~ok then return r
  if r~value==.nil then return .FederationBankResult~new(.true,"TRANSACTION_UNKNOWN","",.directory~new)
  d=.directory~new; d["kind"]=r~value["operation"]; d["bankTransactionId"]=r~value["transactionId"]; d["idempotencyKey"]=idempotencyKey; d["outcome"]=r~value["outcome"]
  return .FederationBankResult~new(.true,"TRANSACTION_COMMITTED","",d)
::method postFx
  expose ledger profiles
  use arg instruction
  if instruction == .nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"] <> "federationbank.ledger.fx/0.7" then return .FederationBankResult~failure("LEDGER_FX_INSTRUCTION_SCHEMA_INVALID")
  tx = instruction["transactionId"]~string
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  sourceProfile = profiles~byCurrency(instruction["currency"])
  targetProfile = profiles~byCurrency(instruction["targetCurrency"])
  if sourceProfile == .nil | targetProfile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND")
  if instruction["regulatoryProfileId"] <> sourceProfile~profileId | instruction["targetRegulatoryProfileId"] <> targetProfile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  sourcePositionResult = self~ensureFxPositionAccount(instruction["currency"])
  if sourcePositionResult~ok = .false then return sourcePositionResult
  targetPositionResult = self~ensureFxPositionAccount(instruction["targetCurrency"])
  if targetPositionResult~ok = .false then return targetPositionResult
  if ledger~store <> .nil then do
    recovered = ledger~store~recoverReceipt(instruction["idempotencyKey"])
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      if recovered~value["operation"] <> "FX_CONVERT" then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION", recovered~value["operation"] || "/FX_CONVERT")
      if \ledger~hasTransaction(tx) then do
        hydrated = ledger~hydratePostingsFromStore
        if hydrated~ok = .false then return hydrated
      end
      if \ledger~hasTransaction(tx) then return .FederationBankResult~failure("FX_REPLAY_STATE_MISSING", tx)
      out = instruction~copy
      out["schema"] = "federationbank.ledger.fx-result/0.7"
      out["ok"] = .true
      out["code"] = "FX_REPLAY_RECOVERED"
      out["detail"] = "durable Ledger FX receipt recovered"
      out["sourceBalanceMinor"] = ledger~balanceMinor(instruction["sourceAccountId"])
      out["targetBalanceMinor"] = ledger~balanceMinor(instruction["targetAccountId"])
      out["recoveredFromDurableReceipt"] = "true"
      return .FederationBankResult~success(out)
    end
  end
  evidence = .directory~new
  do key over .array~of("securityPolicyId", "securityPolicyVersion", "securityDisposition", "corporatePolicyId", "corporatePolicyVersion", "corporatePolicyRuleId", "fxPolicyId", "fxPolicyVersion", "fxPolicyRuleId", "fxQuoteId", "fxQuoteProviderId", "fxMarkupBasisPoints", "fxRateNumerator", "fxRateDenominator", "legalProfileId", "legalGenerationId", "legalGenerationVersion", "regulatoryProfileId", "targetLegalProfileId", "targetLegalGenerationId", "targetLegalGenerationVersion", "targetRegulatoryProfileId")
    evidence[key] = instruction[key]
  end
  receipt = instruction~copy
  receipt["outcome"] = "ACCEPTED"
  receipt["operation"] = "FX_CONVERT"
  receipt["createdAt"] = instruction["requestedAt"]
  iso = instruction["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  postedAt = .DateTime~fromIsoDate(iso)
  posted = ledger~postFxConversion(tx, instruction["sourceAccountId"], instruction["targetAccountId"], instruction["amountMinor"], instruction["targetAmountMinor"], instruction["currency"], instruction["targetCurrency"], sourcePositionResult~value~accountId, targetPositionResult~value~accountId, postedAt, evidence, receipt)
  if posted~ok = .false then return posted
  out = instruction~copy
  out["schema"] = "federationbank.ledger.fx-result/0.7"
  out["ok"] = .true
  out["code"] = "FX_LEDGER_COMMITTED"
  out["detail"] = "multi-currency journal committed with per-currency balance"
  out["sourceBalanceMinor"] = ledger~balanceMinor(instruction["sourceAccountId"])
  out["targetBalanceMinor"] = ledger~balanceMinor(instruction["targetAccountId"])
  out["sourcePositionAccountId"] = sourcePositionResult~value~accountId
  out["targetPositionAccountId"] = targetPositionResult~value~accountId
  if posted~value~hasIndex("databaseTransactionId") then do
    out["databaseTransactionId"] = posted~value["databaseTransactionId"]
    out["databaseOutcome"] = posted~value["databaseOutcome"]
    out["databaseAttempts"] = posted~value["databaseAttempts"]
  end
  return .FederationBankResult~success(out)
::method queryBalance
  expose ledger
  use arg customerId, accountId
  account=ledger~account(accountId)
  if account==.nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND",accountId)
  if account~internalAccount | account~customerId<>customerId then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND_OR_NOT_OWNED",accountId)
  d=ledger~fundsState(accountId); d["accountId"]=account~accountId; d["currency"]=account~currency; d["asOf"]=.DateTime~new~utcIsoDate
  return .FederationBankResult~success(d)

::method postAtmWithdrawal
  expose ledger profiles
  use arg instruction
  if instruction==.nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"]<>"federationbank.ledger.atm-withdrawal/0.8" then return .FederationBankResult~failure("LEDGER_ATM_WITHDRAWAL_SCHEMA_INVALID")
  if instruction["debitAuthority"]<>.FederationBankDebitAuthority~RESERVATION_CONSUME then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_INVALID")
  profile=profiles~byCurrency(instruction["currency"]); if profile==.nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND",instruction["currency"])
  if instruction["regulatoryProfileId"]<>profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  cashResult=self~ensureAtmCashAccount(instruction["terminalId"],instruction["currency"]); if cashResult~ok=.false then return cashResult
  tx=instruction["transactionId"]~string
  if ledger~store<>.nil then do
    recovered=ledger~store~recoverReceipt(instruction["idempotencyKey"]); if recovered~ok=.false then return recovered
    if recovered~value<>.nil then do
      if recovered~value["operation"]<>"WITHDRAW_COMMIT" then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION",recovered~value["operation"]||"/WITHDRAW_COMMIT")
      if \ledger~hasTransaction(tx) then do; hydrated=ledger~hydratePostingsFromStore; if hydrated~ok=.false then return hydrated; end
      hydratedHolds=ledger~hydrateHoldsFromStore; if hydratedHolds~ok=.false then return hydratedHolds
      if \ledger~hasTransaction(tx) then return .FederationBankResult~failure("ATM_REPLAY_STATE_MISSING",tx)
      out=instruction~copy; out["schema"]="federationbank.ledger.atm-withdrawal-result/0.8"; out["ok"]=.true; out["code"]="ATM_WITHDRAWAL_REPLAY_RECOVERED"; out["detail"]="durable ATM withdrawal receipt recovered"
      fs=ledger~fundsState(instruction["sourceAccountId"]); do key over fs; out[key]=fs[key]; end; out["recoveredFromDurableReceipt"]="true"
      return .FederationBankResult~success(out)
    end
  end
  evidence=.directory~new
  do key over .array~of("securityPolicyId","securityPolicyVersion","securityDisposition","corporatePolicyId","corporatePolicyVersion","corporatePolicyRuleId","legalProfileId","legalGenerationId","legalGenerationVersion","regulatoryProfileId","debitAuthority","terminalId","atmNetworkId","rulesetId","rulesVersion","physicalTransactionId","terminalSequence","authorizationId","holdId","dispensedAt","adviceReceivedAt","authorityIssuedAt","authorityExpiresAt","authorityIssuedTerminalSequence","reconciliationWindowSeconds","terminalClockSkewSeconds","offlineEvidenceDisposition","recoverySessionId")
    evidence[key]=instruction[key]
  end
  receipt=instruction~copy; receipt["outcome"]="ACCEPTED"; receipt["operation"]="WITHDRAW_COMMIT"; receipt["createdAt"]=instruction["requestedAt"]
  iso=instruction["requestedAt"]~string; if iso~right(1)="Z" then iso=iso~left(iso~length-1); postedAt=.DateTime~fromIsoDate(iso)
  posted=ledger~consumeAtmWithdrawalHold(tx,instruction["sourceAccountId"],cashResult~value~accountId,instruction["holdId"],instruction["amountMinor"],instruction["currency"],postedAt,evidence,receipt)
  if posted~ok=.false then return posted
  out=instruction~copy; out["schema"]="federationbank.ledger.atm-withdrawal-result/0.8"; out["ok"]=.true; out["code"]="ATM_WITHDRAWAL_COMMITTED"; out["detail"]="reservation consumed after physical cash dispense"
  do key over posted~value; if key~string~upper<>"POSTINGS" then out[key]=posted~value[key]; end
  return .FederationBankResult~success(out)

::method postAtmDeposit
  expose ledger profiles
  use arg instruction
  if instruction==.nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"]<>"federationbank.ledger.atm-deposit/0.8" then return .FederationBankResult~failure("LEDGER_ATM_DEPOSIT_SCHEMA_INVALID")
  profile=profiles~byCurrency(instruction["currency"]); if profile==.nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND",instruction["currency"])
  if instruction["regulatoryProfileId"]<>profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  cashResult=self~ensureAtmCashAccount(instruction["terminalId"],instruction["currency"]); if cashResult~ok=.false then return cashResult
  tx=instruction["transactionId"]~string
  if ledger~store<>.nil then do
    recovered=ledger~store~recoverReceipt(instruction["idempotencyKey"]); if recovered~ok=.false then return recovered
    if recovered~value<>.nil then do
      if recovered~value["operation"]<>"DEPOSIT_COMMIT" then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION",recovered~value["operation"]||"/DEPOSIT_COMMIT")
      if \ledger~hasTransaction(tx) then do; hydrated=ledger~hydratePostingsFromStore; if hydrated~ok=.false then return hydrated; end
      if \ledger~hasTransaction(tx) then return .FederationBankResult~failure("ATM_DEPOSIT_REPLAY_STATE_MISSING",tx)
      out=instruction~copy; out["schema"]="federationbank.ledger.atm-deposit-result/0.8"; out["ok"]=.true; out["code"]="ATM_DEPOSIT_REPLAY_RECOVERED"; out["detail"]="durable ATM deposit receipt recovered"
      fs=ledger~fundsState(instruction["sourceAccountId"]); do key over fs; out[key]=fs[key]; end; out["recoveredFromDurableReceipt"]="true"
      return .FederationBankResult~success(out)
    end
  end
  evidence=.directory~new
  do key over .array~of("securityPolicyId","securityPolicyVersion","securityDisposition","corporatePolicyId","corporatePolicyVersion","corporatePolicyRuleId","legalProfileId","legalGenerationId","legalGenerationVersion","regulatoryProfileId","terminalId","atmNetworkId","rulesetId","rulesVersion","physicalTransactionId","terminalSequence")
    evidence[key]=instruction[key]
  end
  receipt=instruction~copy; receipt["outcome"]="ACCEPTED"; receipt["operation"]="DEPOSIT_COMMIT"; receipt["createdAt"]=instruction["requestedAt"]
  iso=instruction["requestedAt"]~string; if iso~right(1)="Z" then iso=iso~left(iso~length-1); postedAt=.DateTime~fromIsoDate(iso)
  posted=ledger~postAtmDeposit(tx,cashResult~value~accountId,instruction["sourceAccountId"],instruction["amountMinor"],instruction["currency"],postedAt,evidence,receipt)
  if posted~ok=.false then return posted
  out=instruction~copy; out["schema"]="federationbank.ledger.atm-deposit-result/0.8"; out["ok"]=.true; out["code"]="ATM_DEPOSIT_COMMITTED"; out["detail"]="physical cash receipt committed to Ledger"
  do key over posted~value; if key~string~upper<>"POSTINGS" then out[key]=posted~value[key]; end
  return .FederationBankResult~success(out)

::method postOfflineCashAdvice
  expose ledger profiles
  use arg instruction
  if instruction == .nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"] <> "federationbank.ledger.offline-cash/0.7" then return .FederationBankResult~failure("LEDGER_OFFLINE_CASH_SCHEMA_INVALID")
  if instruction["debitAuthority"] <> .FederationBankDebitAuthority~SETTLEMENT_MUST_POST then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_INVALID")
  tx = instruction["transactionId"]~string
  profile = profiles~byCurrency(instruction["currency"])
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", instruction["currency"])
  if instruction["regulatoryProfileId"] <> profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  cashResult = self~ensureAtmCashAccount(instruction["terminalId"], instruction["currency"])
  if cashResult~ok = .false then return cashResult
  if ledger~store <> .nil then do
    recovered = ledger~store~recoverReceipt(instruction["idempotencyKey"])
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      if recovered~value["operation"] <> "OFFLINE_WITHDRAWAL_ADVICE" then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION", recovered~value["operation"] || "/OFFLINE_WITHDRAWAL_ADVICE")
      if \ledger~hasTransaction(tx) then do
        hydrated = ledger~hydratePostingsFromStore
        if hydrated~ok = .false then return hydrated
      end
      if \ledger~hasTransaction(tx) then return .FederationBankResult~failure("ATM_REPLAY_STATE_MISSING", tx)
      out = instruction~copy
      out["schema"] = "federationbank.ledger.offline-cash-result/0.7"
      out["ok"] = .true
      out["code"] = "ATM_SETTLEMENT_REPLAY_RECOVERED"
      out["detail"] = "durable mandatory settlement receipt recovered"
      fs = ledger~fundsState(instruction["sourceAccountId"])
      do key over .array~of("bookBalanceMinor", "activeHeldMinor", "authorisedOverdraftMinor", "availableBalanceMinor", "unauthorisedExcessMinor", "fundsState")
        out[key] = fs[key]
      end
      if fs["withdrawalsBlocked"] then out["withdrawalsBlocked"] = "true"
      else out["withdrawalsBlocked"] = "false"
      out["recoveredFromDurableReceipt"] = "true"
      return .FederationBankResult~success(out)
    end
  end
  evidence = .directory~new
  do key over .array~of("securityPolicyId", "securityPolicyVersion", "securityDisposition", "corporatePolicyId", "corporatePolicyVersion", "corporatePolicyRuleId", "legalProfileId", "legalGenerationId", "legalGenerationVersion", "regulatoryProfileId", "debitAuthority", "terminalId", "atmNetworkId", "offlineAuthorityId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence", "dispensedAt", "adviceReceivedAt", "authorityIssuedAt", "authorityExpiresAt", "authorityIssuedTerminalSequence", "reconciliationWindowSeconds", "terminalClockSkewSeconds", "offlineEvidenceDisposition", "recoverySessionId")
    evidence[key] = instruction[key]
  end
  receipt = instruction~copy
  receipt["outcome"] = "ACCEPTED"
  receipt["operation"] = "OFFLINE_WITHDRAWAL_ADVICE"
  receipt["createdAt"] = instruction["requestedAt"]
  iso = instruction["requestedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  postedAt = .DateTime~fromIsoDate(iso)
  posted = ledger~postMandatoryCashSettlement(tx, instruction["sourceAccountId"], cashResult~value~accountId, instruction["amountMinor"], instruction["currency"], postedAt, evidence, receipt)
  if posted~ok = .false then return posted
  out = instruction~copy
  out["schema"] = "federationbank.ledger.offline-cash-result/0.7"
  out["ok"] = .true
  out["code"] = "ATM_OFFLINE_SETTLEMENT_COMMITTED"
  out["detail"] = "cash already dispensed recorded as mandatory settlement"
  do key over .array~of("bookBalanceMinor", "activeHeldMinor", "authorisedOverdraftMinor", "availableBalanceMinor", "unauthorisedExcessMinor", "fundsState", "debitAuthority", "cashSettlementAccountId", "databaseTransactionId", "databaseOutcome", "databaseAttempts", "databaseOperationCount")
    if posted~value~hasIndex(key) then out[key] = posted~value[key]
  end
  if posted~value["withdrawalsBlocked"] then out["withdrawalsBlocked"] = "true"
  else out["withdrawalsBlocked"] = "false"
  return .FederationBankResult~success(out)
::method postTransfer
  expose ledger profiles
  use arg instruction
  if instruction == .nil then return .FederationBankResult~failure("LEDGER_INSTRUCTION_REQUIRED")
  if instruction["schema"] <> "federationbank.ledger.post-transfer/0.3" & instruction["schema"] <> "federationbank.ledger.post-transfer/0.6" then return .FederationBankResult~failure("LEDGER_INSTRUCTION_SCHEMA_INVALID")
  feeAmount = 0
  feeClass = "NONE"
  if instruction["schema"] = "federationbank.ledger.post-transfer/0.6" then do
    feeAmount = instruction["feeAmountMinor"] + 0
    feeClass = instruction["feeClass"]~string~upper
    if feeAmount < 0 then return .FederationBankResult~failure("FEE_AMOUNT_INVALID", feeAmount)
    if feeAmount > 0 then do
      feeAccountResult = self~ensureFeeIncomeAccount(instruction["currency"], feeClass)
      if feeAccountResult~ok = .false then return feeAccountResult
      feeIncomeAccountId = feeAccountResult~value~accountId
    end
    else feeIncomeAccountId = ""
  end
  else feeIncomeAccountId = ""
  tx = instruction["transactionId"]~string
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  profile = profiles~byCurrency(instruction["currency"])
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", instruction["currency"])
  if instruction["regulatoryProfileId"] <> profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH")
  if ledger~store <> .nil then do
    recovered = ledger~store~recoverReceipt(instruction["idempotencyKey"])
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      if recovered~value["operation"] <> "TRANSFER" then return .FederationBankResult~failure("IDEMPOTENCY_COLLISION", recovered~value["operation"] || "/TRANSFER")
      if \ledger~hasTransaction(tx) then do
        hydrated = ledger~hydratePostingsFromStore
        if hydrated~ok = .false then return hydrated
      end
      if \ledger~hasTransaction(tx) then return .FederationBankResult~failure("TRANSFER_REPLAY_STATE_MISSING", tx)
      out = instruction~copy
      if instruction["schema"] = "federationbank.ledger.post-transfer/0.6" then out["schema"] = "federationbank.ledger.result/0.6"
      else out["schema"] = "federationbank.ledger.result/0.3"
      out["ok"] = .true
      out["code"] = "LEDGER_REPLAY_RECOVERED"
      out["detail"] = "durable Ledger transfer receipt recovered"
      out["sourceBalanceMinor"] = ledger~balanceMinor(instruction["sourceAccountId"])
      out["targetBalanceMinor"] = ledger~balanceMinor(instruction["targetAccountId"])
      out["feeAmountMinor"] = feeAmount
      out["feeIncomeAccountId"] = feeIncomeAccountId
      if feeIncomeAccountId <> "" then out["feeIncomeBalanceMinor"] = ledger~balanceMinor(feeIncomeAccountId)
      out["recoveredFromDurableReceipt"] = "true"
      return .FederationBankResult~success(out)
    end
  end
  evidence = .directory~new
  do key over .array~of("securityPolicyId", "securityPolicyVersion", "securityDisposition", "corporatePolicyId", "corporatePolicyVersion", "corporatePolicyRuleId", "feePolicyId", "feePolicyVersion", "feePolicyRuleId", "legalProfileId", "legalGenerationId", "legalGenerationVersion", "regulatoryProfileId")
    evidence[key] = instruction[key]
  end
  evidence["feeAmountMinor"] = feeAmount
  evidence["feeIncomeAccountId"] = feeIncomeAccountId
  receipt = .directory~new
  receipt["outcome"] = "ACCEPTED"
  receipt["operation"] = "TRANSFER"
  receipt["commandId"] = instruction["commandId"]
  receipt["idempotencyKey"] = instruction["idempotencyKey"]
  receipt["transactionId"] = tx
  receipt["customerId"] = instruction["customerId"]
  receipt["currency"] = instruction["currency"]
  receipt["amountMinor"] = instruction["amountMinor"]
  receipt["feeAmountMinor"] = feeAmount
  receipt["feeClass"] = feeClass
  receipt["feeIncomeAccountId"] = feeIncomeAccountId
  do key over evidence
    receipt[key] = evidence[key]
  end
  receipt["createdAt"] = instruction["requestedAt"]
  postedIso = instruction["requestedAt"]~string
  if postedIso~right(1) = "Z" then postedIso = postedIso~left(postedIso~length - 1)
  postedAt = .DateTime~fromIsoDate(postedIso)
  posted = ledger~postTransfer(tx, instruction["sourceAccountId"], instruction["targetAccountId"], instruction["amountMinor"], instruction["currency"], postedAt, evidence, receipt, feeAmount, feeIncomeAccountId)
  if posted~ok = .false then return posted
  out = instruction~copy
  if instruction["schema"] = "federationbank.ledger.post-transfer/0.6" then out["schema"] = "federationbank.ledger.result/0.6"
  else out["schema"] = "federationbank.ledger.result/0.3"
  out["ok"] = .true
  out["code"] = "LEDGER_COMMITTED"
  out["detail"] = "double-entry transaction committed"
  out["sourceBalanceMinor"] = ledger~balanceMinor(instruction["sourceAccountId"])
  out["targetBalanceMinor"] = ledger~balanceMinor(instruction["targetAccountId"])
  out["feeAmountMinor"] = feeAmount
  out["feeIncomeAccountId"] = feeIncomeAccountId
  out["totalDebitMinor"] = instruction["amountMinor"] + feeAmount
  if feeIncomeAccountId <> "" then out["feeIncomeBalanceMinor"] = ledger~balanceMinor(feeIncomeAccountId)
  if posted~value~hasIndex("databaseTransactionId") then do
    out["databaseTransactionId"] = posted~value["databaseTransactionId"]
    out["databaseOutcome"] = posted~value["databaseOutcome"]
    out["databaseAttempts"] = posted~value["databaseAttempts"]
  end
  return .FederationBankResult~success(out)


/* Queue worker harness.  Each process may host only the methods for its own
 * engine; this class exists so acceptance tests can exercise all three
 * workers against one Queue Fabric without pretending they share authority. */
::class FederationBankBackendRuntime public
::method init
  expose topology accountEngine paymentsEngine ledgerEngine
  use arg topologyArg, accountEngineArg, paymentsEngineArg, ledgerEngineArg
  topology = topologyArg
  accountEngine = accountEngineArg
  paymentsEngine = paymentsEngineArg
  ledgerEngine = ledgerEngineArg
::method options private
  expose topology
  use arg correlationId = "", headers = .nil
  o = .table~new
  o["persistent"] = topology~persistent
  if correlationId <> "" then o["correlationId"] = correlationId
  if headers <> .nil then o["headers"] = headers
  return o
::method submitOpenAccount
  expose topology
  use arg command
  return topology~manager~put(.FederationBankServiceTopology~ACCOUNT_COMMANDS, command~asPayload, self~options(command~commandId), .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
::method submitAccountCommand
  expose topology
  use arg command
  return topology~manager~put(.FederationBankServiceTopology~ACCOUNT_COMMANDS, command~asPayload, self~options(command~commandId), .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
::method submitBeneficiary
  use arg command
  return self~submitAccountCommand(command)
::method submitTransfer
  expose topology
  use arg command
  return topology~manager~put(.FederationBankServiceTopology~PAYMENTS_COMMANDS, command~asPayload, self~options(command~commandId), .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
::method submitHold
  expose topology
  use arg command
  return topology~manager~put(.FederationBankServiceTopology~PAYMENTS_COMMANDS, command~asPayload, self~options(command~commandId), .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
::method rollbackFailure private
  expose topology
  use arg uow, code, detail = ""
  rb = topology~manager~rollbackUnitOfWork(uow)
  if rb~ok = .false then detail ||= "; rollback=" || rb~code || ":" || rb~detail
  return .FederationBankResult~failure(code, detail, rb)
::method resultPayload private
  use arg command, handled
  d = .directory~new
  d["schema"] = "federationbank.channel.result/0.3"
  d["commandId"] = command~commandId
  d["operation"] = command~operation
  d["idempotencyKey"] = command~idempotencyKey
  d["ok"] = handled~ok
  d["code"] = handled~code
  d["detail"] = handled~detail
  if handled~value <> .nil then if handled~value~isA(.Directory) then do key over handled~value
    upperKey = key~string~upper
    if upperKey = "SCHEMA" | upperKey = "COMMANDID" | upperKey = "OPERATION" | upperKey = "IDEMPOTENCYKEY" | upperKey = "OK" | upperKey = "CODE" | upperKey = "DETAIL" then iterate
    v = handled~value[key]
    if v == .nil then d[key] = ""
    else if v~class~id = "String" then d[key] = v
  end
  return d
::method processAccountOne
  expose topology accountEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~ACCOUNT_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~ACCOUNT_COMMANDS)
  if got~ok = .false then return self~rollbackFailure(uow, "QUEUE_ACCOUNT_GET_FAILED", got~code)
  package = got~value
  payload = package~payload
  if payload == .nil | \payload~isA(.Directory) then return self~rollbackFailure(uow, "MALFORMED_ACCOUNT_COMMAND", "payload")
  if \payload~hasIndex("operation") then return self~rollbackFailure(uow, "MALFORMED_ACCOUNT_COMMAND", "operation")
  command = .FederationBankCommand~fromPayload(payload)
  handled = accountEngine~handle(command)
  resultQueue = manager~uowPut(uow, .FederationBankServiceTopology~ACCOUNT_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
  if resultQueue~ok = .false then return self~rollbackFailure(uow, "ACCOUNT_RESULT_STAGE_FAILED", resultQueue~code)
  if handled~ok then do
    projection = accountEngine~projectionFrom(command, handled)
    publishedProjection = topology~publishAccountProjection(projection, command~commandId)
    if publishedProjection~ok = .false then return self~rollbackFailure(uow, "ACCOUNT_PROJECTION_PUBLISH_FAILED", publishedProjection~code || ":" || publishedProjection~detail)
  end
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "ACCOUNT_QUEUE_UOW_COMMIT_FAILED", committed~code)
  return handled
::method processPaymentsProjectionOne
  expose topology paymentsEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~PAYMENTS_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~ACCOUNT_TO_PAYMENTS)
  if got~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_PROJECTION_GET_FAILED", got~code)
  applied = paymentsEngine~applyAccountProjection(got~value~payload)
  if applied~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_PROJECTION_APPLY_FAILED", applied~code)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_PROJECTION_UOW_FAILED", committed~code)
  return applied
::method processPaymentsBeneficiaryProjectionOne
  expose topology paymentsEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~PAYMENTS_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~BENEFICIARY_TO_PAYMENTS)
  if got~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_BENEFICIARY_PROJECTION_GET_FAILED", got~code)
  applied = paymentsEngine~applyBeneficiaryProjection(got~value~payload)
  if applied~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_BENEFICIARY_PROJECTION_APPLY_FAILED", applied~code || ":" || applied~detail)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_BENEFICIARY_PROJECTION_COMMIT_FAILED", committed~code)
  return applied
::method processLedgerProjectionOne
  expose topology ledgerEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~LEDGER_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~ACCOUNT_TO_LEDGER)
  if got~ok = .false then return self~rollbackFailure(uow, "LEDGER_PROJECTION_GET_FAILED", got~code)
  applied = ledgerEngine~applyAccountProjection(got~value~payload)
  if applied~ok = .false then return self~rollbackFailure(uow, "LEDGER_PROJECTION_APPLY_FAILED", applied~code)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "LEDGER_PROJECTION_UOW_FAILED", committed~code)
  return applied
::method processPaymentsOne
  expose topology paymentsEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~PAYMENTS_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~PAYMENTS_COMMANDS)
  if got~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_GET_FAILED", got~code)
  payload = got~value~payload
  if payload == .nil | \payload~isA(.Directory) then return self~rollbackFailure(uow, "MALFORMED_PAYMENT_COMMAND", "payload")
  if \payload~hasIndex("operation") then return self~rollbackFailure(uow, "MALFORMED_PAYMENT_COMMAND", "operation")
  command = .FederationBankCommand~fromPayload(payload)
  directDecision = .false
  if command~operation = "TRANSFER" then authorised = paymentsEngine~authorizeTransfer(command)
  else if command~operation = "FX_CONVERT" then authorised = paymentsEngine~authorizeFx(command)
  else if command~operation = "ATM_OFFLINE_AUTHORITY_ISSUE" then do; authorised = paymentsEngine~authorizeOfflineAuthority(command); directDecision = .true; end
  else if command~operation = "OFFLINE_WITHDRAWAL_ADVICE" then authorised = paymentsEngine~authorizeOfflineCashAdvice(command)
  else if command~operation = "WITHDRAW_COMMIT" then authorised = paymentsEngine~authorizeAtmWithdrawalCommit(command)
  else if command~operation = "DEPOSIT_COMMIT" then authorised = paymentsEngine~authorizeAtmDepositCommit(command)
  else if command~operation = "PLACE_HOLD" | command~operation = "RELEASE_HOLD" then authorised = paymentsEngine~authorizeHold(command)
  else authorised = .FederationBankResult~failure("PAYMENTS_OPERATION_UNSUPPORTED", command~operation)
  if authorised~ok then do
    if directDecision then staged = manager~uowPut(uow, .FederationBankServiceTopology~PAYMENTS_RESULTS, self~resultPayload(command, authorised), self~options(command~commandId))
    else staged = manager~uowPut(uow, .FederationBankServiceTopology~LEDGER_COMMANDS, authorised~value, self~options(command~commandId))
  end
  else staged = manager~uowPut(uow, .FederationBankServiceTopology~PAYMENTS_RESULTS, self~resultPayload(command, authorised), self~options(command~commandId))
  if staged~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_UOW_COMMIT_FAILED", committed~code)
  return authorised
::method processLedgerOne
  expose topology ledgerEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~LEDGER_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~LEDGER_COMMANDS)
  if got~ok = .false then return self~rollbackFailure(uow, "LEDGER_GET_FAILED", got~code)
  instruction = got~value~payload
  if instruction["schema"] = "federationbank.ledger.post-transfer/0.3" | instruction["schema"] = "federationbank.ledger.post-transfer/0.6" then posted = ledgerEngine~postTransfer(instruction)
  else if instruction["schema"] = "federationbank.ledger.fx/0.7" then posted = ledgerEngine~postFx(instruction)
  else if instruction["schema"] = "federationbank.ledger.offline-cash/0.7" then posted = ledgerEngine~postOfflineCashAdvice(instruction)
  else if instruction["schema"] = "federationbank.ledger.atm-withdrawal/0.8" then posted = ledgerEngine~postAtmWithdrawal(instruction)
  else if instruction["schema"] = "federationbank.ledger.atm-deposit/0.8" then posted = ledgerEngine~postAtmDeposit(instruction)
  else if instruction["schema"] = "federationbank.ledger.hold/0.5" then posted = ledgerEngine~manageHold(instruction)
  else posted = .FederationBankResult~failure("LEDGER_INSTRUCTION_SCHEMA_INVALID", instruction["schema"])
  if posted~ok then out = posted~value
  else do
    out = instruction~copy
    if instruction["schema"] = "federationbank.ledger.hold/0.5" then out["schema"] = "federationbank.ledger.hold-result/0.5"
    else if instruction["schema"] = "federationbank.ledger.fx/0.7" then out["schema"] = "federationbank.ledger.fx-result/0.7"
    else if instruction["schema"] = "federationbank.ledger.offline-cash/0.7" then out["schema"] = "federationbank.ledger.offline-cash-result/0.7"
    else if instruction["schema"] = "federationbank.ledger.atm-withdrawal/0.8" then out["schema"] = "federationbank.ledger.atm-withdrawal-result/0.8"
    else if instruction["schema"] = "federationbank.ledger.atm-deposit/0.8" then out["schema"] = "federationbank.ledger.atm-deposit-result/0.8"
    else if instruction["schema"] = "federationbank.ledger.post-transfer/0.6" then out["schema"] = "federationbank.ledger.result/0.6"
    else out["schema"] = "federationbank.ledger.result/0.3"
    out["ok"] = .false
    out["code"] = posted~code
    out["detail"] = posted~detail
  end
  staged = manager~uowPut(uow, .FederationBankServiceTopology~LEDGER_RESULTS, out, self~options(instruction["commandId"]))
  if staged~ok = .false then return self~rollbackFailure(uow, "LEDGER_RESULT_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "LEDGER_UOW_COMMIT_FAILED", committed~code)
  return posted
::method processPaymentsCompletionOne
  expose topology paymentsEngine
  manager = topology~manager
  uow = manager~beginUnitOfWork(.FederationBankServiceTopology~PAYMENTS_WORKER)~value
  got = manager~uowGet(uow, .FederationBankServiceTopology~LEDGER_RESULTS)
  if got~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_COMPLETION_GET_FAILED", got~code)
  ledgerResult = got~value~payload
  if ledgerResult == .nil | \ledgerResult~isA(.Directory) then return self~rollbackFailure(uow, "PAYMENTS_COMPLETION_INVALID", "payload")
  op = ledgerResult["operation"]~string~upper
  if op = "TRANSFER" then completed = paymentsEngine~completeLedgerResult(ledgerResult)
  else if op = "FX_CONVERT" then completed = paymentsEngine~completeFxResult(ledgerResult)
  else if op = "OFFLINE_WITHDRAWAL_ADVICE" then completed = paymentsEngine~completeOfflineCashResult(ledgerResult)
  else if op = "WITHDRAW_COMMIT" then completed = paymentsEngine~completeAtmWithdrawalResult(ledgerResult)
  else if op = "DEPOSIT_COMMIT" then completed = paymentsEngine~completeAtmDepositResult(ledgerResult)
  else if op = "PLACE_HOLD" | op = "RELEASE_HOLD" then completed = paymentsEngine~completeHoldResult(ledgerResult)
  else completed = .FederationBankResult~failure("PAYMENTS_COMPLETION_OPERATION_UNSUPPORTED", op)
  command = .FederationBankCommand~fromPayload(ledgerResult)
  staged = manager~uowPut(uow, .FederationBankServiceTopology~PAYMENTS_RESULTS, self~resultPayload(command, completed), self~options(command~commandId))
  if staged~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_RESULT_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if committed~ok = .false then return self~rollbackFailure(uow, "PAYMENTS_COMPLETION_UOW_FAILED", committed~code)
  return completed
::method getAccountResult
  expose topology
  return topology~manager~get(.FederationBankServiceTopology~ACCOUNT_RESULTS, .FederationBankServiceTopology~CHANNEL_PRINCIPAL)
::method getPaymentsResult
  expose topology
  return topology~manager~get(.FederationBankServiceTopology~PAYMENTS_RESULTS, .FederationBankServiceTopology~CHANNEL_PRINCIPAL)

::requires "FederationBankEngine.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
