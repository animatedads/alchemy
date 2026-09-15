/* FederationBankEngine.cls
   FederationBank IOM Offshore banking-domain core v0.9.1.

   Monetary truth is an immutable double-entry posting journal.
   Currency selects a regulatory profile; policy and legal decisions are
   resolved externally through Institutional Policy / Legal Effect.
   Security Effect (the Bouncer) gates transactions before postings occur.
*/

::class FederationBankBuild public
::constant RELEASE "0.8"
::constant API_VERSION "federationbank.engine/0.8"
::constant BOOKING_ENTITY "FEDERATIONBANK-IOM-OFFSHORE"
::constant BOOKING_JURISDICTION "IOM"
::constant LIMIT_POLICY_DEFAULT "FB-CUSTOMER-TXN-LIMITS"
::constant OPENING_POLICY_DEFAULT "FB-ACCOUNT-OPENING"
::constant BENEFICIARY_POLICY_DEFAULT "FB-BENEFICIARY-LIFECYCLE"
::constant FEE_POLICY_DEFAULT "FB-TRANSFER-FEES"
::constant FX_POLICY_DEFAULT "FB-FX-CONVERSION"

::class FederationBankResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg
::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)
::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)

::class FederationBankRegulatoryProfile public
::attribute profileId get
::attribute currency get
::attribute bookingJurisdiction get
::attribute legalProfileId get
::attribute settlementRailClass get
::attribute regulatoryBehaviour get
::method init
  expose profileId currency bookingJurisdiction legalProfileId settlementRailClass regulatoryBehaviour
  use arg profileIdArg, currencyArg, bookingJurisdictionArg, legalProfileIdArg, settlementRailClassArg, regulatoryBehaviourArg
  profileId = profileIdArg~string~upper
  currency = currencyArg~string~upper
  bookingJurisdiction = bookingJurisdictionArg~string~upper
  legalProfileId = legalProfileIdArg~string~upper
  settlementRailClass = settlementRailClassArg~string~upper
  regulatoryBehaviour = regulatoryBehaviourArg~string
::method canonicalText
  expose profileId currency bookingJurisdiction legalProfileId settlementRailClass regulatoryBehaviour
  return profileId || "|" || currency || "|" || bookingJurisdiction || "|" || legalProfileId || "|" || settlementRailClass || "|" || regulatoryBehaviour

::class FederationBankRegulatoryProfileRegistry public
::method init
  expose profiles byCurrency
  profiles = .directory~new
  byCurrency = .directory~new
::method register
  expose profiles byCurrency
  use arg profile
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_REQUIRED")
  if profiles~hasIndex(profile~profileId) then return .FederationBankResult~failure("REGULATORY_PROFILE_DUPLICATE", profile~profileId)
  if byCurrency~hasIndex(profile~currency) then return .FederationBankResult~failure("REGULATORY_CURRENCY_DUPLICATE", profile~currency)
  profiles[profile~profileId] = profile
  byCurrency[profile~currency] = profile
  return .FederationBankResult~success(profile)
::method byCurrency
  expose byCurrency
  use arg currency
  key = currency~string~upper
  if byCurrency~hasIndex(key) then return byCurrency[key]
  return .nil
::method byId
  expose profiles
  use arg profileId
  key = profileId~string~upper
  if profiles~hasIndex(key) then return profiles[key]
  return .nil
::method standard class
  r = self~new
  /* Behaviour strings are routing semantics, not statements of real law. */
  r~register(.FederationBankRegulatoryProfile~new("FB-IOM-USD", "USD", "IOM", "FB-LEGAL-USD", "USD", "USD-specific legal/regulatory and settlement behaviour"))
  r~register(.FederationBankRegulatoryProfile~new("FB-IOM-AUD", "AUD", "IOM", "FB-LEGAL-AUD", "AUD", "AUD-specific legal/regulatory and settlement behaviour"))
  r~register(.FederationBankRegulatoryProfile~new("FB-IOM-GBP", "GBP", "IOM", "FB-LEGAL-GBP", "GBP", "GBP-specific legal/regulatory and settlement behaviour"))
  r~register(.FederationBankRegulatoryProfile~new("FB-IOM-EUR", "EUR", "IOM", "FB-LEGAL-EUR", "EUR", "EUR-specific legal/regulatory and settlement behaviour"))
  return r

::class FederationBankCustomer public
::attribute customerId get
::attribute legalName get
::attribute dateOfBirth get
::attribute postcode get
::attribute addressCountry get
::attribute segment get
::attribute domicile get
::attribute residence get
::attribute riskTier get
::attribute limitPolicyId get
::method init
  expose customerId legalName dateOfBirth postcode addressCountry segment domicile residence riskTier limitPolicyId
  use arg customerIdArg, segmentArg = "RETAIL", domicileArg = "", residenceArg = "", riskTierArg = "STANDARD", limitPolicyIdArg = .nil, legalNameArg = "", dateOfBirthArg = "", postcodeArg = "", addressCountryArg = ""
  if limitPolicyIdArg == .nil then limitPolicyIdArg = .FederationBankBuild~LIMIT_POLICY_DEFAULT
  customerId = customerIdArg~string
  legalName = legalNameArg~string
  dateOfBirth = dateOfBirthArg~string
  postcode = postcodeArg~string~upper
  addressCountry = addressCountryArg~string~upper
  segment = segmentArg~string~upper
  domicile = domicileArg~string~upper
  residence = residenceArg~string~upper
  riskTier = riskTierArg~string~upper
  limitPolicyId = limitPolicyIdArg~string~upper

::class FederationBankCustomerRegistry public
::method init
  expose customers
  customers = .directory~new
::method add
  expose customers
  use arg customer
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_REQUIRED")
  if customers~hasIndex(customer~customerId) then return .FederationBankResult~failure("CUSTOMER_DUPLICATE", customer~customerId)
  customers[customer~customerId] = customer
  return .FederationBankResult~success(customer)
::method customer
  expose customers
  use arg customerId
  if customers~hasIndex(customerId~string) then return customers[customerId~string]
  return .nil

::class FederationBankBeneficiary public
::attribute beneficiaryId get
::attribute customerId get
::attribute ownerAccountId get
::attribute displayName get
::attribute accountReference get
::attribute bankCode get
::attribute country get
::attribute currency get
::attribute status get
::attribute version get
::attribute updatedAt get
::method init
  expose beneficiaryId customerId ownerAccountId displayName accountReference bankCode country currency status version updatedAt
  use arg beneficiaryIdArg, customerIdArg, ownerAccountIdArg, displayNameArg, accountReferenceArg, bankCodeArg = "", countryArg = "", currencyArg = "", statusArg = "ACTIVE", versionArg = 1, updatedAtArg = .nil
  beneficiaryId = beneficiaryIdArg~string
  customerId = customerIdArg~string
  ownerAccountId = ownerAccountIdArg~string
  displayName = displayNameArg~string
  accountReference = accountReferenceArg~string
  bankCode = bankCodeArg~string
  country = countryArg~string~upper
  currency = currencyArg~string~upper
  status = statusArg~string~upper
  version = versionArg + 0
  if updatedAtArg == .nil then updatedAt = .DateTime~new
  else updatedAt = updatedAtArg
::method amended
  expose beneficiaryId customerId ownerAccountId displayName accountReference bankCode country currency version
  use arg displayNameArg, accountReferenceArg, bankCodeArg, countryArg, currencyArg, atTime
  return .FederationBankBeneficiary~new(beneficiaryId, customerId, ownerAccountId, displayNameArg, accountReferenceArg, bankCodeArg, countryArg, currencyArg, "ACTIVE", version + 1, atTime)
::method suspended
  expose beneficiaryId customerId ownerAccountId displayName accountReference bankCode country currency version
  use arg atTime
  return .FederationBankBeneficiary~new(beneficiaryId, customerId, ownerAccountId, displayName, accountReference, bankCode, country, currency, "SUSPENDED", version + 1, atTime)
::method asDirectory
  expose beneficiaryId customerId ownerAccountId displayName accountReference bankCode country currency status version updatedAt
  d = .directory~new
  d["beneficiaryId"] = beneficiaryId
  d["customerId"] = customerId
  d["ownerAccountId"] = ownerAccountId
  d["displayName"] = displayName
  d["accountReference"] = accountReference
  d["bankCode"] = bankCode
  d["country"] = country
  d["currency"] = currency
  d["status"] = status
  d["version"] = version
  d["updatedAt"] = updatedAt~utcIsoDate
  return d

::class FederationBankBeneficiaryRegistry public
::method init
  expose beneficiaries
  beneficiaries = .directory~new
::method key private
  use arg customerId, beneficiaryId
  return customerId~string || "|" || beneficiaryId~string
::method add
  expose beneficiaries
  use arg beneficiary
  if beneficiary == .nil then return .FederationBankResult~failure("BENEFICIARY_REQUIRED")
  key = self~key(beneficiary~customerId, beneficiary~beneficiaryId)
  if beneficiaries~hasIndex(key) then return .FederationBankResult~failure("BENEFICIARY_DUPLICATE", beneficiary~beneficiaryId)
  beneficiaries[key] = beneficiary
  return .FederationBankResult~success(beneficiary)
::method upsert
  expose beneficiaries
  use arg beneficiary
  if beneficiary == .nil then return .FederationBankResult~failure("BENEFICIARY_REQUIRED")
  beneficiaries[self~key(beneficiary~customerId, beneficiary~beneficiaryId)] = beneficiary
  return .FederationBankResult~success(beneficiary)
::method beneficiary
  expose beneficiaries
  use arg customerId, beneficiaryId
  key = self~key(customerId, beneficiaryId)
  if beneficiaries~hasIndex(key) then return beneficiaries[key]
  return .nil
::method activeCount
  expose beneficiaries
  use arg customerId
  n = 0
  do key over beneficiaries
    b = beneficiaries[key]
    if b~customerId = customerId~string & b~status = "ACTIVE" then n += 1
  end
  return n
::method allForCustomer
  expose beneficiaries
  use arg customerId
  out = .array~new
  do key over beneficiaries
    b = beneficiaries[key]
    if b~customerId = customerId~string then out~append(b)
  end
  return out

::class FederationBankAccount public
::attribute accountId get
::attribute customerId get
::attribute currency get
::attribute productCode get
::attribute bookingJurisdiction get
::attribute regulatoryProfileId get
::attribute status get
::attribute internalAccount get
::attribute allowNegative get
::attribute authorisedOverdraftMinor get
::method init
  expose accountId customerId currency productCode bookingJurisdiction regulatoryProfileId status internalAccount allowNegative authorisedOverdraftMinor
  use arg accountIdArg, customerIdArg, currencyArg, productCodeArg, bookingJurisdictionArg, regulatoryProfileIdArg, internalAccountArg = .false, allowNegativeArg = .false, authorisedOverdraftMinorArg = 0
  accountId = accountIdArg~string
  customerId = customerIdArg~string
  currency = currencyArg~string~upper
  productCode = productCodeArg~string~upper
  bookingJurisdiction = bookingJurisdictionArg~string~upper
  regulatoryProfileId = regulatoryProfileIdArg~string~upper
  status = "OPEN"
  internalAccount = internalAccountArg
  allowNegative = allowNegativeArg
  authorisedOverdraftMinor = authorisedOverdraftMinorArg + 0
  if authorisedOverdraftMinor < 0 then authorisedOverdraftMinor = 0
::method close
  expose status
  status = "CLOSED"
  return self

::class FederationBankDebitAuthority public
::constant FUNDS_REQUIRED "FUNDS_REQUIRED"
::constant RESERVATION_CONSUME "RESERVATION_CONSUME"
::constant SETTLEMENT_MUST_POST "SETTLEMENT_MUST_POST"
::constant INTERNAL_CHARGE_POLICY_CONTROLLED "INTERNAL_CHARGE_POLICY_CONTROLLED"
::method known class
  use arg value
  v = value~string~upper
  return v = self~FUNDS_REQUIRED | v = self~RESERVATION_CONSUME | v = self~SETTLEMENT_MUST_POST | v = self~INTERNAL_CHARGE_POLICY_CONTROLLED

::class FederationBankPosting public
::attribute postingId get
::attribute transactionId get
::attribute accountId get
::attribute currency get
::attribute amountMinor get
::attribute postedAt get
::attribute side get
::attribute postingRole get
::method init
  expose postingId transactionId accountId currency amountMinor postedAt side postingRole
  use arg postingIdArg, transactionIdArg, accountIdArg, currencyArg, amountMinorArg, postedAtArg, sideArg, postingRoleArg = "TRANSFER"
  postingId = postingIdArg~string
  transactionId = transactionIdArg~string
  accountId = accountIdArg~string
  currency = currencyArg~string~upper
  amountMinor = amountMinorArg + 0
  postedAt = postedAtArg
  side = sideArg~string~upper
  postingRole = postingRoleArg~string~upper
::method canonicalText
  expose postingId transactionId accountId currency amountMinor postedAt side postingRole
  return postingId || "|" || transactionId || "|" || accountId || "|" || currency || "|" || amountMinor || "|" || postedAt || "|" || side || "|" || postingRole


::class FederationBankHold public
::attribute holdId get
::attribute accountId get
::attribute customerId get
::attribute currency get
::attribute amountMinor get
::attribute status get
::attribute placedAt get
::attribute releasedAt get
::attribute version get
::method init
  expose holdId accountId customerId currency amountMinor status placedAt releasedAt version
  use arg holdIdArg, accountIdArg, customerIdArg, currencyArg, amountMinorArg, statusArg = "ACTIVE", placedAtArg = .nil, releasedAtArg = .nil, versionArg = 1
  holdId = holdIdArg~string
  accountId = accountIdArg~string
  customerId = customerIdArg~string
  currency = currencyArg~string~upper
  amountMinor = amountMinorArg + 0
  status = statusArg~string~upper
  if placedAtArg == .nil then placedAt = .DateTime~new
  else placedAt = placedAtArg
  releasedAt = releasedAtArg
  version = versionArg + 0
::method released
  expose holdId accountId customerId currency amountMinor placedAt version
  use arg atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  return self~class~new(holdId, accountId, customerId, currency, amountMinor, "RELEASED", placedAt, atTime, version + 1)
::method asDirectory
  expose holdId accountId customerId currency amountMinor status placedAt releasedAt version
  d = .directory~new
  d["holdId"] = holdId
  d["accountId"] = accountId
  d["customerId"] = customerId
  d["currency"] = currency
  d["amountMinor"] = amountMinor
  d["status"] = status
  d["placedAt"] = placedAt~utcIsoDate
  if releasedAt == .nil then d["releasedAt"] = ""
  else d["releasedAt"] = releasedAt~utcIsoDate
  d["version"] = version
  return d

::class FederationBankSqlLedgerStore public
::method init
  expose database retryAttempts timeoutSeconds
  use arg databaseArg, retryAttemptsArg = 3, timeoutSecondsArg = 15
  if databaseArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_SQL_DATABASE_REQUIRED")
  database = databaseArg
  retryAttempts = retryAttemptsArg + 0
  timeoutSeconds = timeoutSecondsArg + 0
::method database
  expose database
  return database
::method configureWriteTransaction private
  expose database retryAttempts timeoutSeconds
  use arg identityText, evidence = .nil, description = "FederationBank durable state change"
  context = .DatabaseExecutionContext~new(evidence, description)
  identity = .DatabaseTransactionIdentity~new(identityText)
  tx = database~transaction(context, identity)
  isolationStatus = tx~isolation(.DatabaseIsolation~SERIALIZABLE)
  if isolationStatus <> .Error~SUCCESS then return .FederationBankResult~failure("DATABASE_TX_POLICY_FAILED", "isolation=" || isolationStatus)
  accessStatus = tx~readWrite
  if accessStatus <> .Error~SUCCESS then return .FederationBankResult~failure("DATABASE_TX_POLICY_FAILED", "readWrite=" || accessStatus)
  retryStatus = tx~setRetryAttempts(retryAttempts)
  if retryStatus <> .Error~SUCCESS then return .FederationBankResult~failure("DATABASE_TX_POLICY_FAILED", "retry=" || retryStatus)
  timeoutStatus = tx~setTimeout(timeoutSeconds)
  if timeoutStatus <> .Error~SUCCESS then return .FederationBankResult~failure("DATABASE_TX_POLICY_FAILED", "timeout=" || timeoutStatus)
  return .FederationBankResult~success(tx)
::method receiptAt private
  use arg receipt, key, defaultValue = ""
  if receipt == .nil then return defaultValue
  if receipt~isA(.Directory) then do
    if receipt~hasIndex(key) then do
      value = receipt[key]
      if value == .nil then return defaultValue
      return value
    end
  end
  return defaultValue
::method evidenceAt private
  use arg evidence, key
  if evidence == .nil then return ""
  if evidence~isA(.Directory) then do
    if evidence~hasIndex(key) then do
      value = evidence[key]
      if value == .nil then return ""
      return value
    end
  end
  return ""
::method nullableNumber private
  use arg value = .nil
  if value == .nil then return .nil
  if value~string = "" then return .nil
  return value
::method insertReceipt private
  use arg tx, receipt
  if receipt == .nil then return
  stmt = tx~prepareStatement("fb_receipt_insert", -
    "INSERT INTO federationbank_command_receipts (idempotency_key, command_id, operation, outcome_code, customer_id, account_id, transaction_id, currency, amount_minor, regulatory_profile_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, address_verification_reference, credit_bureau_reference, credit_status, credit_score, created_at, result_payload) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  values = .array~of( -
    self~receiptAt(receipt,"idempotencyKey"), self~receiptAt(receipt,"commandId"), self~receiptAt(receipt,"operation"), self~receiptAt(receipt,"outcome","ACCEPTED"), -
    self~receiptAt(receipt,"customerId"), self~receiptAt(receipt,"accountId"), self~receiptAt(receipt,"transactionId"), self~receiptAt(receipt,"currency"), self~receiptAt(receipt,"amountMinor",0), -
    self~receiptAt(receipt,"regulatoryProfileId"), self~receiptAt(receipt,"securityPolicyId"), self~receiptAt(receipt,"securityPolicyVersion"), self~receiptAt(receipt,"securityDisposition"), -
    self~receiptAt(receipt,"corporatePolicyId"), self~receiptAt(receipt,"corporatePolicyVersion"), self~receiptAt(receipt,"corporatePolicyRuleId"), -
    self~receiptAt(receipt,"legalProfileId"), self~receiptAt(receipt,"legalGenerationId"), self~receiptAt(receipt,"legalGenerationVersion"), -
    self~receiptAt(receipt,"addressVerificationReference"), self~receiptAt(receipt,"creditBureauReference"), self~receiptAt(receipt,"creditStatus"), self~nullableNumber(self~receiptAt(receipt,"creditScore",.nil)), -
    self~receiptAt(receipt,"createdAt",.DateTime~new~utcIsoDate), c2x(.QueueGraphPayloadCodec~new~encode(receipt)))
  tx~executePrepared(stmt, values)
::method insertCreditIntelligenceEvidence private
  use arg tx, idempotencyKey, evidence
  if evidence == .nil | \evidence~isA(.Directory) then return
  if \evidence~hasIndex("creditIntelligenceEvidence") then return
  product = evidence["creditIntelligenceEvidence"]
  if product == .nil | \product~isA(.Directory) then return
  codec = .QueueGraphPayloadCodec~new
  raw = codec~encode(product)
  suppress = ""
  if product~hasIndex("suppressionFlags") then suppress = codec~encode(product["suppressionFlags"])
  reasons = ""
  if product~hasIndex("reasonCodeTree") then reasons = codec~encode(product["reasonCodeTree"])
  stmt = tx~prepareStatement("fb_ijcib_evidence_insert", -
    "INSERT INTO federationbank_credit_intelligence_evidence (idempotency_key, request_id, correlation_token, bureau_product_id, bureau_reference, generation_timestamp, methodology_version, overall_disposition, scaled_value, scale_direction, score_band_label, suppression_flags_payload, reason_code_tree_payload, next_permitted_refresh_not_before, raw_product_payload) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(stmt, .array~of(idempotencyKey, self~receiptAt(product,"requestId"), self~receiptAt(product,"correlationToken"), self~receiptAt(product,"bureauProductId"), self~receiptAt(product,"bureauReference"), self~receiptAt(product,"generationTimestamp"), self~receiptAt(product,"methodologyVersion"), self~receiptAt(product,"overallDisposition"), self~receiptAt(product,"scaledValue"), self~receiptAt(product,"scaleDirection"), self~receiptAt(product,"scoreBandLabel"), suppress, reasons, self~receiptAt(product,"nextPermittedRefreshNotBefore"), raw))

::method fixtureRememberReceipt private
  expose database
  use arg receipt
  if receipt == .nil then return
  executor = database~executor
  if executor~hasMethod("REMEMBERRECEIPT") then executor~rememberReceipt(receipt)
::method fixtureRememberPostings private
  expose database
  use arg postingSet
  executor = database~executor
  if executor~hasMethod("REMEMBERPOSTINGS") then executor~rememberPostings(postingSet)
  else if postingSet <> .nil then if postingSet~items = 2 then if executor~hasMethod("REMEMBERTRANSFER") then executor~rememberTransfer(postingSet[1], postingSet[2])
::method commitTransfer
  use arg debitPosting, creditPosting, evidence = .nil, receipt = .nil
  if debitPosting == .nil | creditPosting == .nil then return .FederationBankResult~failure("LEDGER_POSTINGS_REQUIRED")
  return self~commitTransferPostings(.array~of(debitPosting, creditPosting), debitPosting~accountId, creditPosting~accountId, 0 - debitPosting~amountMinor, 0, "", evidence, receipt)
::method commitTransferPostings
  expose database
  use arg postingSet, debitAccountId, creditAccountId, transferAmountMinor, feeAmountMinor = 0, feeIncomeAccountId = "", evidence = .nil, receipt = .nil
  if postingSet == .nil then return .FederationBankResult~failure("LEDGER_POSTINGS_REQUIRED")
  if postingSet~items < 2 then return .FederationBankResult~failure("LEDGER_POSTINGS_REQUIRED")
  bankTxId = postingSet[1]~transactionId
  currency = postingSet[1]~currency
  postedAt = postingSet[1]~postedAt
  sum = 0
  do posting over postingSet
    if posting == .nil then return .FederationBankResult~failure("LEDGER_POSTING_REQUIRED")
    if posting~transactionId <> bankTxId then return .FederationBankResult~failure("LEDGER_TRANSACTION_MISMATCH")
    if posting~currency <> currency then return .FederationBankResult~failure("LEDGER_CURRENCY_MISMATCH")
    if posting~amountMinor = 0 then return .FederationBankResult~failure("LEDGER_ZERO_POSTING")
    if posting~amountMinor < 0 & posting~side <> "DEBIT" then return .FederationBankResult~failure("LEDGER_SIDE_INVALID", posting~postingId)
    if posting~amountMinor > 0 & posting~side <> "CREDIT" then return .FederationBankResult~failure("LEDGER_SIDE_INVALID", posting~postingId)
    sum += posting~amountMinor
  end
  if sum <> 0 then return .FederationBankResult~failure("LEDGER_NOT_BALANCED", sum)
  transferAmount = transferAmountMinor + 0
  feeAmount = feeAmountMinor + 0
  if transferAmount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", transferAmount)
  if feeAmount < 0 then return .FederationBankResult~failure("FEE_AMOUNT_INVALID", feeAmount)
  if feeAmount > 0 & feeIncomeAccountId~string = "" then return .FederationBankResult~failure("FEE_INCOME_ACCOUNT_REQUIRED")

  configured = self~configureWriteTransaction("federationbank:" || bankTxId, evidence, "FederationBank ledger commit " || bankTxId)
  if configured~ok = .false then return configured
  tx = configured~value

  header = tx~prepareStatement("fb_tx_insert", -
    "INSERT INTO federationbank_transactions (transaction_id, currency, posted_at, debit_account_id, credit_account_id, amount_minor, fee_amount_minor, fee_account_id, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(header, .array~of(bankTxId, currency, postedAt~utcIsoDate, debitAccountId, creditAccountId, transferAmount, feeAmount, feeIncomeAccountId, "COMMITTED"))

  post = tx~prepareStatement("fb_posting_insert", -
    "INSERT INTO federationbank_ledger_postings (posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  do posting over postingSet
    tx~executePrepared(post, .array~of(posting~postingId, bankTxId, posting~accountId, posting~currency, posting~amountMinor, posting~postedAt~utcIsoDate, posting~side, posting~postingRole))
  end

  decision = tx~prepareStatement("fb_decision_insert", -
    "INSERT INTO federationbank_transaction_decisions (transaction_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, fee_policy_id, fee_policy_version, fee_policy_rule_id, fee_amount_minor, fee_income_account_id, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(decision, .array~of(bankTxId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"feePolicyId"), self~evidenceAt(evidence,"feePolicyVersion"), self~evidenceAt(evidence,"feePolicyRuleId"), feeAmount, feeIncomeAccountId, self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId")))

  self~insertReceipt(tx, receipt)

  rs = tx~commit
  if rs~committed = .false then do
    detail = "database transaction " || rs~transactionId || " outcome=" || rs~outcome || " error=" || rs~error
    return .FederationBankResult~failure("LEDGER_DATABASE_ROLLBACK", detail, rs)
  end
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberPostings(postingSet)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  d["transactionResult"] = rs
  return .FederationBankResult~success(d)
::method commitFxPostings
  expose database
  use arg postingSet, sourceAccountId, targetAccountId, sourceCurrencyArg, targetCurrencyArg, sourceAmountMinorArg, targetAmountMinorArg, evidence = .nil, receipt = .nil
  if postingSet == .nil then return .FederationBankResult~failure("LEDGER_POSTINGS_REQUIRED")
  if postingSet~items < 4 then return .FederationBankResult~failure("FX_POSTINGS_REQUIRED")
  bankTxId = postingSet[1]~transactionId
  sourceCurrency = sourceCurrencyArg~string~upper
  targetCurrency = targetCurrencyArg~string~upper
  sourceAmount = sourceAmountMinorArg + 0
  targetAmount = targetAmountMinorArg + 0
  if sourceCurrency = targetCurrency then return .FederationBankResult~failure("FX_CURRENCY_PAIR_INVALID", sourceCurrency)
  if sourceAmount <= 0 | targetAmount <= 0 then return .FederationBankResult~failure("FX_AMOUNT_INVALID")
  postedAt = postingSet[1]~postedAt
  sums = .directory~new
  do posting over postingSet
    if posting == .nil then return .FederationBankResult~failure("LEDGER_POSTING_REQUIRED")
    if posting~transactionId <> bankTxId then return .FederationBankResult~failure("LEDGER_TRANSACTION_MISMATCH")
    if posting~currency <> sourceCurrency & posting~currency <> targetCurrency then return .FederationBankResult~failure("FX_POSTING_CURRENCY_INVALID", posting~currency)
    if posting~amountMinor = 0 then return .FederationBankResult~failure("LEDGER_ZERO_POSTING")
    if posting~amountMinor < 0 & posting~side <> "DEBIT" then return .FederationBankResult~failure("LEDGER_SIDE_INVALID", posting~postingId)
    if posting~amountMinor > 0 & posting~side <> "CREDIT" then return .FederationBankResult~failure("LEDGER_SIDE_INVALID", posting~postingId)
    cur = posting~currency
    current = 0
    if sums~hasIndex(cur) then current = sums[cur]
    sums[cur] = current + posting~amountMinor
  end
  if \sums~hasIndex(sourceCurrency) | \sums~hasIndex(targetCurrency) then return .FederationBankResult~failure("FX_CURRENCY_LEGS_MISSING")
  if sums[sourceCurrency] <> 0 then return .FederationBankResult~failure("FX_SOURCE_NOT_BALANCED", sums[sourceCurrency])
  if sums[targetCurrency] <> 0 then return .FederationBankResult~failure("FX_TARGET_NOT_BALANCED", sums[targetCurrency])

  configured = self~configureWriteTransaction("federationbank:" || bankTxId, evidence, "FederationBank FX ledger commit " || bankTxId)
  if configured~ok = .false then return configured
  tx = configured~value

  header = tx~prepareStatement("fb_fx_tx_insert", -
    "INSERT INTO federationbank_transactions (transaction_id, transaction_kind, currency, target_currency, posted_at, debit_account_id, credit_account_id, amount_minor, target_amount_minor, fee_amount_minor, fee_account_id, fx_quote_id, fx_rate_numerator, fx_rate_denominator, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(header, .array~of(bankTxId, "FX_CONVERT", sourceCurrency, targetCurrency, postedAt~utcIsoDate, sourceAccountId, targetAccountId, sourceAmount, targetAmount, 0, "", self~evidenceAt(evidence,"fxQuoteId"), self~evidenceAt(evidence,"fxRateNumerator"), self~evidenceAt(evidence,"fxRateDenominator"), "COMMITTED"))

  post = tx~prepareStatement("fb_fx_posting_insert", -
    "INSERT INTO federationbank_ledger_postings (posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  do posting over postingSet
    tx~executePrepared(post, .array~of(posting~postingId, bankTxId, posting~accountId, posting~currency, posting~amountMinor, posting~postedAt~utcIsoDate, posting~side, posting~postingRole))
  end

  decision = tx~prepareStatement("fb_fx_decision_insert", -
    "INSERT INTO federationbank_transaction_decisions (transaction_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, fx_policy_id, fx_policy_version, fx_policy_rule_id, fx_quote_id, fx_quote_provider_id, fx_markup_basis_points, fx_rate_numerator, fx_rate_denominator, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id, target_legal_profile_id, target_legal_generation_id, target_legal_generation_version, target_regulatory_profile_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(decision, .array~of(bankTxId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"fxPolicyId"), self~evidenceAt(evidence,"fxPolicyVersion"), self~evidenceAt(evidence,"fxPolicyRuleId"), self~evidenceAt(evidence,"fxQuoteId"), self~evidenceAt(evidence,"fxQuoteProviderId"), self~evidenceAt(evidence,"fxMarkupBasisPoints"), self~evidenceAt(evidence,"fxRateNumerator"), self~evidenceAt(evidence,"fxRateDenominator"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId"), self~evidenceAt(evidence,"targetLegalProfileId"), self~evidenceAt(evidence,"targetLegalGenerationId"), self~evidenceAt(evidence,"targetLegalGenerationVersion"), self~evidenceAt(evidence,"targetRegulatoryProfileId")))

  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then do
    detail = "database transaction " || rs~transactionId || " outcome=" || rs~outcome || " error=" || rs~error
    return .FederationBankResult~failure("LEDGER_DATABASE_ROLLBACK", detail, rs)
  end
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberPostings(postingSet)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  d["transactionResult"] = rs
  return .FederationBankResult~success(d)

::method commitOfflineCashPostings
  expose database
  use arg postingSet, customerAccountId, cashAccountId, amountMinorArg, evidence = .nil, receipt = .nil
  if postingSet == .nil then return .FederationBankResult~failure("LEDGER_POSTINGS_REQUIRED")
  if postingSet~items <> 2 then return .FederationBankResult~failure("ATM_POSTINGS_REQUIRED")
  bankTxId = postingSet[1]~transactionId
  currency = postingSet[1]~currency
  amount = amountMinorArg + 0
  if amount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", amount)
  sum = 0
  do posting over postingSet
    if posting == .nil then return .FederationBankResult~failure("LEDGER_POSTING_REQUIRED")
    if posting~transactionId <> bankTxId then return .FederationBankResult~failure("LEDGER_TRANSACTION_MISMATCH")
    if posting~currency <> currency then return .FederationBankResult~failure("LEDGER_CURRENCY_MISMATCH")
    sum += posting~amountMinor
  end
  if sum <> 0 then return .FederationBankResult~failure("LEDGER_NOT_BALANCED", sum)
  if self~evidenceAt(evidence,"debitAuthority") <> .FederationBankDebitAuthority~SETTLEMENT_MUST_POST then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_INVALID")
  do required over .array~of("terminalId", "atmNetworkId", "offlineAuthorityId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence")
    if self~evidenceAt(evidence, required) = "" then return .FederationBankResult~failure("ATM_SETTLEMENT_EVIDENCE_REQUIRED", required)
  end

  configured = self~configureWriteTransaction("federationbank:" || bankTxId, evidence, "FederationBank offline ATM settlement " || bankTxId)
  if configured~ok = .false then return configured
  tx = configured~value
  postedAt = postingSet[1]~postedAt
  header = tx~prepareStatement("fb_atm_tx_insert", -
    "INSERT INTO federationbank_transactions (transaction_id, transaction_kind, currency, posted_at, debit_account_id, credit_account_id, amount_minor, fee_amount_minor, fee_account_id, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(header, .array~of(bankTxId, "ATM_OFFLINE_WITHDRAWAL", currency, postedAt~utcIsoDate, customerAccountId, cashAccountId, amount, 0, "", "COMMITTED"))

  post = tx~prepareStatement("fb_atm_posting_insert", -
    "INSERT INTO federationbank_ledger_postings (posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  do posting over postingSet
    tx~executePrepared(post, .array~of(posting~postingId, bankTxId, posting~accountId, posting~currency, posting~amountMinor, posting~postedAt~utcIsoDate, posting~side, posting~postingRole))
  end

  decision = tx~prepareStatement("fb_atm_decision_insert", -
    "INSERT INTO federationbank_transaction_decisions (transaction_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(decision, .array~of(bankTxId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId")))

  atmEvidence = tx~prepareStatement("fb_atm_evidence_insert", -
    "INSERT INTO federationbank_atm_settlement_evidence (transaction_id, debit_authority, terminal_id, atm_network_id, offline_authority_id, ruleset_id, rules_version, physical_transaction_id, terminal_sequence, dispensed_minor, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(atmEvidence, .array~of(bankTxId, self~evidenceAt(evidence,"debitAuthority"), self~evidenceAt(evidence,"terminalId"), self~evidenceAt(evidence,"atmNetworkId"), self~evidenceAt(evidence,"offlineAuthorityId"), self~evidenceAt(evidence,"rulesetId"), self~evidenceAt(evidence,"rulesVersion"), self~evidenceAt(evidence,"physicalTransactionId"), self~evidenceAt(evidence,"terminalSequence"), amount, postedAt~utcIsoDate))

  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then do
    detail = "database transaction " || rs~transactionId || " outcome=" || rs~outcome || " error=" || rs~error
    return .FederationBankResult~failure("LEDGER_DATABASE_ROLLBACK", detail, rs)
  end
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberPostings(postingSet)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  d["transactionResult"] = rs
  return .FederationBankResult~success(d)

::method commitAtmWithdrawalPostings
  expose database
  use arg postingSet, customerAccountId, cashAccountId, releasedHold, evidence = .nil, receipt = .nil
  if postingSet == .nil | postingSet~items <> 2 then return .FederationBankResult~failure("ATM_POSTINGS_REQUIRED")
  if releasedHold == .nil then return .FederationBankResult~failure("ATM_HOLD_REQUIRED")
  bankTxId = postingSet[1]~transactionId
  currency = postingSet[1]~currency
  amount = releasedHold~amountMinor
  sum = 0
  do posting over postingSet
    if posting == .nil then return .FederationBankResult~failure("LEDGER_POSTING_REQUIRED")
    if posting~transactionId <> bankTxId then return .FederationBankResult~failure("LEDGER_TRANSACTION_MISMATCH")
    if posting~currency <> currency then return .FederationBankResult~failure("LEDGER_CURRENCY_MISMATCH")
    sum += posting~amountMinor
  end
  if sum <> 0 then return .FederationBankResult~failure("LEDGER_NOT_BALANCED", sum)
  if self~evidenceAt(evidence,"debitAuthority") <> .FederationBankDebitAuthority~RESERVATION_CONSUME then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_INVALID")
  do required over .array~of("terminalId", "atmNetworkId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence", "authorizationId", "holdId")
    if self~evidenceAt(evidence, required) = "" then return .FederationBankResult~failure("ATM_PHYSICAL_EVIDENCE_REQUIRED", required)
  end
  configured = self~configureWriteTransaction("federationbank:" || bankTxId, evidence, "FederationBank online ATM withdrawal " || bankTxId)
  if configured~ok = .false then return configured
  tx = configured~value
  postedAt = postingSet[1]~postedAt
  header = tx~prepareStatement("fb_atm_online_tx_insert", -
    "INSERT INTO federationbank_transactions (transaction_id, transaction_kind, currency, posted_at, debit_account_id, credit_account_id, amount_minor, fee_amount_minor, fee_account_id, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(header, .array~of(bankTxId, "ATM_WITHDRAWAL", currency, postedAt~utcIsoDate, customerAccountId, cashAccountId, amount, 0, "", "COMMITTED"))
  post = tx~prepareStatement("fb_atm_online_posting_insert", -
    "INSERT INTO federationbank_ledger_postings (posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  do posting over postingSet
    tx~executePrepared(post, .array~of(posting~postingId, bankTxId, posting~accountId, posting~currency, posting~amountMinor, posting~postedAt~utcIsoDate, posting~side, posting~postingRole))
  end
  decision = tx~prepareStatement("fb_atm_online_decision_insert", -
    "INSERT INTO federationbank_transaction_decisions (transaction_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(decision, .array~of(bankTxId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId")))
  releasedText = ""
  if releasedHold~releasedAt <> .nil then releasedText = releasedHold~releasedAt~utcIsoDate
  holdUpdate = tx~prepareStatement("fb_atm_hold_consume", -
    "UPDATE federationbank_holds SET status = ?, version = ?, released_at = ? WHERE hold_id = ? AND status = 'ACTIVE'")
  tx~executePrepared(holdUpdate, .array~of(releasedHold~status, releasedHold~version, releasedText, releasedHold~holdId))
  holdEvent = tx~prepareStatement("fb_atm_hold_event_insert", -
    "INSERT INTO federationbank_hold_events (event_id, hold_id, account_id, customer_id, operation, currency, amount_minor, hold_version, status, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, event_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(holdEvent, .array~of(self~receiptAt(receipt,"commandId") || ":CONSUME_HOLD", releasedHold~holdId, releasedHold~accountId, releasedHold~customerId, "CONSUME_HOLD", releasedHold~currency, releasedHold~amountMinor, releasedHold~version, releasedHold~status, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), postedAt~utcIsoDate))
  physical = tx~prepareStatement("fb_atm_physical_evidence_insert", -
    "INSERT INTO federationbank_atm_physical_evidence (transaction_id, operation, terminal_id, atm_network_id, ruleset_id, rules_version, physical_transaction_id, terminal_sequence, amount_minor, authorization_id, hold_id, evidence_state, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(physical, .array~of(bankTxId, "WITHDRAW_COMMIT", self~evidenceAt(evidence,"terminalId"), self~evidenceAt(evidence,"atmNetworkId"), self~evidenceAt(evidence,"rulesetId"), self~evidenceAt(evidence,"rulesVersion"), self~evidenceAt(evidence,"physicalTransactionId"), self~evidenceAt(evidence,"terminalSequence"), amount, self~evidenceAt(evidence,"authorizationId"), self~evidenceAt(evidence,"holdId"), "DISPENSED", postedAt~utcIsoDate))
  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("LEDGER_DATABASE_ROLLBACK", rs~outcome || ":" || rs~error, rs)
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberPostings(postingSet)
  self~fixtureRememberHold(releasedHold)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId; d["databaseOutcome"] = rs~outcome; d["databaseAttempts"] = rs~attemptCount; d["databaseOperationCount"] = rs~operationCount
  return .FederationBankResult~success(d)

::method commitAtmDepositPostings
  expose database
  use arg postingSet, customerAccountId, cashAccountId, amountMinorArg, evidence = .nil, receipt = .nil
  if postingSet == .nil | postingSet~items <> 2 then return .FederationBankResult~failure("ATM_POSTINGS_REQUIRED")
  bankTxId = postingSet[1]~transactionId; currency = postingSet[1]~currency; amount = amountMinorArg + 0
  if amount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", amount)
  sum = 0
  do posting over postingSet
    if posting == .nil then return .FederationBankResult~failure("LEDGER_POSTING_REQUIRED")
    if posting~transactionId <> bankTxId then return .FederationBankResult~failure("LEDGER_TRANSACTION_MISMATCH")
    if posting~currency <> currency then return .FederationBankResult~failure("LEDGER_CURRENCY_MISMATCH")
    sum += posting~amountMinor
  end
  if sum <> 0 then return .FederationBankResult~failure("LEDGER_NOT_BALANCED", sum)
  do required over .array~of("terminalId", "atmNetworkId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence")
    if self~evidenceAt(evidence, required) = "" then return .FederationBankResult~failure("ATM_PHYSICAL_EVIDENCE_REQUIRED", required)
  end
  configured = self~configureWriteTransaction("federationbank:" || bankTxId, evidence, "FederationBank ATM deposit " || bankTxId)
  if configured~ok = .false then return configured
  tx = configured~value; postedAt = postingSet[1]~postedAt
  header = tx~prepareStatement("fb_atm_deposit_tx_insert", -
    "INSERT INTO federationbank_transactions (transaction_id, transaction_kind, currency, posted_at, debit_account_id, credit_account_id, amount_minor, fee_amount_minor, fee_account_id, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(header, .array~of(bankTxId, "ATM_DEPOSIT", currency, postedAt~utcIsoDate, cashAccountId, customerAccountId, amount, 0, "", "COMMITTED"))
  post = tx~prepareStatement("fb_atm_deposit_posting_insert", -
    "INSERT INTO federationbank_ledger_postings (posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  do posting over postingSet
    tx~executePrepared(post, .array~of(posting~postingId, bankTxId, posting~accountId, posting~currency, posting~amountMinor, posting~postedAt~utcIsoDate, posting~side, posting~postingRole))
  end
  decision = tx~prepareStatement("fb_atm_deposit_decision_insert", -
    "INSERT INTO federationbank_transaction_decisions (transaction_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(decision, .array~of(bankTxId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId")))
  physical = tx~prepareStatement("fb_atm_deposit_evidence_insert", -
    "INSERT INTO federationbank_atm_physical_evidence (transaction_id, operation, terminal_id, atm_network_id, ruleset_id, rules_version, physical_transaction_id, terminal_sequence, amount_minor, authorization_id, hold_id, evidence_state, recorded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(physical, .array~of(bankTxId, "DEPOSIT_COMMIT", self~evidenceAt(evidence,"terminalId"), self~evidenceAt(evidence,"atmNetworkId"), self~evidenceAt(evidence,"rulesetId"), self~evidenceAt(evidence,"rulesVersion"), self~evidenceAt(evidence,"physicalTransactionId"), self~evidenceAt(evidence,"terminalSequence"), amount, "", "", "CASH_ACCEPTED", postedAt~utcIsoDate))
  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("LEDGER_DATABASE_ROLLBACK", rs~outcome || ":" || rs~error, rs)
  self~fixtureRememberReceipt(receipt); self~fixtureRememberPostings(postingSet)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId; d["databaseOutcome"] = rs~outcome; d["databaseAttempts"] = rs~attemptCount; d["databaseOperationCount"] = rs~operationCount
  return .FederationBankResult~success(d)

::method recoverPostings
  expose database
  context = .DatabaseExecutionContext~new(.nil, "FederationBank ledger posting recovery")
  tx = database~transaction(context, .DatabaseTransactionIdentity~new("federationbank:ledger:recover"))
  ignored = tx~isolation(.DatabaseIsolation~READCOMMITTED)
  ignored = tx~readOnly
  stmt = tx~prepareStatement("fb_postings_recover", -
    "SELECT posting_id, transaction_id, account_id, currency, amount_minor, posted_at, side, posting_role FROM federationbank_ledger_postings ORDER BY posted_at, posting_id")
  ref = tx~queryPrepared(stmt, .array~new)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("LEDGER_RECOVERY_DATABASE_READ_FAILED", rs~outcome || ":" || rs~error, rs)
  if ref~resolved = .false then return .FederationBankResult~failure("LEDGER_RECOVERY_DATABASE_READ_FAILED", "deferred result unresolved")
  qr = ref~result
  out = .array~new
  do row over qr~rows
    iso = row~valueAt("posted_at")~string
    if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
    if iso = "" then postedAt = .DateTime~new
    else postedAt = .DateTime~fromIsoDate(iso)
    out~append(.FederationBankPosting~new(row~valueAt("posting_id"), row~valueAt("transaction_id"), row~valueAt("account_id"), row~valueAt("currency"), row~valueAt("amount_minor"), postedAt, row~valueAt("side"), row~valueAt("posting_role")))
  end
  return .FederationBankResult~success(out)

::method commitOpenAccount
  use arg customer, account, isNewCustomer, evidence = .nil, receipt = .nil
  if customer == .nil | account == .nil then return .FederationBankResult~failure("ACCOUNT_OPEN_STATE_REQUIRED")
  idem = self~receiptAt(receipt, "idempotencyKey")
  if idem = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  configured = self~configureWriteTransaction("federationbank:" || idem, evidence, "FederationBank account opening " || idem)
  if configured~ok = .false then return configured
  tx = configured~value

  if isNewCustomer then do
    cstmt = tx~prepareStatement("fb_customer_insert", -
      "INSERT INTO federationbank_customers (customer_id, legal_name, date_of_birth, postcode, address_country, segment, domicile, residence, risk_tier, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
    tx~executePrepared(cstmt, .array~of(customer~customerId, customer~legalName, customer~dateOfBirth, customer~postcode, customer~addressCountry, customer~segment, customer~domicile, customer~residence, customer~riskTier, self~receiptAt(receipt,"createdAt",.DateTime~new~utcIsoDate)))
  end

  astmt = tx~prepareStatement("fb_account_insert", -
    "INSERT INTO federationbank_accounts (account_id, customer_id, currency, product_code, booking_jurisdiction, regulatory_profile_id, status, opened_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(astmt, .array~of(account~accountId, account~customerId, account~currency, account~productCode, account~bookingJurisdiction, account~regulatoryProfileId, account~status, self~receiptAt(receipt,"createdAt",.DateTime~new~utcIsoDate)))

  ostmt = tx~prepareStatement("fb_opening_decision_insert", -
    "INSERT INTO federationbank_account_opening_decisions (idempotency_key, command_id, customer_id, account_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, regulatory_profile_id, address_verification_reference, address_contract_generation, address_mapping_generation, credit_bureau_reference, credit_status, credit_score, outcome) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(ostmt, .array~of(idem, self~receiptAt(receipt,"commandId"), customer~customerId, account~accountId, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~evidenceAt(evidence,"regulatoryProfileId"), self~evidenceAt(evidence,"addressVerificationReference"), self~evidenceAt(evidence,"addressContractGeneration"), self~evidenceAt(evidence,"addressMappingGeneration"), self~evidenceAt(evidence,"creditBureauReference"), self~evidenceAt(evidence,"creditStatus"), self~nullableNumber(self~evidenceAt(evidence,"creditScore")), self~receiptAt(receipt,"outcome","ACCEPTED")))

  self~insertCreditIntelligenceEvidence(tx, idem, evidence)
  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then do
    detail = "database transaction " || rs~transactionId || " outcome=" || rs~outcome || " error=" || rs~error
    return .FederationBankResult~failure("CORE_DATABASE_ROLLBACK", detail, rs)
  end
  self~fixtureRememberReceipt(receipt)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  return .FederationBankResult~success(d)
::method fixtureRememberBeneficiary private
  expose database
  use arg beneficiary
  if beneficiary == .nil then return
  executor = database~executor
  if executor~hasMethod("REMEMBERBENEFICIARY") then executor~rememberBeneficiary(beneficiary)
::method commitBeneficiaryChange
  use arg beneficiary, operation, evidence = .nil, receipt = .nil
  if beneficiary == .nil then return .FederationBankResult~failure("BENEFICIARY_REQUIRED")
  op = operation~string~upper
  if op <> "ADD_BENEFICIARY" & op <> "AMEND_BENEFICIARY" & op <> "SUSPEND_BENEFICIARY" then return .FederationBankResult~failure("BENEFICIARY_OPERATION_INVALID", op)
  idem = self~receiptAt(receipt, "idempotencyKey")
  if idem = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  configured = self~configureWriteTransaction("federationbank:beneficiary:" || idem, evidence, "FederationBank beneficiary lifecycle " || idem)
  if configured~ok = .false then return configured
  tx = configured~value
  if op = "ADD_BENEFICIARY" then do
    stmt = tx~prepareStatement("fb_beneficiary_insert", -
      "INSERT INTO federationbank_beneficiaries (customer_id, beneficiary_id, owner_account_id, display_name, account_reference, bank_code, country, currency, status, version, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
    tx~executePrepared(stmt, .array~of(beneficiary~customerId, beneficiary~beneficiaryId, beneficiary~ownerAccountId, beneficiary~displayName, beneficiary~accountReference, beneficiary~bankCode, beneficiary~country, beneficiary~currency, beneficiary~status, beneficiary~version, beneficiary~updatedAt~utcIsoDate))
  end
  else do
    stmt = tx~prepareStatement("fb_beneficiary_update", -
      "UPDATE federationbank_beneficiaries SET display_name = ?, account_reference = ?, bank_code = ?, country = ?, currency = ?, status = ?, version = ?, updated_at = ? WHERE customer_id = ? AND beneficiary_id = ?")
    tx~executePrepared(stmt, .array~of(beneficiary~displayName, beneficiary~accountReference, beneficiary~bankCode, beneficiary~country, beneficiary~currency, beneficiary~status, beneficiary~version, beneficiary~updatedAt~utcIsoDate, beneficiary~customerId, beneficiary~beneficiaryId))
  end
  event = tx~prepareStatement("fb_beneficiary_event_insert", -
    "INSERT INTO federationbank_beneficiary_events (event_id, customer_id, beneficiary_id, owner_account_id, operation, beneficiary_version, status, display_name, account_reference, bank_code, country, currency, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, event_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  tx~executePrepared(event, .array~of(idem, beneficiary~customerId, beneficiary~beneficiaryId, beneficiary~ownerAccountId, op, beneficiary~version, beneficiary~status, beneficiary~displayName, beneficiary~accountReference, beneficiary~bankCode, beneficiary~country, beneficiary~currency, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), beneficiary~updatedAt~utcIsoDate))
  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then do
    detail = "database transaction " || rs~transactionId || " outcome=" || rs~outcome || " error=" || rs~error
    return .FederationBankResult~failure("BENEFICIARY_DATABASE_ROLLBACK", detail, rs)
  end
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberBeneficiary(beneficiary)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  return .FederationBankResult~success(d)
::method recoverBeneficiaries
  expose database
  context = .DatabaseExecutionContext~new(.nil, "FederationBank beneficiary recovery")
  tx = database~transaction(context, .DatabaseTransactionIdentity~new("federationbank:beneficiaries:recover"))
  ignored = tx~isolation(.DatabaseIsolation~READCOMMITTED)
  ignored = tx~readOnly
  stmt = tx~prepareStatement("fb_beneficiaries_recover", -
    "SELECT customer_id, beneficiary_id, owner_account_id, display_name, account_reference, bank_code, country, currency, status, version, updated_at FROM federationbank_beneficiaries ORDER BY customer_id, beneficiary_id")
  ref = tx~queryPrepared(stmt, .array~new)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("BENEFICIARY_RECOVERY_DATABASE_READ_FAILED", rs~outcome || ":" || rs~error, rs)
  if ref~resolved = .false then return .FederationBankResult~failure("BENEFICIARY_RECOVERY_DATABASE_READ_FAILED", "deferred result unresolved")
  out = .array~new
  do row over ref~result~rows
    iso = row~valueAt("updated_at")~string
    if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
    if iso = "" then atTime = .DateTime~new
    else atTime = .DateTime~fromIsoDate(iso)
    out~append(.FederationBankBeneficiary~new(row~valueAt("beneficiary_id"), row~valueAt("customer_id"), row~valueAt("owner_account_id"), row~valueAt("display_name"), row~valueAt("account_reference"), row~valueAt("bank_code"), row~valueAt("country"), row~valueAt("currency"), row~valueAt("status"), row~valueAt("version"), atTime))
  end
  return .FederationBankResult~success(out)

::method fixtureRememberHold private
  expose database
  use arg hold
  if hold == .nil then return
  executor = database~executor
  if executor~hasMethod("REMEMBERHOLD") then executor~rememberHold(hold)
::method commitHoldChange
  use arg hold, operation, evidence = .nil, receipt = .nil
  if hold == .nil then return .FederationBankResult~failure("HOLD_REQUIRED")
  op = operation~string~upper
  if op <> "PLACE_HOLD" & op <> "RELEASE_HOLD" then return .FederationBankResult~failure("HOLD_OPERATION_INVALID", op)
  idem = self~receiptAt(receipt, "idempotencyKey")
  if idem = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  configured = self~configureWriteTransaction("federationbank:hold:" || idem, evidence, "FederationBank hold lifecycle " || idem)
  if configured~ok = .false then return configured
  tx = configured~value
  if op = "PLACE_HOLD" then do
    stmt = tx~prepareStatement("fb_hold_insert", -
      "INSERT INTO federationbank_holds (hold_id, account_id, customer_id, currency, amount_minor, status, version, placed_at, released_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
    tx~executePrepared(stmt, .array~of(hold~holdId, hold~accountId, hold~customerId, hold~currency, hold~amountMinor, hold~status, hold~version, hold~placedAt~utcIsoDate, .nil))
  end
  else do
    releasedText = ""
    if hold~releasedAt <> .nil then releasedText = hold~releasedAt~utcIsoDate
    stmt = tx~prepareStatement("fb_hold_release", -
      "UPDATE federationbank_holds SET status = ?, version = ?, released_at = ? WHERE hold_id = ? AND status = 'ACTIVE'")
    tx~executePrepared(stmt, .array~of(hold~status, hold~version, releasedText, hold~holdId))
  end
  event = tx~prepareStatement("fb_hold_event_insert", -
    "INSERT INTO federationbank_hold_events (event_id, hold_id, account_id, customer_id, operation, currency, amount_minor, hold_version, status, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, event_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  eventId = self~receiptAt(receipt,"commandId") || ":" || op
  tx~executePrepared(event, .array~of(eventId, hold~holdId, hold~accountId, hold~customerId, op, hold~currency, hold~amountMinor, hold~version, hold~status, self~evidenceAt(evidence,"securityPolicyId"), self~evidenceAt(evidence,"securityPolicyVersion"), self~evidenceAt(evidence,"securityDisposition"), self~evidenceAt(evidence,"corporatePolicyId"), self~evidenceAt(evidence,"corporatePolicyVersion"), self~evidenceAt(evidence,"corporatePolicyRuleId"), self~evidenceAt(evidence,"legalProfileId"), self~evidenceAt(evidence,"legalGenerationId"), self~evidenceAt(evidence,"legalGenerationVersion"), self~receiptAt(receipt,"createdAt",.DateTime~new~utcIsoDate)))
  self~insertReceipt(tx, receipt)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("HOLD_DATABASE_ROLLBACK", rs~outcome || ":" || rs~error, rs)
  self~fixtureRememberReceipt(receipt)
  self~fixtureRememberHold(hold)
  d = .directory~new
  d["databaseTransactionId"] = rs~transactionId
  d["databaseOutcome"] = rs~outcome
  d["databaseAttempts"] = rs~attemptCount
  d["databaseOperationCount"] = rs~operationCount
  return .FederationBankResult~success(d)
::method recoverHolds
  expose database
  context = .DatabaseExecutionContext~new(.nil, "FederationBank hold recovery")
  tx = database~transaction(context, .DatabaseTransactionIdentity~new("federationbank:holds:recover"))
  ignored = tx~isolation(.DatabaseIsolation~READCOMMITTED)
  ignored = tx~readOnly
  stmt = tx~prepareStatement("fb_holds_recover", -
    "SELECT hold_id, account_id, customer_id, currency, amount_minor, status, version, placed_at, released_at FROM federationbank_holds ORDER BY placed_at, hold_id")
  ref = tx~queryPrepared(stmt, .array~new)
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("HOLD_RECOVERY_DATABASE_READ_FAILED", rs~outcome || ":" || rs~error, rs)
  if ref~resolved = .false then return .FederationBankResult~failure("HOLD_RECOVERY_DATABASE_READ_FAILED", "deferred result unresolved")
  out = .array~new
  do row over ref~result~rows
    placedIso = row~valueAt("placed_at")~string
    if placedIso~right(1) = "Z" then placedIso = placedIso~left(placedIso~length - 1)
    if placedIso = "" then placedAt = .DateTime~new
    else placedAt = .DateTime~fromIsoDate(placedIso)
    releasedIso = row~valueAt("released_at")~string
    if releasedIso~right(1) = "Z" then releasedIso = releasedIso~left(releasedIso~length - 1)
    if releasedIso = "" then releasedAt = .nil
    else releasedAt = .DateTime~fromIsoDate(releasedIso)
    out~append(.FederationBankHold~new(row~valueAt("hold_id"), row~valueAt("account_id"), row~valueAt("customer_id"), row~valueAt("currency"), row~valueAt("amount_minor"), row~valueAt("status"), placedAt, releasedAt, row~valueAt("version")))
  end
  return .FederationBankResult~success(out)

::method recoverReceipt
  expose database
  use arg idempotencyKey
  key = idempotencyKey~string
  if key = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  context = .DatabaseExecutionContext~new(.nil, "FederationBank receipt recovery " || key)
  tx = database~transaction(context, .DatabaseTransactionIdentity~new("federationbank:receipt:" || key))
  ignored = tx~isolation(.DatabaseIsolation~READCOMMITTED)
  ignored = tx~readOnly
  stmt = tx~prepareStatement("fb_receipt_select", -
    "SELECT idempotency_key, command_id, operation, outcome_code, customer_id, account_id, transaction_id, currency, amount_minor, regulatory_profile_id, security_policy_id, security_policy_version, security_disposition, corporate_policy_id, corporate_policy_version, corporate_policy_rule_id, legal_profile_id, legal_generation_id, legal_generation_version, address_verification_reference, credit_bureau_reference, credit_status, credit_score, created_at, result_payload FROM federationbank_command_receipts WHERE idempotency_key = ?")
  ref = tx~queryPrepared(stmt, .array~of(key))
  rs = tx~commit
  if rs~committed = .false then return .FederationBankResult~failure("RECEIPT_DATABASE_READ_FAILED", rs~outcome || ":" || rs~error, rs)
  if ref~resolved = .false then return .FederationBankResult~failure("RECEIPT_DATABASE_READ_FAILED", "deferred result unresolved")
  qr = ref~result
  if qr~rowCount = 0 then return .FederationBankResult~success(.nil, "NOT_FOUND")
  row = qr~rows[1]
  d = .directory~new
  rawPayload = row~valueAt("result_payload")~string
  if rawPayload <> "" then do
    decoded = .QueueGraphPayloadCodec~new~decode(x2c(rawPayload))
    if decoded~isA(.Directory) then d = decoded
  end
  d["idempotencyKey"] = row~valueAt("idempotency_key")
  d["commandId"] = row~valueAt("command_id")
  d["operation"] = row~valueAt("operation")
  d["outcome"] = row~valueAt("outcome_code")
  d["customerId"] = row~valueAt("customer_id")
  d["accountId"] = row~valueAt("account_id")
  d["transactionId"] = row~valueAt("transaction_id")
  d["currency"] = row~valueAt("currency")
  d["amountMinor"] = row~valueAt("amount_minor")
  d["regulatoryProfileId"] = row~valueAt("regulatory_profile_id")
  d["securityPolicyId"] = row~valueAt("security_policy_id")
  d["securityPolicyVersion"] = row~valueAt("security_policy_version")
  d["securityDisposition"] = row~valueAt("security_disposition")
  d["corporatePolicyId"] = row~valueAt("corporate_policy_id")
  d["corporatePolicyVersion"] = row~valueAt("corporate_policy_version")
  d["corporatePolicyRuleId"] = row~valueAt("corporate_policy_rule_id")
  d["legalProfileId"] = row~valueAt("legal_profile_id")
  d["legalGenerationId"] = row~valueAt("legal_generation_id")
  d["legalGenerationVersion"] = row~valueAt("legal_generation_version")
  d["addressVerificationReference"] = row~valueAt("address_verification_reference")
  d["creditBureauReference"] = row~valueAt("credit_bureau_reference")
  d["creditStatus"] = row~valueAt("credit_status")
  d["creditScore"] = row~valueAt("credit_score")
  d["createdAt"] = row~valueAt("created_at")
  d["recoveredFromDurableReceipt"] = "true"
  return .FederationBankResult~success(d)

::class FederationBankLedger public
::method init
  expose accounts postings transactions sequence store holds
  use arg storeArg = .nil
  accounts = .directory~new
  postings = .array~new
  transactions = .directory~new
  holds = .directory~new
  sequence = 0
  store = storeArg
::method durable
  expose store
  return store <> .nil
::method store
  expose store
  return store
::method addAccount
  expose accounts
  use arg account
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_REQUIRED")
  if accounts~hasIndex(account~accountId) then return .FederationBankResult~failure("ACCOUNT_DUPLICATE", account~accountId)
  accounts[account~accountId] = account
  return .FederationBankResult~success(account)
::method account
  expose accounts
  use arg accountId
  if accounts~hasIndex(accountId~string) then return accounts[accountId~string]
  return .nil
::method hasTransaction
  expose transactions
  use arg transactionId
  return transactions~hasIndex(transactionId~string)
::method balanceMinor
  expose accounts postings
  use arg accountId
  if accounts~hasIndex(accountId~string) = .false then return .nil
  total = 0
  do posting over postings
    if posting~accountId = accountId~string then total += posting~amountMinor
  end
  return total
::method hold
  expose holds
  use arg holdId
  key = holdId~string
  if holds~hasIndex(key) then return holds[key]
  return .nil
::method activeHeldMinor
  expose holds
  use arg accountId
  total = 0
  aid = accountId~string
  do key over holds
    h = holds[key]
    if h~accountId = aid & h~status = "ACTIVE" then total += h~amountMinor
  end
  return total
::method availableBalanceMinor
  use arg accountId
  account = self~account(accountId)
  if account == .nil then return .nil
  book = self~balanceMinor(accountId)
  if account~allowNegative then return book - self~activeHeldMinor(accountId)
  return book + account~authorisedOverdraftMinor - self~activeHeldMinor(accountId)
::method fundsState
  use arg accountId
  account = self~account(accountId)
  if account == .nil then return .nil
  book = self~balanceMinor(accountId)
  held = self~activeHeldMinor(accountId)
  overdraft = account~authorisedOverdraftMinor
  excess = 0
  if account~allowNegative = .false then do
    floor = 0 - overdraft
    if book < floor then excess = floor - book
  end
  d = .directory~new
  d["bookBalanceMinor"] = book
  d["activeHeldMinor"] = held
  d["authorisedOverdraftMinor"] = overdraft
  d["availableBalanceMinor"] = self~availableBalanceMinor(accountId)
  d["unauthorisedExcessMinor"] = excess
  if account~allowNegative then state = "INTERNAL_UNRESTRICTED"
  else if excess > 0 then state = "UNAUTHORISED_EXCESS"
  else if book < 0 then state = "AUTHORISED_OVERDRAFT"
  else state = "IN_CREDIT"
  d["fundsState"] = state
  if excess > 0 then d["withdrawalsBlocked"] = .true
  else d["withdrawalsBlocked"] = .false
  return d
::method placeHold
  expose accounts holds store
  use arg holdId, accountId, customerId, amountMinor, currency, atTime = .nil, evidence = .nil, receipt = .nil
  hid = holdId~string
  if hid = "" then return .FederationBankResult~failure("HOLD_ID_REQUIRED")
  if holds~hasIndex(hid) then return .FederationBankResult~failure("HOLD_DUPLICATE", hid)
  account = self~account(accountId)
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND", accountId)
  if account~status <> "OPEN" then return .FederationBankResult~failure("ACCOUNT_NOT_OPEN", accountId)
  cur = currency~string~upper
  if account~currency <> cur then return .FederationBankResult~failure("CURRENCY_MISMATCH", cur)
  if account~internalAccount = .false & account~customerId <> customerId~string then return .FederationBankResult~failure("ACCOUNT_CUSTOMER_MISMATCH")
  amount = amountMinor + 0
  if amount <= 0 then return .FederationBankResult~failure("HOLD_AMOUNT_INVALID", amount)
  available = self~availableBalanceMinor(accountId)
  if account~allowNegative = .false then if available < amount then return .FederationBankResult~failure("INSUFFICIENT_AVAILABLE_FUNDS", available)
  if atTime == .nil then atTime = .DateTime~new
  h = .FederationBankHold~new(hid, account~accountId, customerId, cur, amount, "ACTIVE", atTime, .nil, 1)
  db = .nil
  if store <> .nil then do
    db = store~commitHoldChange(h, "PLACE_HOLD", evidence, receipt)
    if db~ok = .false then return db
  end
  holds[hid] = h
  d = h~asDirectory
  d["bookBalanceMinor"] = self~balanceMinor(accountId)
  d["availableBalanceMinor"] = self~availableBalanceMinor(accountId)
  if db <> .nil then do
    d["databaseTransactionId"] = db~value["databaseTransactionId"]
    d["databaseOutcome"] = db~value["databaseOutcome"]
    d["databaseAttempts"] = db~value["databaseAttempts"]
  end
  return .FederationBankResult~success(d)
::method releaseHold
  expose holds store
  use arg holdId, customerId, atTime = .nil, evidence = .nil, receipt = .nil
  hid = holdId~string
  if hid = "" then return .FederationBankResult~failure("HOLD_ID_REQUIRED")
  if \holds~hasIndex(hid) then return .FederationBankResult~failure("HOLD_NOT_FOUND", hid)
  current = holds[hid]
  if current~status <> "ACTIVE" then return .FederationBankResult~failure("HOLD_NOT_ACTIVE", hid)
  if current~customerId <> customerId~string then return .FederationBankResult~failure("HOLD_CUSTOMER_MISMATCH")
  if atTime == .nil then atTime = .DateTime~new
  released = current~released(atTime)
  db = .nil
  if store <> .nil then do
    db = store~commitHoldChange(released, "RELEASE_HOLD", evidence, receipt)
    if db~ok = .false then return db
  end
  holds[hid] = released
  d = released~asDirectory
  d["bookBalanceMinor"] = self~balanceMinor(released~accountId)
  d["availableBalanceMinor"] = self~availableBalanceMinor(released~accountId)
  if db <> .nil then do
    d["databaseTransactionId"] = db~value["databaseTransactionId"]
    d["databaseOutcome"] = db~value["databaseOutcome"]
    d["databaseAttempts"] = db~value["databaseAttempts"]
  end
  return .FederationBankResult~success(d)
::method postings
  expose postings
  copy = .array~new
  do item over postings
    copy~append(item)
  end
  return copy
::method transactionPostings
  expose transactions
  use arg transactionId
  key = transactionId~string
  if transactions~hasIndex(key) = .false then return .array~new
  out = .array~new
  do p over transactions[key]
    out~append(p)
  end
  return out
::method postTransfer
  expose accounts postings transactions sequence store
  use arg transactionId, debitAccountId, creditAccountId, amountMinor, currency, postedAt = .nil, evidence = .nil, receipt = .nil, feeAmountMinorArg = 0, feeIncomeAccountIdArg = ""
  tx = transactionId~string
  cur = currency~string~upper
  amount = amountMinor + 0
  feeAmount = feeAmountMinorArg + 0
  feeAccountId = feeIncomeAccountIdArg~string
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  if transactions~hasIndex(tx) then return .FederationBankResult~failure("TRANSACTION_DUPLICATE", tx)
  if amount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", amount)
  if feeAmount < 0 then return .FederationBankResult~failure("FEE_AMOUNT_INVALID", feeAmount)
  debit = self~account(debitAccountId)
  credit = self~account(creditAccountId)
  if debit == .nil then return .FederationBankResult~failure("DEBIT_ACCOUNT_NOT_FOUND", debitAccountId)
  if credit == .nil then return .FederationBankResult~failure("CREDIT_ACCOUNT_NOT_FOUND", creditAccountId)
  if debit~status <> "OPEN" | credit~status <> "OPEN" then return .FederationBankResult~failure("ACCOUNT_NOT_OPEN")
  if debit~currency <> cur | credit~currency <> cur then return .FederationBankResult~failure("CURRENCY_MISMATCH", cur)
  if debit~accountId = credit~accountId then return .FederationBankResult~failure("SAME_ACCOUNT_TRANSFER")
  feeAccount = .nil
  if feeAmount > 0 then do
    if feeAccountId = "" then return .FederationBankResult~failure("FEE_INCOME_ACCOUNT_REQUIRED")
    feeAccount = self~account(feeAccountId)
    if feeAccount == .nil then return .FederationBankResult~failure("FEE_INCOME_ACCOUNT_NOT_FOUND", feeAccountId)
    if feeAccount~internalAccount = .false then return .FederationBankResult~failure("FEE_INCOME_ACCOUNT_NOT_INTERNAL", feeAccountId)
    if feeAccount~currency <> cur then return .FederationBankResult~failure("FEE_INCOME_CURRENCY_MISMATCH", cur)
    if feeAccount~status <> "OPEN" then return .FederationBankResult~failure("FEE_INCOME_ACCOUNT_NOT_OPEN", feeAccountId)
  end
  availableBalance = self~availableBalanceMinor(debit~accountId)
  totalDebit = amount + feeAmount
  if debit~allowNegative = .false then if availableBalance < totalDebit then return .FederationBankResult~failure("INSUFFICIENT_AVAILABLE_FUNDS", availableBalance)
  if postedAt == .nil then postedAt = .DateTime~new
  sequenceBefore = sequence
  postingSet = .array~new
  sequence += 1
  transferDebit = .FederationBankPosting~new("P" || sequence || "TD", tx, debit~accountId, cur, 0 - amount, postedAt, "DEBIT", "TRANSFER_DEBIT")
  postingSet~append(transferDebit)
  sequence += 1
  transferCredit = .FederationBankPosting~new("P" || sequence || "TC", tx, credit~accountId, cur, amount, postedAt, "CREDIT", "TRANSFER_CREDIT")
  postingSet~append(transferCredit)
  if feeAmount > 0 then do
    sequence += 1
    feeDebit = .FederationBankPosting~new("P" || sequence || "FD", tx, debit~accountId, cur, 0 - feeAmount, postedAt, "DEBIT", "FEE_DEBIT")
    postingSet~append(feeDebit)
    sequence += 1
    feeCredit = .FederationBankPosting~new("P" || sequence || "FC", tx, feeAccountId, cur, feeAmount, postedAt, "CREDIT", "FEE_CREDIT")
    postingSet~append(feeCredit)
  end
  databaseCommit = .nil
  if store <> .nil then do
    databaseCommit = store~commitTransferPostings(postingSet, debit~accountId, credit~accountId, amount, feeAmount, feeAccountId, evidence, receipt)
    if databaseCommit~ok = .false then do
      sequence = sequenceBefore
      return databaseCommit
    end
  end
  do posting over postingSet
    postings~append(posting)
  end
  transactions[tx] = postingSet
  d = .directory~new
  d["postings"] = postingSet
  d["transferAmountMinor"] = amount
  d["feeAmountMinor"] = feeAmount
  d["totalDebitMinor"] = totalDebit
  d["feeIncomeAccountId"] = feeAccountId
  if databaseCommit <> .nil then do
    d["databaseTransactionId"] = databaseCommit~value["databaseTransactionId"]
    d["databaseOutcome"] = databaseCommit~value["databaseOutcome"]
    d["databaseAttempts"] = databaseCommit~value["databaseAttempts"]
    d["databaseOperationCount"] = databaseCommit~value["databaseOperationCount"]
  end
  return .FederationBankResult~success(d)

::method postFxConversion
  expose accounts postings transactions sequence store
  use arg transactionId, sourceAccountId, targetAccountId, sourceAmountMinor, targetAmountMinor, sourceCurrencyArg, targetCurrencyArg, sourcePositionAccountId, targetPositionAccountId, postedAt = .nil, evidence = .nil, receipt = .nil
  tx = transactionId~string
  sourceCurrency = sourceCurrencyArg~string~upper
  targetCurrency = targetCurrencyArg~string~upper
  sourceAmount = sourceAmountMinor + 0
  targetAmount = targetAmountMinor + 0
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  if transactions~hasIndex(tx) then return .FederationBankResult~failure("TRANSACTION_DUPLICATE", tx)
  if sourceCurrency = targetCurrency then return .FederationBankResult~failure("FX_CURRENCY_PAIR_INVALID", sourceCurrency)
  if sourceAmount <= 0 | targetAmount <= 0 then return .FederationBankResult~failure("FX_AMOUNT_INVALID")
  source = self~account(sourceAccountId)
  target = self~account(targetAccountId)
  sourcePosition = self~account(sourcePositionAccountId)
  targetPosition = self~account(targetPositionAccountId)
  if source == .nil then return .FederationBankResult~failure("DEBIT_ACCOUNT_NOT_FOUND", sourceAccountId)
  if target == .nil then return .FederationBankResult~failure("CREDIT_ACCOUNT_NOT_FOUND", targetAccountId)
  if sourcePosition == .nil | targetPosition == .nil then return .FederationBankResult~failure("FX_POSITION_ACCOUNT_NOT_FOUND")
  if source~status <> "OPEN" | target~status <> "OPEN" then return .FederationBankResult~failure("ACCOUNT_NOT_OPEN")
  if source~currency <> sourceCurrency | target~currency <> targetCurrency then return .FederationBankResult~failure("FX_ACCOUNT_CURRENCY_MISMATCH")
  if sourcePosition~currency <> sourceCurrency | targetPosition~currency <> targetCurrency then return .FederationBankResult~failure("FX_POSITION_CURRENCY_MISMATCH")
  if sourcePosition~internalAccount = .false | targetPosition~internalAccount = .false then return .FederationBankResult~failure("FX_POSITION_ACCOUNT_NOT_INTERNAL")
  available = self~availableBalanceMinor(source~accountId)
  if source~allowNegative = .false then if available < sourceAmount then return .FederationBankResult~failure("INSUFFICIENT_AVAILABLE_FUNDS", available)
  if postedAt == .nil then postedAt = .DateTime~new
  sequenceBefore = sequence
  postingSet = .array~new
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "FXSD", tx, source~accountId, sourceCurrency, 0 - sourceAmount, postedAt, "DEBIT", "FX_SOURCE_DEBIT"))
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "FXSC", tx, sourcePosition~accountId, sourceCurrency, sourceAmount, postedAt, "CREDIT", "FX_SOURCE_POSITION_CREDIT"))
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "FXTD", tx, targetPosition~accountId, targetCurrency, 0 - targetAmount, postedAt, "DEBIT", "FX_TARGET_POSITION_DEBIT"))
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "FXTC", tx, target~accountId, targetCurrency, targetAmount, postedAt, "CREDIT", "FX_TARGET_CREDIT"))
  databaseCommit = .nil
  if store <> .nil then do
    databaseCommit = store~commitFxPostings(postingSet, source~accountId, target~accountId, sourceCurrency, targetCurrency, sourceAmount, targetAmount, evidence, receipt)
    if databaseCommit~ok = .false then do
      sequence = sequenceBefore
      return databaseCommit
    end
  end
  do posting over postingSet
    postings~append(posting)
  end
  transactions[tx] = postingSet
  d = .directory~new
  d["postings"] = postingSet
  d["sourceAmountMinor"] = sourceAmount
  d["targetAmountMinor"] = targetAmount
  d["sourceCurrency"] = sourceCurrency
  d["targetCurrency"] = targetCurrency
  d["sourcePositionAccountId"] = sourcePosition~accountId
  d["targetPositionAccountId"] = targetPosition~accountId
  if databaseCommit <> .nil then do
    d["databaseTransactionId"] = databaseCommit~value["databaseTransactionId"]
    d["databaseOutcome"] = databaseCommit~value["databaseOutcome"]
    d["databaseAttempts"] = databaseCommit~value["databaseAttempts"]
    d["databaseOperationCount"] = databaseCommit~value["databaseOperationCount"]
  end
  return .FederationBankResult~success(d)

::method postMandatoryCashSettlement
  expose accounts postings transactions sequence store
  use arg transactionId, customerAccountId, cashAccountId, amountMinor, currencyArg, postedAt = .nil, evidence = .nil, receipt = .nil
  tx = transactionId~string
  currency = currencyArg~string~upper
  amount = amountMinor + 0
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  if transactions~hasIndex(tx) then return .FederationBankResult~failure("TRANSACTION_DUPLICATE", tx)
  if amount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", amount)
  if evidence == .nil | \evidence~isA(.Directory) then return .FederationBankResult~failure("ATM_SETTLEMENT_EVIDENCE_REQUIRED")
  if \evidence~hasIndex("debitAuthority") then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_REQUIRED")
  if evidence["debitAuthority"] <> .FederationBankDebitAuthority~SETTLEMENT_MUST_POST then return .FederationBankResult~failure("ATM_DEBIT_AUTHORITY_INVALID")
  customerAccount = self~account(customerAccountId)
  cashAccount = self~account(cashAccountId)
  if customerAccount == .nil then return .FederationBankResult~failure("DEBIT_ACCOUNT_NOT_FOUND", customerAccountId)
  if cashAccount == .nil then return .FederationBankResult~failure("ATM_CASH_ACCOUNT_NOT_FOUND", cashAccountId)
  if customerAccount~status <> "OPEN" | cashAccount~status <> "OPEN" then return .FederationBankResult~failure("ACCOUNT_NOT_OPEN")
  if customerAccount~currency <> currency | cashAccount~currency <> currency then return .FederationBankResult~failure("CURRENCY_MISMATCH", currency)
  if cashAccount~internalAccount = .false then return .FederationBankResult~failure("ATM_CASH_ACCOUNT_NOT_INTERNAL", cashAccountId)
  if postedAt == .nil then postedAt = .DateTime~new
  sequenceBefore = sequence
  postingSet = .array~new
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "ATMD", tx, customerAccount~accountId, currency, 0 - amount, postedAt, "DEBIT", "ATM_OFFLINE_WITHDRAWAL_DEBIT"))
  sequence += 1
  postingSet~append(.FederationBankPosting~new("P" || sequence || "ATMC", tx, cashAccount~accountId, currency, amount, postedAt, "CREDIT", "ATM_CASH_SETTLEMENT_CREDIT"))
  databaseCommit = .nil
  if store <> .nil then do
    databaseCommit = store~commitOfflineCashPostings(postingSet, customerAccount~accountId, cashAccount~accountId, amount, evidence, receipt)
    if databaseCommit~ok = .false then do
      sequence = sequenceBefore
      return databaseCommit
    end
  end
  do posting over postingSet
    postings~append(posting)
  end
  transactions[tx] = postingSet
  d = self~fundsState(customerAccount~accountId)
  d["postings"] = postingSet
  d["transactionId"] = tx
  d["debitAuthority"] = .FederationBankDebitAuthority~SETTLEMENT_MUST_POST
  d["cashSettlementAccountId"] = cashAccount~accountId
  if databaseCommit <> .nil then do
    d["databaseTransactionId"] = databaseCommit~value["databaseTransactionId"]
    d["databaseOutcome"] = databaseCommit~value["databaseOutcome"]
    d["databaseAttempts"] = databaseCommit~value["databaseAttempts"]
    d["databaseOperationCount"] = databaseCommit~value["databaseOperationCount"]
  end
  return .FederationBankResult~success(d)

::method consumeAtmWithdrawalHold
  expose accounts postings transactions sequence store holds
  use arg transactionId, customerAccountId, cashAccountId, holdIdArg, amountMinorArg, currencyArg, postedAt = .nil, evidence = .nil, receipt = .nil
  tx = transactionId~string; holdId = holdIdArg~string; currency = currencyArg~string~upper; amount = amountMinorArg + 0
  if tx = "" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  if transactions~hasIndex(tx) then return .FederationBankResult~failure("TRANSACTION_DUPLICATE", tx)
  if amount <= 0 then return .FederationBankResult~failure("AMOUNT_INVALID", amount)
  hold = self~hold(holdId)
  if hold == .nil then return .FederationBankResult~failure("HOLD_NOT_FOUND", holdId)
  if hold~status <> "ACTIVE" then return .FederationBankResult~failure("HOLD_NOT_ACTIVE", holdId)
  if hold~accountId <> customerAccountId | hold~currency <> currency | hold~amountMinor <> amount then return .FederationBankResult~failure("ATM_HOLD_MISMATCH", holdId)
  customerAccount = self~account(customerAccountId); cashAccount = self~account(cashAccountId)
  if customerAccount == .nil then return .FederationBankResult~failure("DEBIT_ACCOUNT_NOT_FOUND", customerAccountId)
  if cashAccount == .nil | cashAccount~internalAccount = .false then return .FederationBankResult~failure("ATM_CASH_ACCOUNT_NOT_FOUND", cashAccountId)
  if customerAccount~currency <> currency | cashAccount~currency <> currency then return .FederationBankResult~failure("CURRENCY_MISMATCH", currency)
  if postedAt == .nil then postedAt = .DateTime~new
  sequenceBefore = sequence; postingSet = .array~new
  sequence += 1; postingSet~append(.FederationBankPosting~new("P" || sequence || "ATMWD", tx, customerAccountId, currency, 0 - amount, postedAt, "DEBIT", "ATM_WITHDRAWAL_DEBIT"))
  sequence += 1; postingSet~append(.FederationBankPosting~new("P" || sequence || "ATMWC", tx, cashAccountId, currency, amount, postedAt, "CREDIT", "ATM_CASH_SETTLEMENT_CREDIT"))
  releasedHold = hold~released(postedAt)
  databaseCommit = .nil
  if store <> .nil then do
    databaseCommit = store~commitAtmWithdrawalPostings(postingSet, customerAccountId, cashAccountId, releasedHold, evidence, receipt)
    if databaseCommit~ok = .false then do; sequence = sequenceBefore; return databaseCommit; end
  end
  do posting over postingSet; postings~append(posting); end
  transactions[tx] = postingSet; holds[holdId] = releasedHold
  d = self~fundsState(customerAccountId); d["postings"] = postingSet; d["transactionId"] = tx; d["holdId"] = holdId; d["cashSettlementAccountId"] = cashAccountId
  if databaseCommit <> .nil then do key over .array~of("databaseTransactionId","databaseOutcome","databaseAttempts","databaseOperationCount"); d[key]=databaseCommit~value[key]; end
  return .FederationBankResult~success(d)

::method postAtmDeposit
  expose accounts postings transactions sequence store
  use arg transactionId, cashAccountId, customerAccountId, amountMinorArg, currencyArg, postedAt = .nil, evidence = .nil, receipt = .nil
  tx=transactionId~string; currency=currencyArg~string~upper; amount=amountMinorArg+0
  if tx="" then return .FederationBankResult~failure("TRANSACTION_ID_REQUIRED")
  if transactions~hasIndex(tx) then return .FederationBankResult~failure("TRANSACTION_DUPLICATE",tx)
  if amount<=0 then return .FederationBankResult~failure("AMOUNT_INVALID",amount)
  cash=self~account(cashAccountId); customer=self~account(customerAccountId)
  if cash==.nil | cash~internalAccount=.false then return .FederationBankResult~failure("ATM_CASH_ACCOUNT_NOT_FOUND",cashAccountId)
  if customer==.nil then return .FederationBankResult~failure("CREDIT_ACCOUNT_NOT_FOUND",customerAccountId)
  if cash~currency<>currency | customer~currency<>currency then return .FederationBankResult~failure("CURRENCY_MISMATCH",currency)
  if postedAt==.nil then postedAt=.DateTime~new
  sequenceBefore=sequence; postingSet=.array~new
  sequence+=1; postingSet~append(.FederationBankPosting~new("P"||sequence||"ATMDPD",tx,cashAccountId,currency,0-amount,postedAt,"DEBIT","ATM_CASH_SETTLEMENT_DEBIT"))
  sequence+=1; postingSet~append(.FederationBankPosting~new("P"||sequence||"ATMDPC",tx,customerAccountId,currency,amount,postedAt,"CREDIT","ATM_DEPOSIT_CREDIT"))
  databaseCommit=.nil
  if store<>.nil then do
    databaseCommit=store~commitAtmDepositPostings(postingSet,customerAccountId,cashAccountId,amount,evidence,receipt)
    if databaseCommit~ok=.false then do; sequence=sequenceBefore; return databaseCommit; end
  end
  do posting over postingSet; postings~append(posting); end
  transactions[tx]=postingSet
  d=self~fundsState(customerAccountId); d["postings"]=postingSet; d["transactionId"]=tx; d["cashSettlementAccountId"]=cashAccountId
  if databaseCommit<>.nil then do key over .array~of("databaseTransactionId","databaseOutcome","databaseAttempts","databaseOperationCount"); d[key]=databaseCommit~value[key]; end
  return .FederationBankResult~success(d)

::method hydratePostingsFromStore
  expose postings transactions sequence store
  if store == .nil then return .FederationBankResult~success(0, "no durable store")
  recovered = store~recoverPostings
  if recovered~ok = .false then return recovered
  postings = .array~new
  transactions = .directory~new
  sequence = 0
  do posting over recovered~value
    postings~append(posting)
    sequence += 1
    tx = posting~transactionId
    pair = transactions[tx]
    if pair == .nil then do
      pair = .array~new
      transactions[tx] = pair
    end
    pair~append(posting)
  end
  return .FederationBankResult~success(postings~items)

::method hydrateHoldsFromStore
  expose holds store
  if store == .nil then return .FederationBankResult~success(0, "no durable store")
  recovered = store~recoverHolds
  if recovered~ok = .false then return recovered
  holds = .directory~new
  do h over recovered~value
    holds[h~holdId] = h
  end
  return .FederationBankResult~success(holds~items)

::class FederationBankCommand public
::attribute commandId get
::attribute operation get
::attribute idempotencyKey get
::attribute customerId get
::attribute sourceAccountId get
::attribute targetAccountId get
::attribute currency get
::attribute amountMinor get
::attribute channel get
::attribute actorId get
::attribute requestedAt get
::attribute productCode get
::attribute accountId get
::attribute legalName get
::attribute dateOfBirth get
::attribute postcode get
::attribute addressCountry get
::attribute applicantResidence get
::attribute applicantDomicile get
::attribute applicantSegment get
::attribute applicantRiskTier get
::attribute details get
::method detail
  expose details
  use arg key, defaultValue = ""
  if details == .nil then return defaultValue
  if details~hasIndex(key) then return details[key]
  return defaultValue
::method init
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details
  use arg commandIdArg, operationArg, idempotencyKeyArg, customerIdArg, sourceAccountIdArg = "", targetAccountIdArg = "", currencyArg = "", amountMinorArg = 0, channelArg = "WEB", actorIdArg = "", requestedAtArg = .nil, productCodeArg = "", accountIdArg = "", legalNameArg = "", dateOfBirthArg = "", postcodeArg = "", addressCountryArg = "", applicantResidenceArg = "", applicantDomicileArg = "", applicantSegmentArg = "RETAIL", applicantRiskTierArg = "STANDARD", detailsArg = .nil
  commandId = commandIdArg~string
  operation = operationArg~string~upper
  idempotencyKey = idempotencyKeyArg~string
  customerId = customerIdArg~string
  sourceAccountId = sourceAccountIdArg~string
  targetAccountId = targetAccountIdArg~string
  currency = currencyArg~string~upper
  amountMinor = amountMinorArg + 0
  channel = channelArg~string~upper
  actorId = actorIdArg~string
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else if requestedAtArg~string = "" then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
  productCode = productCodeArg~string~upper
  accountId = accountIdArg~string
  legalName = legalNameArg~string
  dateOfBirth = dateOfBirthArg~string
  postcode = postcodeArg~string~upper
  addressCountry = addressCountryArg~string~upper
  applicantResidence = applicantResidenceArg~string~upper
  applicantDomicile = applicantDomicileArg~string~upper
  applicantSegment = applicantSegmentArg~string~upper
  applicantRiskTier = applicantRiskTierArg~string~upper
  if detailsArg == .nil then details = .directory~new
  else details = detailsArg
::method asPayload
  expose commandId operation idempotencyKey customerId sourceAccountId targetAccountId currency amountMinor channel actorId requestedAt productCode accountId legalName dateOfBirth postcode addressCountry applicantResidence applicantDomicile applicantSegment applicantRiskTier details
  d = .directory~new
  d["schema"] = .FederationBankBuild~API_VERSION || "/command"
  d["commandId"] = commandId
  d["operation"] = operation
  d["idempotencyKey"] = idempotencyKey
  d["customerId"] = customerId
  d["sourceAccountId"] = sourceAccountId
  d["targetAccountId"] = targetAccountId
  d["currency"] = currency
  d["amountMinor"] = amountMinor
  d["channel"] = channel
  d["actorId"] = actorId
  d["requestedAt"] = requestedAt~utcIsoDate
  d["productCode"] = productCode
  d["accountId"] = accountId
  d["legalName"] = legalName
  d["dateOfBirth"] = dateOfBirth
  d["postcode"] = postcode
  d["addressCountry"] = addressCountry
  d["applicantResidence"] = applicantResidence
  d["applicantDomicile"] = applicantDomicile
  d["applicantSegment"] = applicantSegment
  d["applicantRiskTier"] = applicantRiskTier
  d["details"] = details
  d["bookingEntity"] = .FederationBankBuild~BOOKING_ENTITY
  d["bookingJurisdiction"] = .FederationBankBuild~BOOKING_JURISDICTION
  return d
::method fromPayload class
  use arg p
  iso = p["requestedAt"]~string
  /* utcIsoDate emits a trailing Z; ooRexx fromIsoDate expects the ISO body. */
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  details = .directory~new
  if p~hasIndex("details") then if p["details"] <> .nil then details = p["details"]
  return self~new(p["commandId"], p["operation"], p["idempotencyKey"], p["customerId"], p["sourceAccountId"], p["targetAccountId"], p["currency"], p["amountMinor"], p["channel"], p["actorId"], .DateTime~fromIsoDate(iso), p["productCode"], p["accountId"], p["legalName"], p["dateOfBirth"], p["postcode"], p["addressCountry"], p["applicantResidence"], p["applicantDomicile"], p["applicantSegment"], p["applicantRiskTier"], details)

::class FederationBankLimitRule public
::attribute ruleId get
::attribute segment get
::attribute currency get
::attribute operation get
::attribute channel get
::attribute perTransactionMinor get
::attribute dailyMinor get
::attribute rationale get
::method init
  expose ruleId segment currency operation channel perTransactionMinor dailyMinor rationale
  use arg ruleIdArg, segmentArg = "*", currencyArg = "*", operationArg = "TRANSFER", channelArg = "*", perTransactionMinorArg = 0, dailyMinorArg = 0, rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  segment = segmentArg~string~upper
  currency = currencyArg~string~upper
  operation = operationArg~string~upper
  channel = channelArg~string~upper
  perTransactionMinor = perTransactionMinorArg + 0
  dailyMinor = dailyMinorArg + 0
  rationale = rationaleArg~string
::method matches
  use arg command, customer
  if self~segment <> "*" & self~segment <> customer~segment then return .false
  if self~currency <> "*" & self~currency <> command~currency then return .false
  if self~operation <> "*" & self~operation <> command~operation then return .false
  if self~channel <> "*" & self~channel <> command~channel then return .false
  return .true
::method specificity
  score = 0
  if self~segment <> "*" then score += 1
  if self~currency <> "*" then score += 1
  if self~operation <> "*" then score += 1
  if self~channel <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~segment || "|" || self~currency || "|" || self~operation || "|" || self~channel || "|" || self~perTransactionMinor || "|" || self~dailyMinor || "|" || self~rationale

::class FederationBankLimitPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  do existing over rules
    if existing~ruleId = rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method rules
  expose rules
  out = .array~new
  do r over rules
    out~append(r)
  end
  return out
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed
  return sealed
::method evaluate
  expose rules sealed
  use arg command, customer, dailyUsageMinor = 0
  if sealed = .false then return .FederationBankResult~failure("LIMIT_POLICY_NOT_SEALED")
  best = .nil
  bestScore = -1
  do rule over rules
    if rule~matches(command, customer) then do
      score = rule~specificity
      if score > bestScore then do
        best = rule
        bestScore = score
      end
      else if score = bestScore then if best <> .nil then if rule~ruleId < best~ruleId then best = rule
    end
  end
  if best == .nil then return .FederationBankResult~failure("LIMIT_POLICY_NO_RULE", customer~segment || "/" || command~currency || "/" || command~operation || "/" || command~channel)
  d = .directory~new
  d["ruleId"] = best~ruleId
  d["perTransactionMinor"] = best~perTransactionMinor
  d["dailyMinor"] = best~dailyMinor
  d["usageBeforeMinor"] = dailyUsageMinor
  d["rationale"] = best~rationale
  allowed = .true
  reason = "ALLOW"
  if best~perTransactionMinor > 0 then if command~amountMinor > best~perTransactionMinor then do
    allowed = .false
    reason = "PER_TRANSACTION_LIMIT"
  end
  if allowed & best~dailyMinor > 0 then if dailyUsageMinor + command~amountMinor > best~dailyMinor then do
    allowed = .false
    reason = "DAILY_LIMIT"
  end
  d["allowed"] = allowed
  d["reason"] = reason
  return .FederationBankResult~success(d)
::method canonicalText
  expose rules sealed
  ids = .array~new
  byId = .directory~new
  do r over rules
    ids~append(r~ruleId)
    byId[r~ruleId] = r
  end
  ids~sort
  text = "FEDERATIONBANK-LIMIT-POLICY/1|SEALED=" || sealed
  do id over ids
    text ||= "|" || byId[id]~canonicalText
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankUsageTracker public
::method init
  expose usage
  usage = .directory~new
::method dayKey private
  use arg customerId, currency, atTime
  return customerId~string || "|" || currency~string~upper || "|" || atTime~utcIsoDate~left(10)
::method usedMinor
  expose usage
  use arg customerId, currency, atTime
  key = self~dayKey(customerId, currency, atTime)
  if usage~hasIndex(key) then return usage[key]
  return 0
::method record
  expose usage
  use arg customerId, currency, amountMinor, atTime
  key = self~dayKey(customerId, currency, atTime)
  current = 0
  if usage~hasIndex(key) then current = usage[key]
  usage[key] = current + amountMinor
  return usage[key]

::class FederationBankFeeRule public
::attribute ruleId get
::attribute segment get
::attribute currency get
::attribute operation get
::attribute channel get
::attribute fixedMinor get
::attribute basisPoints get
::attribute minimumMinor get
::attribute maximumMinor get
::attribute waiverThresholdMinor get
::attribute feeClass get
::attribute rationale get
::method init
  expose ruleId segment currency operation channel fixedMinor basisPoints minimumMinor maximumMinor waiverThresholdMinor feeClass rationale
  use arg ruleIdArg, segmentArg = "*", currencyArg = "*", operationArg = "TRANSFER", channelArg = "*", fixedMinorArg = 0, basisPointsArg = 0, minimumMinorArg = 0, maximumMinorArg = 0, waiverThresholdMinorArg = 0, feeClassArg = "STANDARD_TRANSFER", rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  segment = segmentArg~string~upper
  currency = currencyArg~string~upper
  operation = operationArg~string~upper
  channel = channelArg~string~upper
  fixedMinor = fixedMinorArg + 0
  basisPoints = basisPointsArg + 0
  minimumMinor = minimumMinorArg + 0
  maximumMinor = maximumMinorArg + 0
  waiverThresholdMinor = waiverThresholdMinorArg + 0
  feeClass = feeClassArg~string~upper
  rationale = rationaleArg~string
::method matches
  use arg command, customer
  if self~segment <> "*" & self~segment <> customer~segment then return .false
  if self~currency <> "*" & self~currency <> command~currency then return .false
  if self~operation <> "*" & self~operation <> command~operation then return .false
  if self~channel <> "*" & self~channel <> command~channel then return .false
  return .true
::method specificity
  score = 0
  if self~segment <> "*" then score += 1
  if self~currency <> "*" then score += 1
  if self~operation <> "*" then score += 1
  if self~channel <> "*" then score += 1
  return score
::method calculate
  use arg command
  amount = command~amountMinor + 0
  if self~waiverThresholdMinor > 0 then if amount <= self~waiverThresholdMinor then return 0
  fee = self~fixedMinor
  if self~basisPoints > 0 then fee += (amount * self~basisPoints) % 10000
  if self~minimumMinor > 0 & fee < self~minimumMinor then fee = self~minimumMinor
  if self~maximumMinor > 0 & fee > self~maximumMinor then fee = self~maximumMinor
  return fee
::method canonicalText
  return self~ruleId || "|" || self~segment || "|" || self~currency || "|" || self~operation || "|" || self~channel || "|" || self~fixedMinor || "|" || self~basisPoints || "|" || self~minimumMinor || "|" || self~maximumMinor || "|" || self~waiverThresholdMinor || "|" || self~feeClass || "|" || self~rationale

::class FederationBankFeePolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  rules~append(rule)
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed
  return sealed
::method evaluate
  expose rules sealed
  use arg command, customer
  if sealed = .false then return .FederationBankResult~failure("FEE_POLICY_NOT_SEALED")
  best = .nil
  bestScore = -1
  do rule over rules
    if rule~matches(command, customer) then do
      score = rule~specificity
      if score > bestScore then do
        best = rule
        bestScore = score
      end
      else if score = bestScore then if best <> .nil then if rule~ruleId < best~ruleId then best = rule
    end
  end
  if best == .nil then return .FederationBankResult~failure("FEE_POLICY_NO_RULE", customer~segment || "/" || command~currency || "/" || command~operation || "/" || command~channel)
  d = .directory~new
  d["ruleId"] = best~ruleId
  d["feeAmountMinor"] = best~calculate(command)
  d["feeClass"] = best~feeClass
  d["rationale"] = best~rationale
  return .FederationBankResult~success(d)
::method canonicalText
  expose rules sealed
  text = "sealed=" || sealed
  do r over rules
    text ||= .endOfLine || r~canonicalText
  end
  return text

::class FederationBankFeePolicyGate public
::method init
  expose catalog
  use arg catalogArg
  if catalogArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_FEE_POLICY_CATALOG_REQUIRED")
  catalog = catalogArg
::method evaluate
  expose catalog
  use arg command, customer
  resolved = catalog~resolve(.FederationBankBuild~FEE_POLICY_DEFAULT, command~requestedAt)
  if resolved~ok = .false then return .FederationBankResult~failure("FEE_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  payload = release~payload
  if payload == .nil then return .FederationBankResult~failure("FEE_POLICY_PAYLOAD_REQUIRED", release~policyId || "@" || release~version)
  decision = payload~evaluate(command, customer)
  if decision~ok = .false then return decision
  d = decision~value
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  return .FederationBankResult~success(d)


::class FederationBankFxRule public
::attribute ruleId get
::attribute segment get
::attribute sourceCurrency get
::attribute targetCurrency get
::attribute operation get
::attribute channel get
::attribute maximumSourceMinor get
::attribute markupBasisPoints get
::attribute rationale get
::method init
  expose ruleId segment sourceCurrency targetCurrency operation channel maximumSourceMinor markupBasisPoints rationale
  use arg ruleIdArg, segmentArg = "*", sourceCurrencyArg = "*", targetCurrencyArg = "*", operationArg = "FX_CONVERT", channelArg = "*", maximumSourceMinorArg = 0, markupBasisPointsArg = 0, rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  segment = segmentArg~string~upper
  sourceCurrency = sourceCurrencyArg~string~upper
  targetCurrency = targetCurrencyArg~string~upper
  operation = operationArg~string~upper
  channel = channelArg~string~upper
  maximumSourceMinor = maximumSourceMinorArg + 0
  markupBasisPoints = markupBasisPointsArg + 0
  rationale = rationaleArg~string
::method matches
  use arg command, customer, targetCurrencyArg
  targetCur = targetCurrencyArg~string~upper
  if self~segment <> "*" & self~segment <> customer~segment then return .false
  if self~sourceCurrency <> "*" & self~sourceCurrency <> command~currency then return .false
  if self~targetCurrency <> "*" & self~targetCurrency <> targetCur then return .false
  if self~operation <> "*" & self~operation <> command~operation then return .false
  if self~channel <> "*" & self~channel <> command~channel then return .false
  return .true
::method specificity
  score = 0
  if self~segment <> "*" then score += 1
  if self~sourceCurrency <> "*" then score += 1
  if self~targetCurrency <> "*" then score += 1
  if self~operation <> "*" then score += 1
  if self~channel <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~segment || "|" || self~sourceCurrency || "|" || self~targetCurrency || "|" || self~operation || "|" || self~channel || "|" || self~maximumSourceMinor || "|" || self~markupBasisPoints || "|" || self~rationale

::class FederationBankFxPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  rules~append(rule)
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed
  return sealed
::method evaluate
  expose rules sealed
  use arg command, customer, targetCurrency
  if sealed = .false then return .FederationBankResult~failure("FX_POLICY_NOT_SEALED")
  best = .nil
  bestScore = -1
  do rule over rules
    if rule~matches(command, customer, targetCurrency) then do
      score = rule~specificity
      if score > bestScore then do
        best = rule
        bestScore = score
      end
      else if score = bestScore then if best <> .nil then if rule~ruleId < best~ruleId then best = rule
    end
  end
  if best == .nil then return .FederationBankResult~failure("FX_POLICY_NO_RULE", customer~segment || "/" || command~currency || "/" || targetCurrency || "/" || command~channel)
  allowed = .true
  reason = "ALLOWED"
  if best~maximumSourceMinor > 0 then if command~amountMinor > best~maximumSourceMinor then do
    allowed = .false
    reason = "FX_PAIR_LIMIT"
  end
  d = .directory~new
  d["allowed"] = allowed
  d["reason"] = reason
  d["ruleId"] = best~ruleId
  d["markupBasisPoints"] = best~markupBasisPoints
  d["maximumSourceMinor"] = best~maximumSourceMinor
  d["rationale"] = best~rationale
  return .FederationBankResult~success(d)
::method canonicalText
  expose rules sealed
  text = "sealed=" || sealed
  do r over rules
    text ||= .endOfLine || r~canonicalText
  end
  return text

::class FederationBankFxPolicyGate public
::method init
  expose catalog
  use arg catalogArg
  if catalogArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_FX_POLICY_CATALOG_REQUIRED")
  catalog = catalogArg
::method evaluate
  expose catalog
  use arg command, customer, targetCurrency
  resolved = catalog~resolve(.FederationBankBuild~FX_POLICY_DEFAULT, command~requestedAt)
  if resolved~ok = .false then return .FederationBankResult~failure("FX_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  payload = release~payload
  if payload == .nil then return .FederationBankResult~failure("FX_POLICY_PAYLOAD_REQUIRED", release~policyId || "@" || release~version)
  decision = payload~evaluate(command, customer, targetCurrency)
  if decision~ok = .false then return decision
  d = decision~value
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  return .FederationBankResult~success(d)

::class FederationBankFxQuote public
::attribute quoteId get
::attribute providerId get
::attribute sourceCurrency get
::attribute targetCurrency get
::attribute rateNumerator get
::attribute rateDenominator get
::attribute quotedAt get
::attribute validUntil get
::attribute methodology get
::method init
  expose quoteId providerId sourceCurrency targetCurrency rateNumerator rateDenominator quotedAt validUntil methodology
  use arg quoteIdArg, providerIdArg, sourceCurrencyArg, targetCurrencyArg, rateNumeratorArg, rateDenominatorArg, quotedAtArg = .nil, validUntilArg = .nil, methodologyArg = ""
  quoteId = quoteIdArg~string
  providerId = providerIdArg~string~upper
  sourceCurrency = sourceCurrencyArg~string~upper
  targetCurrency = targetCurrencyArg~string~upper
  rateNumerator = rateNumeratorArg + 0
  rateDenominator = rateDenominatorArg + 0
  if rateNumerator <= 0 | rateDenominator <= 0 then raise syntax 88.900 array("FEDERATIONBANK_FX_RATE_INVALID")
  if quotedAtArg == .nil then quotedAt = .DateTime~new
  else quotedAt = quotedAtArg
  if validUntilArg == .nil then validUntil = quotedAt + .TimeSpan~new(0,0,0,5)
  else validUntil = validUntilArg
  methodology = methodologyArg~string
::method targetAmountMinor
  use arg sourceAmountMinor, markupBasisPointsArg = 0
  sourceAmount = sourceAmountMinor + 0
  markup = markupBasisPointsArg + 0
  if sourceAmount <= 0 then return 0
  if markup < 0 | markup >= 10000 then return 0
  effectiveNumerator = self~rateNumerator * (10000 - markup)
  effectiveDenominator = self~rateDenominator * 10000
  return (sourceAmount * effectiveNumerator) % effectiveDenominator
::method asDirectory
  d = .directory~new
  d["quoteId"] = self~quoteId
  d["providerId"] = self~providerId
  d["sourceCurrency"] = self~sourceCurrency
  d["targetCurrency"] = self~targetCurrency
  d["rateNumerator"] = self~rateNumerator
  d["rateDenominator"] = self~rateDenominator
  d["quotedAt"] = self~quotedAt~utcIsoDate
  d["validUntil"] = self~validUntil~utcIsoDate
  d["methodology"] = self~methodology
  return d

::class FederationBankFxQuotePort public
::method quote abstract

::class FederationBankPolicyGate public
::method init
  expose catalog
  use arg catalogArg
  if catalogArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_POLICY_CATALOG_REQUIRED")
  catalog = catalogArg
::method evaluate
  expose catalog
  use arg command, customer, dailyUsageMinor
  resolved = catalog~resolve(customer~limitPolicyId, command~requestedAt)
  if resolved~ok = .false then return .FederationBankResult~failure("POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  payload = release~payload
  if payload == .nil then return .FederationBankResult~failure("POLICY_PAYLOAD_REQUIRED", release~policyId || "@" || release~version)
  decision = payload~evaluate(command, customer, dailyUsageMinor)
  if decision~ok = .false then return decision
  d = decision~value
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  return .FederationBankResult~success(d)


::class FederationBankBeneficiaryRule public
::attribute ruleId get
::attribute segment get
::attribute operation get
::attribute channel get
::attribute maxActiveBeneficiaries get
::attribute rationale get
::method init
  expose ruleId segment operation channel maxActiveBeneficiaries rationale
  use arg ruleIdArg, segmentArg = "*", operationArg = "*", channelArg = "*", maxActiveArg = 0, rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  segment = segmentArg~string~upper
  operation = operationArg~string~upper
  channel = channelArg~string~upper
  maxActiveBeneficiaries = maxActiveArg + 0
  rationale = rationaleArg~string
::method matches
  use arg command, customer
  if self~segment <> "*" & self~segment <> customer~segment then return .false
  if self~operation <> "*" & self~operation <> command~operation then return .false
  if self~channel <> "*" & self~channel <> command~channel then return .false
  return .true
::method specificity
  score = 0
  if self~segment <> "*" then score += 1
  if self~operation <> "*" then score += 1
  if self~channel <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~segment || "|" || self~operation || "|" || self~channel || "|" || self~maxActiveBeneficiaries || "|" || self~rationale

::class FederationBankBeneficiaryPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .false
  if rule == .nil then return .false
  do existing over rules
    if existing~ruleId = rule~ruleId then return .false
  end
  rules~append(rule)
  return .true
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed
  return sealed
::method evaluate
  expose rules sealed
  use arg command, customer, activeCount = 0
  if sealed = .false then return .FederationBankResult~failure("BENEFICIARY_POLICY_NOT_SEALED")
  best = .nil
  bestScore = -1
  do rule over rules
    if rule~matches(command, customer) then do
      score = rule~specificity
      if score > bestScore then do
        best = rule
        bestScore = score
      end
      else if score = bestScore then if best <> .nil then if rule~ruleId < best~ruleId then best = rule
    end
  end
  if best == .nil then return .FederationBankResult~failure("BENEFICIARY_POLICY_NO_RULE", customer~segment || "/" || command~operation || "/" || command~channel)
  d = .directory~new
  d["ruleId"] = best~ruleId
  d["activeCountBefore"] = activeCount
  d["maxActiveBeneficiaries"] = best~maxActiveBeneficiaries
  d["rationale"] = best~rationale
  allowed = .true
  reason = "ALLOW"
  if command~operation = "ADD_BENEFICIARY" & best~maxActiveBeneficiaries > 0 then do
    if activeCount >= best~maxActiveBeneficiaries then do
      allowed = .false
      reason = "ACTIVE_BENEFICIARY_LIMIT"
    end
  end
  d["allowed"] = allowed
  d["reason"] = reason
  return .FederationBankResult~success(d)
::method canonicalText
  expose rules sealed
  text = "FEDERATIONBANK-BENEFICIARY-POLICY/1|SEALED=" || sealed
  do r over rules
    text ||= "|" || r~canonicalText
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankBeneficiaryPolicyGate public
::method init
  expose catalog
  use arg catalogArg
  if catalogArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_BENEFICIARY_POLICY_CATALOG_REQUIRED")
  catalog = catalogArg
::method evaluate
  expose catalog
  use arg command, customer, activeCount
  resolved = catalog~resolve(.FederationBankBuild~BENEFICIARY_POLICY_DEFAULT, command~requestedAt)
  if resolved~ok = .false then return .FederationBankResult~failure("BENEFICIARY_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  decision = release~payload~evaluate(command, customer, activeCount)
  if decision~ok = .false then return decision
  d = decision~value
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  return .FederationBankResult~success(d)

::class FederationBankOpeningRule public
::attribute ruleId get
::attribute productCode get
::attribute currency get
::attribute channel get
::attribute addressVerificationRequired get
::attribute creditScoreRequired get
::attribute acceptScore get
::attribute referScore get
::attribute existingCustomerChecksRequired get
::attribute rationale get
::attribute creditProductCode get
::method init
  expose ruleId productCode currency channel addressVerificationRequired creditScoreRequired acceptScore referScore existingCustomerChecksRequired rationale creditProductCode
  use arg ruleIdArg, productCodeArg = "*", currencyArg = "*", channelArg = "*", addressRequiredArg = .true, creditRequiredArg = .true, acceptScoreArg = 600, referScoreArg = 500, existingChecksArg = .false, rationaleArg = "", creditProductCodeArg = ""
  ruleId = ruleIdArg~string~upper
  productCode = productCodeArg~string~upper
  currency = currencyArg~string~upper
  channel = channelArg~string~upper
  addressVerificationRequired = addressRequiredArg
  creditScoreRequired = creditRequiredArg
  acceptScore = acceptScoreArg + 0
  referScore = referScoreArg + 0
  existingCustomerChecksRequired = existingChecksArg
  rationale = rationaleArg~string
  creditProductCode = creditProductCodeArg~string
::method matches
  use arg command
  if self~productCode <> "*" & self~productCode <> command~productCode then return .false
  if self~currency <> "*" & self~currency <> command~currency then return .false
  if self~channel <> "*" & self~channel <> command~channel then return .false
  return .true
::method specificity
  score = 0
  if self~productCode <> "*" then score += 1
  if self~currency <> "*" then score += 1
  if self~channel <> "*" then score += 1
  return score
::method canonicalText
  return self~ruleId || "|" || self~productCode || "|" || self~currency || "|" || self~channel || "|" || self~addressVerificationRequired || "|" || self~creditScoreRequired || "|" || self~acceptScore || "|" || self~referScore || "|" || self~existingCustomerChecksRequired || "|" || self~rationale || "|" || self~creditProductCode

::class FederationBankAccountOpeningPolicy public
::attribute sealed get
::method init
  expose rules sealed
  rules = .array~new
  sealed = .false
::method addRule
  expose rules sealed
  use arg rule
  if sealed then return .FederationBankResult~failure("OPENING_POLICY_SEALED")
  if rule == .nil then return .FederationBankResult~failure("OPENING_RULE_REQUIRED")
  rules~append(rule)
  return .FederationBankResult~success(rule)
::method rules
  expose rules
  out = .array~new
  do r over rules
    out~append(r)
  end
  return out
::method seal
  expose sealed
  sealed = .true
  return self
::method publicationEligible
  expose sealed
  return sealed
::method selectRule
  expose rules
  use arg command
  selected = .nil
  score = -1
  do r over rules
    if r~matches(command) then do
      rs = r~specificity
      if rs > score then do
        selected = r
        score = rs
      end
    end
  end
  if selected == .nil then return .FederationBankResult~failure("OPENING_POLICY_NO_RULE", command~productCode || ":" || command~currency || ":" || command~channel)
  return .FederationBankResult~success(selected)
::method requirements
  use arg command, isNewCustomer = .true
  selected = self~selectRule(command)
  if selected~ok = .false then return selected
  rule = selected~value
  d = .directory~new
  d["rule"] = rule
  d["ruleId"] = rule~ruleId
  d["creditProductCode"] = rule~creditProductCode
  if isNewCustomer | rule~existingCustomerChecksRequired then do
    d["addressVerificationRequired"] = rule~addressVerificationRequired
    d["creditScoreRequired"] = rule~creditScoreRequired
  end
  else do
    d["addressVerificationRequired"] = .false
    d["creditScoreRequired"] = .false
  end
  return .FederationBankResult~success(d)
::method decide
  use arg rule, addressEvidence = .nil, creditReport = .nil, addressRequiredArg = .nil, creditRequiredArg = .nil
  if rule == .nil then return .FederationBankResult~failure("OPENING_RULE_REQUIRED")
  if addressRequiredArg == .nil then addressRequired = rule~addressVerificationRequired
  else addressRequired = addressRequiredArg
  if creditRequiredArg == .nil then creditRequired = rule~creditScoreRequired
  else creditRequired = creditRequiredArg
  d = .directory~new
  d["ruleId"] = rule~ruleId
  d["outcome"] = "ACCEPTED"
  d["reason"] = "POLICY_SATISFIED"
  if addressRequired then do
    if addressEvidence == .nil then do
      d["outcome"] = "REJECTED"
      d["reason"] = "ADDRESS_EVIDENCE_MISSING"
      return .FederationBankResult~success(d)
    end
    if addressEvidence["verified"] <> .true then do
      d["outcome"] = "REJECTED"
      d["reason"] = "ADDRESS_NOT_VERIFIED"
      return .FederationBankResult~success(d)
    end
  end
  if creditRequired then do
    if creditReport == .nil then do
      d["outcome"] = "REJECTED"
      d["reason"] = "CREDIT_REPORT_MISSING"
      return .FederationBankResult~success(d)
    end

    /* IJCIB is deliberately not a score API.  Preserve the whole product and
       act only on its published top-level semantics.  In particular, the bank
       never decodes the opaque reason-code tree. */
    if creditReport~hasMethod("OVERALLDISPOSITION") then do
      status = creditReport~overallDisposition
      d["creditStatus"] = status
      d["creditBureauReference"] = creditReport~bureauReference
      d["creditMethodologyVersion"] = creditReport~methodologyVersion
      d["creditNextPermittedRefreshNotBefore"] = creditReport~nextPermittedRefreshNotBefore
      if creditReport~hasScaledValue then d["creditScore"] = creditReport~scaledValue
      else d["creditScore"] = ""

      select
        when status = "INTELLIGENCE_PRODUCT_RELEASED_SUBJECT_TO_REFERRAL" then do
          d["outcome"] = "REFERRED"
          d["reason"] = "IJCIB_PRODUCT_REQUIRES_REFERRAL"
          return .FederationBankResult~success(d)
        end
        when status = "INTELLIGENCE_PRODUCT_WITHHELD_PENDING_FURTHER_ASSURANCE" then do
          d["outcome"] = "REFERRED"
          d["reason"] = "IJCIB_FURTHER_ASSURANCE_REQUIRED"
          return .FederationBankResult~success(d)
        end
        when status = "REQUEST_REFUSED_INSTITUTIONAL_MISMATCH" | status = "REQUEST_REFUSED_PROTOCOL_OR_DIGEST_FAILURE" | status = "REQUEST_REFUSED_TEMPORAL_OR_NONCE_ANOMALY" | status = "BUREAU_INTERNAL_EXCEPTION_NO_PRODUCT" then do
          d["outcome"] = "REJECTED"
          d["reason"] = "IJCIB_PRODUCT_UNAVAILABLE"
          return .FederationBankResult~success(d)
        end
        when status = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS" then nop
        otherwise do
          d["outcome"] = "REJECTED"
          d["reason"] = "IJCIB_DISPOSITION_UNKNOWN"
          return .FederationBankResult~success(d)
        end
      end

      /* A suppressed score is not silently converted to zero.  It becomes a
         bank referral.  Likewise a methodology with an unknown direction is
         not interpreted by application code. */
      if creditReport~suppressionFlags~items > 0 | \creditReport~hasScaledValue then do
        d["outcome"] = "REFERRED"
        d["reason"] = "IJCIB_EVIDENCE_SUPPRESSED"
        return .FederationBankResult~success(d)
      end
      if creditReport~scaleDirection <> "HIGHER_INDICATES_LOWER_OBSERVED_STRESS" then do
        d["outcome"] = "REFERRED"
        d["reason"] = "IJCIB_SCALE_SEMANTICS_UNRECOGNISED"
        return .FederationBankResult~success(d)
      end
      if creditReport~scaledValue < rule~referScore then do
        d["outcome"] = "REJECTED"
        d["reason"] = "CREDIT_POLICY_REJECT"
        return .FederationBankResult~success(d)
      end
      if creditReport~scaledValue < rule~acceptScore then do
        d["outcome"] = "REFERRED"
        d["reason"] = "CREDIT_POLICY_REFER"
        return .FederationBankResult~success(d)
      end
    end
    else do
      /* Legacy v0.2 fixture/port compatibility. */
      status = creditReport~status
      d["creditStatus"] = status
      d["creditScore"] = creditReport~score
      d["creditBureauReference"] = creditReport~bureauReference
      if status = "REFUSED" | status = "ERROR" | status = "TIMEOUT" then do
        d["outcome"] = "REJECTED"
        d["reason"] = "CREDIT_REPORT_UNAVAILABLE"
        return .FederationBankResult~success(d)
      end
      if status = "REFER" then do
        d["outcome"] = "REFERRED"
        d["reason"] = "CREDIT_AGENCY_REFER"
        return .FederationBankResult~success(d)
      end
      if status <> "OK" then do
        d["outcome"] = "REJECTED"
        d["reason"] = "CREDIT_STATUS_INVALID"
        return .FederationBankResult~success(d)
      end
      if creditReport~score < rule~referScore then do
        d["outcome"] = "REJECTED"
        d["reason"] = "CREDIT_POLICY_REJECT"
        return .FederationBankResult~success(d)
      end
      if creditReport~score < rule~acceptScore then do
        d["outcome"] = "REFERRED"
        d["reason"] = "CREDIT_POLICY_REFER"
        return .FederationBankResult~success(d)
      end
    end
  end
  return .FederationBankResult~success(d)
::method canonicalText
  expose rules sealed
  text = "FEDERATIONBANK_ACCOUNT_OPENING|" || sealed
  do r over rules
    text ||= "|" || r~canonicalText
  end
  return text
::method semanticIdentity
  return self~canonicalText

::class FederationBankOpeningPolicyGate public
::method init
  expose catalog policyId
  use arg catalogArg, policyIdArg = .nil
  if catalogArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_OPENING_POLICY_CATALOG_REQUIRED")
  catalog = catalogArg
  if policyIdArg == .nil then policyId = .FederationBankBuild~OPENING_POLICY_DEFAULT
  else policyId = policyIdArg~string~upper
::method resolveRequirements
  expose catalog policyId
  use arg command, isNewCustomer = .true
  resolved = catalog~resolve(policyId, command~requestedAt)
  if resolved~ok = .false then return .FederationBankResult~failure("OPENING_POLICY_RESOLUTION_FAILED", resolved~code || ":" || resolved~detail, resolved)
  release = resolved~value
  payload = release~payload
  if payload == .nil then return .FederationBankResult~failure("OPENING_POLICY_PAYLOAD_REQUIRED")
  requirements = payload~requirements(command, isNewCustomer)
  if requirements~ok = .false then return requirements
  d = requirements~value
  d["policyId"] = release~policyId
  d["policyVersion"] = release~version
  d["policyIdentity"] = release~semanticIdentity
  d["policyPayload"] = payload
  return .FederationBankResult~success(d)
::method decide
  use arg resolvedRequirements, addressEvidence = .nil, creditReport = .nil
  if resolvedRequirements == .nil then return .FederationBankResult~failure("OPENING_REQUIREMENTS_REQUIRED")
  payload = resolvedRequirements["policyPayload"]
  rule = resolvedRequirements["rule"]
  decision = payload~decide(rule, addressEvidence, creditReport, resolvedRequirements["addressVerificationRequired"], resolvedRequirements["creditScoreRequired"])
  if decision~ok = .false then return decision
  d = decision~value
  d["policyId"] = resolvedRequirements["policyId"]
  d["policyVersion"] = resolvedRequirements["policyVersion"]
  d["policyIdentity"] = resolvedRequirements["policyIdentity"]
  return .FederationBankResult~success(d)

::class FederationBankLegalGenerationRegistry public
::method init
  expose generations
  generations = .directory~new
::method register
  expose generations
  use arg legalProfileId, generation
  key = legalProfileId~string~upper
  if generation == .nil then return .FederationBankResult~failure("LEGAL_GENERATION_REQUIRED", key)
  if generation~sealed = .false then return .FederationBankResult~failure("LEGAL_GENERATION_NOT_SEALED", key)
  if generations~hasIndex(key) then return .FederationBankResult~failure("LEGAL_PROFILE_DUPLICATE", key)
  generations[key] = generation
  return .FederationBankResult~success(generation)
::method generation
  expose generations
  use arg legalProfileId
  key = legalProfileId~string~upper
  if generations~hasIndex(key) then return generations[key]
  return .nil

::class FederationBankLegalGate public
::method init
  expose registry engine
  use arg registryArg, engineArg = .nil
  if registryArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_LEGAL_REGISTRY_REQUIRED")
  registry = registryArg
  if engineArg == .nil then engine = .LegalEffectEngine~new
  else engine = engineArg

::method evaluateOpenAccount
  expose registry engine
  use arg command, customer, profile
  generation = registry~generation(profile~legalProfileId)
  if generation == .nil then return .FederationBankResult~failure("LEGAL_PROFILE_NOT_LOADED", profile~legalProfileId)
  facts = .LegalFactSet~new
  facts~putKnown("CURRENCY", command~currency, "FederationBank command", "RUNTIME")
  facts~putKnown("CUSTOMER_RESIDENCE", customer~residence, "FederationBank customer", "RUNTIME")
  facts~putKnown("CUSTOMER_DOMICILE", customer~domicile, "FederationBank customer", "RUNTIME")
  facts~putKnown("BOOKING_JURISDICTION", profile~bookingJurisdiction, "FederationBank regulatory profile", "RUNTIME")
  context = .LegalContext~new(command~commandId, command~requestedAt~utcIsoDate, "", facts)
  context~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", profile~bookingJurisdiction, "BANKING", "FederationBank IOM booking entity"))
  action = .LegalAction~new(command~operation, "FederationBank queued account-opening operation")
  outcome = engine~evaluate(action, generation, context)
  if outcome~ok = .false then return .FederationBankResult~failure("LEGAL_EVALUATION_FAILED", outcome~code || ":" || outcome~detail, outcome)
  assessment = outcome~value
  if assessment~status = "BLOCKED" then return .FederationBankResult~failure("LEGAL_BLOCKED", profile~legalProfileId, assessment)
  if assessment~status = "REVIEW_REQUIRED" then return .FederationBankResult~failure("LEGAL_REVIEW_REQUIRED", profile~legalProfileId, assessment)
  d = .directory~new
  d["legalProfileId"] = profile~legalProfileId
  d["generationId"] = generation~generationId
  d["generationVersion"] = generation~version
  d["status"] = assessment~status
  d["assessment"] = assessment
  return .FederationBankResult~success(d)
::method evaluateBeneficiary
  expose registry engine
  use arg command, customer, account, profile
  generation = registry~generation(profile~legalProfileId)
  if generation == .nil then return .FederationBankResult~failure("LEGAL_PROFILE_NOT_LOADED", profile~legalProfileId)
  facts = .LegalFactSet~new
  facts~putKnown("CURRENCY", account~currency, "FederationBank account", "RUNTIME")
  facts~putKnown("BENEFICIARY_CURRENCY", command~detail("currency")~string~upper, "FederationBank command", "RUNTIME")
  facts~putKnown("BENEFICIARY_COUNTRY", command~detail("country")~string~upper, "FederationBank command", "RUNTIME")
  facts~putKnown("CUSTOMER_RESIDENCE", customer~residence, "FederationBank customer", "RUNTIME")
  facts~putKnown("CUSTOMER_DOMICILE", customer~domicile, "FederationBank customer", "RUNTIME")
  facts~putKnown("BOOKING_JURISDICTION", account~bookingJurisdiction, "FederationBank account", "RUNTIME")
  context = .LegalContext~new(command~commandId, command~requestedAt~utcIsoDate, "", facts)
  context~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", account~bookingJurisdiction, "BANKING", "FederationBank IOM booking entity"))
  action = .LegalAction~new(command~operation, "FederationBank queued beneficiary lifecycle operation")
  outcome = engine~evaluate(action, generation, context)
  if outcome~ok = .false then return .FederationBankResult~failure("LEGAL_EVALUATION_FAILED", outcome~code || ":" || outcome~detail, outcome)
  assessment = outcome~value
  if assessment~status = "BLOCKED" then return .FederationBankResult~failure("LEGAL_BLOCKED", profile~legalProfileId, assessment)
  if assessment~status = "REVIEW_REQUIRED" then return .FederationBankResult~failure("LEGAL_REVIEW_REQUIRED", profile~legalProfileId, assessment)
  d = .directory~new
  d["legalProfileId"] = profile~legalProfileId
  d["generationId"] = generation~generationId
  d["generationVersion"] = generation~version
  d["status"] = assessment~status
  d["assessment"] = assessment
  return .FederationBankResult~success(d)
::method evaluate
  expose registry engine
  use arg command, customer, sourceAccount, profile, derivedFacts = .nil
  generation = registry~generation(profile~legalProfileId)
  if generation == .nil then return .FederationBankResult~failure("LEGAL_PROFILE_NOT_LOADED", profile~legalProfileId)
  facts = .LegalFactSet~new
  facts~putKnown("CURRENCY", command~currency, "FederationBank command", "RUNTIME")
  facts~putKnown("AMOUNT_MINOR", command~amountMinor, "FederationBank command", "RUNTIME")
  if derivedFacts <> .nil then if derivedFacts~isA(.Directory) then do
    if derivedFacts~hasIndex("feeAmountMinor") then facts~putKnown("FEE_AMOUNT_MINOR", derivedFacts["feeAmountMinor"], "FederationBank fee policy", "RUNTIME")
    if derivedFacts~hasIndex("feeClass") then facts~putKnown("FEE_CLASS", derivedFacts["feeClass"], "FederationBank fee policy", "RUNTIME")
  end
  facts~putKnown("CUSTOMER_RESIDENCE", customer~residence, "FederationBank customer", "RUNTIME")
  facts~putKnown("CUSTOMER_DOMICILE", customer~domicile, "FederationBank customer", "RUNTIME")
  facts~putKnown("BOOKING_JURISDICTION", sourceAccount~bookingJurisdiction, "FederationBank account", "RUNTIME")
  context = .LegalContext~new(command~commandId, command~requestedAt~utcIsoDate, "", facts)
  context~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", sourceAccount~bookingJurisdiction, "BANKING", "booking entity"))
  action = .LegalAction~new(command~operation, "FederationBank queued banking operation")
  outcome = engine~evaluate(action, generation, context)
  if outcome~ok = .false then return .FederationBankResult~failure("LEGAL_EVALUATION_FAILED", outcome~code || ":" || outcome~detail, outcome)
  assessment = outcome~value
  if assessment~status = "BLOCKED" then return .FederationBankResult~failure("LEGAL_BLOCKED", profile~legalProfileId, assessment)
  if assessment~status = "REVIEW_REQUIRED" then return .FederationBankResult~failure("LEGAL_REVIEW_REQUIRED", profile~legalProfileId, assessment)
  d = .directory~new
  d["legalProfileId"] = profile~legalProfileId
  d["generationId"] = generation~generationId
  d["generationVersion"] = generation~version
  d["status"] = assessment~status
  d["assessment"] = assessment
  return .FederationBankResult~success(d)


::class FederationBankCivicPortAddressVerifier public
::constant ABILITY_ID "civic.postcode.lookup"
::constant CONTRACT_GENERATION "civic.postcode.lookup/0.1"
::constant MAPPING_GENERATION "postcodes.io.postcode/0.2"
::method init
  expose client adapter
  use arg clientArg, adapterArg = .nil
  if clientArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_CIVICPORT_CLIENT_REQUIRED")
  client = clientArg
  if adapterArg == .nil then adapter = .CivicPostcodeAdapter~new
  else adapter = adapterArg
::method verify
  expose client adapter
  use arg command
  if command~postcode = "" then return .FederationBankResult~failure("ADDRESS_POSTCODE_REQUIRED")
  encoded = command~postcode~changestr(" ", "%20")
  url = "https://api.postcodes.io/postcodes/" || encoded
  fetched = client~get(url, .nil, 10, command~idempotencyKey, "")
  if fetched~ok = .false then return .FederationBankResult~failure("ADDRESS_CIVICPORT_FAILED", fetched~errorCode || ":" || fetched~message, fetched)
  mapped = adapter~map(fetched~document)
  if mapped~ok = .false then return .FederationBankResult~failure("ADDRESS_CIVICPORT_INVALID", mapped~errorCode || ":" || mapped~message, mapped)
  d = .directory~new
  d["verified"] = .true
  d["abilityId"] = self~ABILITY_ID
  d["contractGeneration"] = self~CONTRACT_GENERATION
  d["mappingGeneration"] = mapped~mappingId
  d["postcode"] = mapped~row["postcode"]
  d["country"] = mapped~row["country"]
  d["documentDigest"] = mapped~document~bodyDigest
  d["documentFetchedAt"] = mapped~document~fetchedAt
  d["transport"] = mapped~document~transportName
  d["reference"] = "sha512:" || mapped~document~bodyDigest
  return .FederationBankResult~success(d)

::class FederationBankCreditScoreRequest public
::attribute requestId get
::attribute correlationId get
::attribute customerReference get
::attribute legalName get
::attribute dateOfBirth get
::attribute postcode get
::attribute requestedProduct get
::attribute requestedCurrency get
::attribute requestedAt get
::method init
  expose requestId correlationId customerReference legalName dateOfBirth postcode requestedProduct requestedCurrency requestedAt
  use arg requestIdArg, correlationIdArg, customerReferenceArg, legalNameArg, dateOfBirthArg, postcodeArg, requestedProductArg, requestedCurrencyArg, requestedAtArg = .nil
  requestId = requestIdArg~string
  correlationId = correlationIdArg~string
  customerReference = customerReferenceArg~string
  legalName = legalNameArg~string
  dateOfBirth = dateOfBirthArg~string
  postcode = postcodeArg~string~upper
  requestedProduct = requestedProductArg~string~upper
  requestedCurrency = requestedCurrencyArg~string~upper
  if requestedAtArg == .nil then requestedAt = .DateTime~new
  else requestedAt = requestedAtArg
::method asDirectory
  expose requestId correlationId customerReference legalName dateOfBirth postcode requestedProduct requestedCurrency requestedAt
  d = .directory~new
  d["schema"] = "federationbank.credit-score.request/0.1"
  d["requestId"] = requestId
  d["correlationId"] = correlationId
  d["customerReference"] = customerReference
  d["legalName"] = legalName
  d["dateOfBirth"] = dateOfBirth
  d["postcode"] = postcode
  d["requestedProduct"] = requestedProduct
  d["requestedCurrency"] = requestedCurrency
  d["requestedAt"] = requestedAt~utcIsoDate
  return d

::class FederationBankCreditScoreReport public
::attribute requestId get
::attribute correlationId get
::attribute bureauReference get
::attribute score get
::attribute scoreBand get
::attribute status get
::attribute reasonCodes get
::attribute generatedAt get
::method init
  expose requestId correlationId bureauReference score scoreBand status reasonCodes generatedAt
  use arg requestIdArg, correlationIdArg, bureauReferenceArg, scoreArg, scoreBandArg = "", statusArg = "OK", reasonCodesArg = .nil, generatedAtArg = .nil
  requestId = requestIdArg~string
  correlationId = correlationIdArg~string
  bureauReference = bureauReferenceArg~string
  score = scoreArg + 0
  scoreBand = scoreBandArg~string~upper
  status = statusArg~string~upper
  if reasonCodesArg == .nil then reasonCodes = .array~new
  else reasonCodes = reasonCodesArg
  if generatedAtArg == .nil then generatedAt = .DateTime~new
  else generatedAt = generatedAtArg
::method asDirectory
  expose requestId correlationId bureauReference score scoreBand status reasonCodes generatedAt
  d = .directory~new
  d["schema"] = "federationbank.credit-score.report/0.1"
  d["requestId"] = requestId
  d["correlationId"] = correlationId
  d["bureauReference"] = bureauReference
  d["score"] = score
  d["scoreBand"] = scoreBand
  d["status"] = status
  d["reasonCodes"] = reasonCodes
  d["generatedAt"] = generatedAt~utcIsoDate
  return d

::class FederationBankCreditAgencyPort public
::method requestScore
  use arg request
  return .FederationBankResult~failure("CREDIT_AGENCY_NOT_CONFIGURED")

/* The live agency is owned independently (Grok's black-box application).
   This codec fixes the Engine-side JMS envelope without embedding broker
   credentials or agency business logic in FederationBank. */
::class FederationBankJmsCreditAgencyCodec public
::constant REQUEST_SCHEMA "federationbank.credit-score.request/0.1"
::constant REPORT_SCHEMA "federationbank.credit-score.report/0.1"
::method requestMessage
  use arg request
  if request == .nil then return .FederationBankResult~failure("CREDIT_REQUEST_REQUIRED")
  headers = .directory~new
  headers["schema"] = self~REQUEST_SCHEMA
  headers["requestId"] = request~requestId
  headers["correlationId"] = request~correlationId
  properties = .directory~new
  properties["FederationBankOperation"] = "CREDIT_SCORE"
  /* Queue/JMS bridge dev6 sends TEXT bodies. QGRAPH is a deterministic,
     Java-free representation; Grok's agency may use JSON instead when the
     mutually-agreed live wire contract is cut. */
  body = .QueueGraphPayloadCodec~new~encode(request~asDirectory)
  message = .JMSBridgeMessage~new(request~requestId, "TEXT", body, headers, properties, "FEDERATIONBANK", "ENGINE", request~requestedAt~utcIsoDate)
  return .FederationBankResult~success(message)
::method reportMessage
  use arg report
  if report == .nil then return .FederationBankResult~failure("CREDIT_REPORT_REQUIRED")
  headers = .directory~new
  headers["schema"] = self~REPORT_SCHEMA
  headers["requestId"] = report~requestId
  headers["correlationId"] = report~correlationId
  properties = .directory~new
  properties["FederationBankOperation"] = "CREDIT_SCORE_REPORT"
  body = .QueueGraphPayloadCodec~new~encode(report~asDirectory)
  message = .JMSBridgeMessage~new(report~bureauReference, "TEXT", body, headers, properties, "CREDIT_AGENCY", "JMS", report~generatedAt~utcIsoDate)
  return .FederationBankResult~success(message)
::method reportFromMessage
  use arg message
  if message == .nil then return .FederationBankResult~failure("CREDIT_REPORT_MESSAGE_REQUIRED")
  if \message~isA(.JMSBridgeMessage) then return .FederationBankResult~failure("CREDIT_REPORT_MESSAGE_TYPE_INVALID")
  if message~bodyType <> "TEXT" then return .FederationBankResult~failure("CREDIT_REPORT_BODY_TYPE_INVALID", message~bodyType)
  signal on syntax name decodeFailed
  payload = .QueueGraphPayloadCodec~new~decode(message~body)
  signal off syntax
  if \payload~isA(.Directory) then return .FederationBankResult~failure("CREDIT_REPORT_PAYLOAD_INVALID")
  if payload["schema"] <> self~REPORT_SCHEMA then return .FederationBankResult~failure("CREDIT_REPORT_SCHEMA_INVALID", payload["schema"])
  iso = payload["generatedAt"]~string
  if iso~right(1) = "Z" then iso = iso~left(iso~length - 1)
  generated = .DateTime~fromIsoDate(iso)
  report = .FederationBankCreditScoreReport~new(payload["requestId"], payload["correlationId"], payload["bureauReference"], payload["score"], payload["scoreBand"], payload["status"], payload["reasonCodes"], generated)
  return .FederationBankResult~success(report)
decodeFailed:
  signal off syntax
  return .FederationBankResult~failure("CREDIT_REPORT_DECODE_FAILED", condition("D"))

::class FederationBankExternalChecks public
::method init
  expose addressVerifier creditAgency
  use arg addressVerifierArg = .nil, creditAgencyArg = .nil
  addressVerifier = addressVerifierArg
  creditAgency = creditAgencyArg
::method verifyAddress
  expose addressVerifier
  use arg command
  if addressVerifier == .nil then return .FederationBankResult~failure("ADDRESS_VERIFIER_NOT_CONFIGURED")
  return addressVerifier~verify(command)
::method obtainCreditReport
  expose creditAgency
  use arg command, addressEvidence = .nil, requirements = .nil
  if creditAgency == .nil then return .FederationBankResult~failure("CREDIT_AGENCY_NOT_CONFIGURED")
  if creditAgency~hasMethod("REQUESTFOR") then return creditAgency~requestFor(command, addressEvidence, requirements)
  req = .FederationBankCreditScoreRequest~new(command~commandId || "-CREDIT", command~commandId, command~customerId, command~legalName, command~dateOfBirth, command~postcode, command~productCode, command~currency, command~requestedAt)
  return creditAgency~requestScore(req)

::class FederationBankBouncer public
::method init
  expose framework engine
  use arg frameworkArg, engineArg = .nil
  if frameworkArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_BOUNCER_POLICY_REQUIRED")
  framework = frameworkArg
  if engineArg == .nil then engine = .SecurityEffectEngine~new
  else engine = engineArg
::method addFinding private
  use arg snapshot, id, kind, subjectId, detail, atTime
  finding = .SecurityFinding~new(id, kind, .SecurityConstant~FINDING_CONCERN, subjectId, 100, atTime, .nil, detail, "FEDERATIONBANK_ENGINE")~seal
  snapshot~addFinding(finding)
::method evaluateAtmPhysical
  expose framework engine
  use arg command, account, knownDuplicate = .false
  op = command~operation
  action = .SecurityActionSurface~new(command~commandId, command~customerId, op, command~requestedAt, "FINANCIAL", "ATM_PHYSICAL_CASH")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("TERMINAL_ID", command~detail("terminalId"))
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if op <> "WITHDRAW_COMMIT" & op <> "DEPOSIT_COMMIT" then self~addFinding(snapshot, command~commandId || "-OP", "BOGUS_TRANSACTION", command~customerId, "unsupported ATM physical operation", command~requestedAt)
  if command~channel <> "ATM" then self~addFinding(snapshot, command~commandId || "-CHANNEL", "BOGUS_TRANSACTION", command~customerId, "ATM physical operation requires ATM channel", command~requestedAt)
  if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive ATM amount", command~requestedAt)
  if account == .nil then self~addFinding(snapshot, command~commandId || "-ACCOUNT", "BOGUS_TRANSACTION", command~customerId, "ATM account absent", command~requestedAt)
  else do
    if account~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "ATM account/customer mismatch", command~requestedAt)
    if account~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "ATM account/currency mismatch", command~requestedAt)
    if account~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-STATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "ATM account not open", command~requestedAt)
  end
  do key over .array~of("terminalId", "atmNetworkId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence")
    if command~detail(key)~string = "" then self~addFinding(snapshot, command~commandId || "-" || key~upper, "BOGUS_TRANSACTION", command~customerId, "missing ATM physical evidence " || key, command~requestedAt)
  end
  if op = "WITHDRAW_COMMIT" then do
    if command~detail("authorizationId")~string = "" then self~addFinding(snapshot, command~commandId || "-AUTH", "BOGUS_TRANSACTION", command~customerId, "missing withdrawal authorization", command~requestedAt)
    if command~detail("holdId")~string = "" then self~addFinding(snapshot, command~commandId || "-HOLD", "BOGUS_TRANSACTION", command~customerId, "missing withdrawal hold", command~requestedAt)
    if command~detail("dispensedMinor")~string = "" then self~addFinding(snapshot, command~commandId || "-DISP", "BOGUS_TRANSACTION", command~customerId, "missing dispensed amount", command~requestedAt)
    else if command~detail("dispensedMinor") + 0 <> command~amountMinor then self~addFinding(snapshot, command~commandId || "-DISPMATCH", "BOGUS_TRANSACTION", command~customerId, "dispensed amount mismatch", command~requestedAt)
  end
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "ATM physical transaction already committed", command~requestedAt)
  snapshot~seal; action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)

::method evaluate
  expose framework engine
  use arg command, sourceAccount, targetAccount, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "BANKING_TRANSFER")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("BOOKING_JURISDICTION", .FederationBankBuild~BOOKING_JURISDICTION)
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive amount", command~requestedAt)
  if command~currency = "" then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "missing currency", command~requestedAt)
  if sourceAccount == .nil then self~addFinding(snapshot, command~commandId || "-SRC", "BOGUS_TRANSACTION", command~customerId, "source account absent", command~requestedAt)
  if targetAccount == .nil then self~addFinding(snapshot, command~commandId || "-DST", "BOGUS_TRANSACTION", command~customerId, "target account absent", command~requestedAt)
  if sourceAccount <> .nil then do
    if sourceAccount~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-SCUR", "BOGUS_TRANSACTION", command~customerId, "declared/source currency mismatch", command~requestedAt)
    if sourceAccount~internalAccount = .false & sourceAccount~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "source account/customer mismatch", command~requestedAt)
    if sourceAccount~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-SSTATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "source account not open", command~requestedAt)
  end
  if targetAccount <> .nil then do
    if targetAccount~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-TCUR", "BOGUS_TRANSACTION", command~customerId, "declared/target currency mismatch", command~requestedAt)
    if targetAccount~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-TSTATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "target account not open", command~requestedAt)
  end
  if sourceAccount <> .nil & targetAccount <> .nil then if sourceAccount~accountId = targetAccount~accountId then self~addFinding(snapshot, command~commandId || "-SAME", "BOGUS_TRANSACTION", command~customerId, "same-account transfer", command~requestedAt)
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "idempotency key already posted", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)
::method evaluateFx
  expose framework engine
  use arg command, sourceAccount, targetAccount, knownDuplicate = .false
  targetCurrency = command~detail("targetCurrency")~string~upper
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "FX_CONVERSION")
  action~putAttribute("SOURCE_CURRENCY", command~currency)
  action~putAttribute("TARGET_CURRENCY", targetCurrency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive FX source amount", command~requestedAt)
  if command~currency = "" | targetCurrency = "" then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "missing FX currency", command~requestedAt)
  if command~currency = targetCurrency & command~currency <> "" then self~addFinding(snapshot, command~commandId || "-PAIR", "BOGUS_TRANSACTION", command~customerId, "same-currency FX request", command~requestedAt)
  if sourceAccount == .nil then self~addFinding(snapshot, command~commandId || "-SRC", "BOGUS_TRANSACTION", command~customerId, "source account absent", command~requestedAt)
  if targetAccount == .nil then self~addFinding(snapshot, command~commandId || "-DST", "BOGUS_TRANSACTION", command~customerId, "target account absent", command~requestedAt)
  if sourceAccount <> .nil then do
    if sourceAccount~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-SCUR", "BOGUS_TRANSACTION", command~customerId, "source currency mismatch", command~requestedAt)
    if sourceAccount~internalAccount = .false & sourceAccount~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "source account/customer mismatch", command~requestedAt)
    if sourceAccount~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-SSTATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "source account not open", command~requestedAt)
  end
  if targetAccount <> .nil then do
    if targetAccount~currency <> targetCurrency then self~addFinding(snapshot, command~commandId || "-TCUR", "BOGUS_TRANSACTION", command~customerId, "target currency mismatch", command~requestedAt)
    if targetAccount~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-TOWNER", "BOGUS_TRANSACTION", command~customerId, "target account/customer mismatch", command~requestedAt)
    if targetAccount~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-TSTATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "target account not open", command~requestedAt)
  end
  if sourceAccount <> .nil & targetAccount <> .nil then if sourceAccount~accountId = targetAccount~accountId then self~addFinding(snapshot, command~commandId || "-SAME", "BOGUS_TRANSACTION", command~customerId, "same-account FX request", command~requestedAt)
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "idempotency key already posted", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)

::method evaluateOfflineAuthorityIssue
  expose framework engine
  use arg command, account, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "ATM_OFFLINE_AUTHORITY")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("TERMINAL_ID", command~detail("terminalId"))
  action~putAttribute("AUTHORITY_MODE", command~detail("authorityMode"))
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~operation <> "ATM_OFFLINE_AUTHORITY_ISSUE" then self~addFinding(snapshot, command~commandId || "-OP", "BOGUS_TRANSACTION", command~customerId, "unsupported offline authority operation", command~requestedAt)
  if command~channel <> "ATM" then self~addFinding(snapshot, command~commandId || "-CHANNEL", "BOGUS_TRANSACTION", command~customerId, "offline authority requires ATM channel", command~requestedAt)
  if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive offline authority amount", command~requestedAt)
  if account == .nil then self~addFinding(snapshot, command~commandId || "-ACCOUNT", "BOGUS_TRANSACTION", command~customerId, "offline authority account absent", command~requestedAt)
  else do
    if account~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "offline authority account/customer mismatch", command~requestedAt)
    if account~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "offline authority account/currency mismatch", command~requestedAt)
    if account~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-STATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "offline authority account not open", command~requestedAt)
  end
  do key over .array~of("terminalId", "atmNetworkId", "rulesetId", "rulesVersion", "authorityMode")
    if command~detail(key)~string = "" then self~addFinding(snapshot, command~commandId || "-" || key~upper, "BOGUS_TRANSACTION", command~customerId, "missing offline authority evidence " || key, command~requestedAt)
  end
  mode = command~detail("authorityMode")~string~upper
  if mode <> "RESERVED_ALLOWANCE" & mode <> "DELEGATED_STAND_IN" then self~addFinding(snapshot, command~commandId || "-MODE", "BOGUS_TRANSACTION", command~customerId, "unsupported offline authority mode", command~requestedAt)
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "offline authority issue replay", command~requestedAt)
  snapshot~seal; action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)

::method evaluateOfflineCashAdvice
  expose framework engine
  use arg command, account, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "ATM_OFFLINE_SETTLEMENT")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("TERMINAL_ID", command~detail("terminalId"))
  action~putAttribute("OFFLINE_AUTHORITY_ID", command~detail("offlineAuthorityId"))
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~channel <> "ATM" then self~addFinding(snapshot, command~commandId || "-CHANNEL", "BOGUS_TRANSACTION", command~customerId, "offline cash advice must originate from ATM channel", command~requestedAt)
  if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive dispensed amount", command~requestedAt)
  if account == .nil then self~addFinding(snapshot, command~commandId || "-ACCT", "BOGUS_TRANSACTION", command~customerId, "customer account absent", command~requestedAt)
  if account <> .nil then do
    if account~internalAccount = .false & account~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "account/customer mismatch", command~requestedAt)
    if account~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "declared/account currency mismatch", command~requestedAt)
  end
  do key over .array~of("terminalId", "atmNetworkId", "offlineAuthorityId", "rulesetId", "rulesVersion", "physicalTransactionId", "terminalSequence")
    if command~detail(key)~string = "" then self~addFinding(snapshot, command~commandId || "-" || key~upper, "BOGUS_TRANSACTION", command~customerId, "missing offline cash evidence " || key, command~requestedAt)
  end
  if command~detail("authorityMode")~string~upper <> "DELEGATED_STAND_IN" then self~addFinding(snapshot, command~commandId || "-AUTHMODE", "BOGUS_TRANSACTION", command~customerId, "unsupported offline authority mode", command~requestedAt)
  if command~detail("dispensedMinor")~string = "" then self~addFinding(snapshot, command~commandId || "-DISP", "BOGUS_TRANSACTION", command~customerId, "missing dispensed amount evidence", command~requestedAt)
  else if command~detail("dispensedMinor") + 0 <> command~amountMinor then self~addFinding(snapshot, command~commandId || "-DISPMATCH", "BOGUS_TRANSACTION", command~customerId, "dispensed amount does not match advice", command~requestedAt)
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "offline cash settlement already posted", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)

::method evaluateOpenAccount
  expose framework engine
  use arg command, isNewCustomer = .false, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "ACCOUNT_OPENING")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("PRODUCT_CODE", command~productCode)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("BOOKING_JURISDICTION", .FederationBankBuild~BOOKING_JURISDICTION)
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~commandId = "" then self~addFinding(snapshot, "OPEN-MISSING-COMMAND", "BOGUS_TRANSACTION", command~customerId, "missing command id", command~requestedAt)
  if command~idempotencyKey = "" then self~addFinding(snapshot, command~commandId || "-IDEM", "BOGUS_TRANSACTION", command~customerId, "missing idempotency key", command~requestedAt)
  if command~customerId = "" then self~addFinding(snapshot, command~commandId || "-CUST", "BOGUS_TRANSACTION", command~customerId, "missing customer reference", command~requestedAt)
  if command~accountId = "" then self~addFinding(snapshot, command~commandId || "-ACCT", "BOGUS_TRANSACTION", command~customerId, "missing account id", command~requestedAt)
  if command~currency = "" then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "missing currency", command~requestedAt)
  if command~productCode = "" then self~addFinding(snapshot, command~commandId || "-PROD", "BOGUS_TRANSACTION", command~customerId, "missing product code", command~requestedAt)
  if isNewCustomer then do
    if command~legalName = "" then self~addFinding(snapshot, command~commandId || "-NAME", "BOGUS_TRANSACTION", command~customerId, "missing legal name for new customer", command~requestedAt)
    if command~dateOfBirth = "" then self~addFinding(snapshot, command~commandId || "-DOB", "BOGUS_TRANSACTION", command~customerId, "missing date of birth for new customer", command~requestedAt)
    if command~postcode = "" then self~addFinding(snapshot, command~commandId || "-POST", "BOGUS_TRANSACTION", command~customerId, "missing postcode for new customer", command~requestedAt)
    if command~applicantResidence = "" then self~addFinding(snapshot, command~commandId || "-RES", "BOGUS_TRANSACTION", command~customerId, "missing residence for new customer", command~requestedAt)
    if command~applicantDomicile = "" then self~addFinding(snapshot, command~commandId || "-DOM", "BOGUS_TRANSACTION", command~customerId, "missing domicile for new customer", command~requestedAt)
  end
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "durable idempotency receipt already exists", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)
::method evaluateBeneficiary
  expose framework engine
  use arg command, customer, account, existingBeneficiary = .nil, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "BENEFICIARY_LIFECYCLE")
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("BOOKING_JURISDICTION", .FederationBankBuild~BOOKING_JURISDICTION)
  action~putAttribute("ACCOUNT_ID", command~accountId)
  action~putAttribute("BENEFICIARY_ID", command~detail("beneficiaryId"))
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~commandId = "" then self~addFinding(snapshot, "BEN-MISSING-COMMAND", "BOGUS_TRANSACTION", command~customerId, "missing command id", command~requestedAt)
  if command~idempotencyKey = "" then self~addFinding(snapshot, command~commandId || "-IDEM", "BOGUS_TRANSACTION", command~customerId, "missing idempotency key", command~requestedAt)
  if customer == .nil then self~addFinding(snapshot, command~commandId || "-CUST", "BOGUS_TRANSACTION", command~customerId, "customer absent", command~requestedAt)
  if account == .nil then self~addFinding(snapshot, command~commandId || "-ACCT", "BOGUS_TRANSACTION", command~customerId, "owning account absent", command~requestedAt)
  if account <> .nil then do
    if account~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "owning account/customer mismatch", command~requestedAt)
    if account~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-STATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "owning account not open", command~requestedAt)
  end
  beneficiaryId = command~detail("beneficiaryId")~string
  if existingBeneficiary <> .nil then if existingBeneficiary~ownerAccountId <> command~accountId then self~addFinding(snapshot, command~commandId || "-BENOWNER", "BENEFICIARY_STATE_INVALID", command~customerId, "beneficiary owning account mismatch", command~requestedAt)
  if beneficiaryId = "" then self~addFinding(snapshot, command~commandId || "-BENID", "BOGUS_TRANSACTION", command~customerId, "missing beneficiary id", command~requestedAt)
  if command~operation = "ADD_BENEFICIARY" | command~operation = "AMEND_BENEFICIARY" then do
    if command~detail("displayName")~string = "" then self~addFinding(snapshot, command~commandId || "-BENNAME", "BOGUS_TRANSACTION", command~customerId, "missing beneficiary display name", command~requestedAt)
    if command~detail("accountReference")~string = "" then self~addFinding(snapshot, command~commandId || "-BENACCT", "BOGUS_TRANSACTION", command~customerId, "missing beneficiary account reference", command~requestedAt)
    if command~detail("country")~string = "" then self~addFinding(snapshot, command~commandId || "-BENCOUNTRY", "BOGUS_TRANSACTION", command~customerId, "missing beneficiary country", command~requestedAt)
    if command~detail("currency")~string = "" then self~addFinding(snapshot, command~commandId || "-BENCUR", "BOGUS_TRANSACTION", command~customerId, "missing beneficiary currency", command~requestedAt)
  end
  if command~operation = "ADD_BENEFICIARY" then do
    if existingBeneficiary <> .nil then self~addFinding(snapshot, command~commandId || "-DUPBEN", "BENEFICIARY_STATE_INVALID", command~customerId, "beneficiary already exists", command~requestedAt)
  end
  else if command~operation = "AMEND_BENEFICIARY" then do
    if existingBeneficiary == .nil then self~addFinding(snapshot, command~commandId || "-NOBEN", "BENEFICIARY_STATE_INVALID", command~customerId, "beneficiary does not exist", command~requestedAt)
  end
  else if command~operation = "SUSPEND_BENEFICIARY" then do
    if existingBeneficiary == .nil then self~addFinding(snapshot, command~commandId || "-NOBEN", "BENEFICIARY_STATE_INVALID", command~customerId, "beneficiary does not exist", command~requestedAt)
    else if existingBeneficiary~status = "SUSPENDED" then self~addFinding(snapshot, command~commandId || "-SUSP", "BENEFICIARY_STATE_INVALID", command~customerId, "beneficiary already suspended", command~requestedAt)
  end
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "durable idempotency receipt already exists", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)
::method evaluateHold
  expose framework engine
  use arg command, account, knownDuplicate = .false
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "FUNDS_RESERVATION")
  action~putAttribute("CURRENCY", command~currency)
  action~putAttribute("AMOUNT_MINOR", command~amountMinor)
  action~putAttribute("CHANNEL", command~channel)
  action~putAttribute("BOOKING_JURISDICTION", .FederationBankBuild~BOOKING_JURISDICTION)
  action~putAttribute("ACCOUNT_ID", command~sourceAccountId)
  action~putAttribute("HOLD_ID", command~detail("holdId"))
  snapshot = .SecuritySnapshot~new("BOUNCER-" || command~commandId, command~customerId, command~requestedAt)
  if command~commandId = "" then self~addFinding(snapshot, "HOLD-MISSING-COMMAND", "BOGUS_TRANSACTION", command~customerId, "missing command id", command~requestedAt)
  if command~idempotencyKey = "" then self~addFinding(snapshot, command~commandId || "-IDEM", "BOGUS_TRANSACTION", command~customerId, "missing idempotency key", command~requestedAt)
  if command~detail("holdId")~string = "" then self~addFinding(snapshot, command~commandId || "-HOLDID", "BOGUS_TRANSACTION", command~customerId, "missing hold id", command~requestedAt)
  if account == .nil then self~addFinding(snapshot, command~commandId || "-ACCT", "BOGUS_TRANSACTION", command~customerId, "account absent", command~requestedAt)
  if account <> .nil then do
    if account~internalAccount = .false & account~customerId <> command~customerId then self~addFinding(snapshot, command~commandId || "-OWNER", "BOGUS_TRANSACTION", command~customerId, "account/customer mismatch", command~requestedAt)
    if account~currency <> command~currency then self~addFinding(snapshot, command~commandId || "-CUR", "BOGUS_TRANSACTION", command~customerId, "declared/account currency mismatch", command~requestedAt)
    if account~status <> "OPEN" then self~addFinding(snapshot, command~commandId || "-STATE", "ACCOUNT_NOT_OPERABLE", command~customerId, "account not open", command~requestedAt)
  end
  if command~operation = "PLACE_HOLD" then if command~amountMinor <= 0 then self~addFinding(snapshot, command~commandId || "-AMOUNT", "BOGUS_TRANSACTION", command~customerId, "non-positive hold amount", command~requestedAt)
  if knownDuplicate then self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "durable hold receipt already exists", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)
::method evaluateReplay
  expose framework engine
  use arg command
  action = .SecurityActionSurface~new(command~commandId, command~customerId, command~operation, command~requestedAt, "FINANCIAL", "IDEMPOTENCY_REPLAY")
  snapshot = .SecuritySnapshot~new("BOUNCER-REPLAY-" || command~commandId, command~customerId, command~requestedAt)
  self~addFinding(snapshot, command~commandId || "-REPLAY", "REPLAY_SUSPECTED", command~customerId, "durable committed receipt already exists", command~requestedAt)
  snapshot~seal
  action~seal
  evaluated = engine~evaluate(action, snapshot, framework)
  if evaluated~ok = .false then return .FederationBankResult~failure("BOUNCER_EVALUATION_FAILED", evaluated~code || ":" || evaluated~detail, evaluated)
  return .FederationBankResult~success(evaluated~value)
::method standardFramework class
  /* Fixture deployment effectivity belongs to the policy revision, not the
     worker process start time.  A restarted worker must be able to classify
     an older committed command under the same deployed policy generation. */
  effectiveAt = .DateTime~fromIsoDate("2020-01-01T00:00:00.000000")
  p = .SecurityPolicyFramework~new("FB-BOUNCER", "1", effectiveAt, .nil, "FederationBank Security", "FederationBank Risk")
  r1 = .SecurityPolicyRule~new("REJECT-BOGUS", 10, "TRANSFER", .SecurityConstant~DISP_REJECT, "Bogus transaction cannot reach monetary truth")
  r1~requireFinding("BOGUS_TRANSACTION")
  r1~addConstraint("NO_POSTING", "ACTION", "Reject before ledger posting")
  p~addRule(r1~seal)
  r2 = .SecurityPolicyRule~new("REJECT-REPLAY", 20, "TRANSFER", .SecurityConstant~DISP_REJECT, "Replay/idempotency collision")
  r2~requireFinding("REPLAY_SUSPECTED")
  r2~addConstraint("NO_POSTING", "ACTION", "Duplicate request cannot repost")
  p~addRule(r2~seal)
  r3 = .SecurityPolicyRule~new("HOLD-ACCOUNT", 30, "TRANSFER", .SecurityConstant~DISP_HOLD, "Non-operable account requires hold/review")
  r3~requireFinding("ACCOUNT_NOT_OPERABLE")
  r3~addConstraint("HOLD_TRANSACTION", "ACTION", "Do not post until account state is resolved")
  p~addRule(r3~seal)
  r4 = .SecurityPolicyRule~new("REJECT-OPEN-BOGUS", 10, "OPEN_ACCOUNT", .SecurityConstant~DISP_REJECT, "Bogus account-opening command cannot change core state")
  r4~requireFinding("BOGUS_TRANSACTION")
  r4~addConstraint("NO_STATE_CHANGE", "ACTION", "Reject before customer/account persistence")
  p~addRule(r4~seal)
  r5 = .SecurityPolicyRule~new("REJECT-OPEN-REPLAY", 20, "OPEN_ACCOUNT", .SecurityConstant~DISP_REJECT, "Committed account-opening replay cannot execute again")
  r5~requireFinding("REPLAY_SUSPECTED")
  r5~addConstraint("NO_STATE_CHANGE", "ACTION", "Recover durable receipt instead of repeating open")
  p~addRule(r5~seal)
  do op over .array~of("FX_CONVERT", "OFFLINE_WITHDRAWAL_ADVICE", "ATM_OFFLINE_AUTHORITY_ISSUE")
    rx = .SecurityPolicyRule~new("REJECT-" || op || "-BOGUS", 10, op, .SecurityConstant~DISP_REJECT, "Invalid banking command cannot change monetary truth")
    rx~requireFinding("BOGUS_TRANSACTION")
    rx~addConstraint("NO_POSTING", "ACTION", "Reject before Ledger posting")
    p~addRule(rx~seal)
    rr = .SecurityPolicyRule~new("REJECT-" || op || "-REPLAY", 20, op, .SecurityConstant~DISP_REJECT, "Committed operation replay cannot execute again")
    rr~requireFinding("REPLAY_SUSPECTED")
    rr~addConstraint("NO_POSTING", "ACTION", "Recover durable receipt instead of reposting")
    p~addRule(rr~seal)
  end
  do op over .array~of("WITHDRAW_COMMIT", "DEPOSIT_COMMIT")
    ra = .SecurityPolicyRule~new("REJECT-" || op || "-BOGUS", 10, op, .SecurityConstant~DISP_REJECT, "Invalid ATM physical cash fact cannot change monetary truth")
    ra~requireFinding("BOGUS_TRANSACTION")
    ra~addConstraint("NO_POSTING", "ACTION", "Reject before ATM Ledger posting")
    p~addRule(ra~seal)
    rr = .SecurityPolicyRule~new("REJECT-" || op || "-REPLAY", 20, op, .SecurityConstant~DISP_REJECT, "Committed ATM physical cash fact replay cannot execute again")
    rr~requireFinding("REPLAY_SUSPECTED")
    rr~addConstraint("NO_POSTING", "ACTION", "Recover durable receipt instead of reposting ATM cash fact")
    p~addRule(rr~seal)
  end
  do op over .array~of("PLACE_HOLD", "RELEASE_HOLD")
    rh = .SecurityPolicyRule~new("REJECT-" || op || "-BOGUS", 10, op, .SecurityConstant~DISP_REJECT, "Invalid funds-reservation command cannot change Ledger reservation state")
    rh~requireFinding("BOGUS_TRANSACTION")
    rh~addConstraint("NO_STATE_CHANGE", "ACTION", "Reject before hold persistence")
    p~addRule(rh~seal)
  end
  do op over .array~of("ADD_BENEFICIARY", "AMEND_BENEFICIARY", "SUSPEND_BENEFICIARY")
    rb = .SecurityPolicyRule~new("REJECT-" || op || "-BOGUS", 10, op, .SecurityConstant~DISP_REJECT, "Invalid beneficiary lifecycle command cannot change core state")
    rb~requireFinding("BOGUS_TRANSACTION")
    rb~addConstraint("NO_STATE_CHANGE", "ACTION", "Reject before beneficiary persistence")
    p~addRule(rb~seal)
    rs = .SecurityPolicyRule~new("REJECT-" || op || "-STATE", 15, op, .SecurityConstant~DISP_REJECT, "Invalid beneficiary lifecycle state transition")
    rs~requireFinding("BENEFICIARY_STATE_INVALID")
    rs~addConstraint("NO_STATE_CHANGE", "ACTION", "Reject invalid beneficiary transition")
    p~addRule(rs~seal)
    rr = .SecurityPolicyRule~new("REJECT-" || op || "-REPLAY", 20, op, .SecurityConstant~DISP_REJECT, "Committed beneficiary operation replay cannot execute again")
    rr~requireFinding("REPLAY_SUSPECTED")
    rr~addConstraint("NO_STATE_CHANGE", "ACTION", "Recover durable receipt instead of repeating beneficiary change")
    p~addRule(rr~seal)
  end
  return p~seal

/* Account-lifecycle authority extracted from the legacy combined Engine.
 * This is the actual core used by the queue-addressable Account Engine.
 * It has no payment authorisation method and no balance/posting API.
 */
::class FederationBankAccountAuthority public
::method init
  expose customers accounts profiles legalGate bouncer receipts openingPolicyGate externalChecks beneficiaries beneficiaryPolicyGate
  use arg customersArg, accountsArg, profilesArg, legalGateArg, bouncerArg, openingPolicyGateArg, externalChecksArg = .nil, beneficiariesArg = .nil, beneficiaryPolicyGateArg = .nil
  if customersArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_CUSTOMERS_REQUIRED")
  if accountsArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_REGISTRY_REQUIRED")
  if profilesArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_PROFILES_REQUIRED")
  if legalGateArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_LEGAL_GATE_REQUIRED")
  if bouncerArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_BOUNCER_REQUIRED")
  if openingPolicyGateArg == .nil then raise syntax 88.900 array("FEDERATIONBANK_ACCOUNT_POLICY_GATE_REQUIRED")
  customers = customersArg
  accounts = accountsArg
  profiles = profilesArg
  legalGate = legalGateArg
  bouncer = bouncerArg
  openingPolicyGate = openingPolicyGateArg
  externalChecks = externalChecksArg
  if beneficiariesArg == .nil then beneficiaries = .FederationBankBeneficiaryRegistry~new
  else beneficiaries = beneficiariesArg
  beneficiaryPolicyGate = beneficiaryPolicyGateArg
  receipts = .directory~new
::method customers
  expose customers
  return customers
::method accounts
  expose accounts
  return accounts
::method profiles
  expose profiles
  return profiles
::method beneficiaries
  expose beneficiaries
  return beneficiaries
::method rebuildBeneficiariesFromStore
  expose accounts beneficiaries
  if accounts~store == .nil then return .FederationBankResult~success(0, "no durable store")
  recovered = accounts~store~recoverBeneficiaries
  if recovered~ok = .false then return recovered
  count = 0
  do beneficiary over recovered~value
    applied = beneficiaries~upsert(beneficiary)
    if applied~ok = .false then return applied
    count += 1
  end
  return .FederationBankResult~success(count)
::method lookupReceipt
  expose receipts accounts
  use arg idempotencyKey
  key = idempotencyKey~string
  if receipts~hasIndex(key) then return .FederationBankResult~success(receipts[key])
  if accounts~store <> .nil then do
    recovered = accounts~store~recoverReceipt(key)
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      receipts[key] = recovered~value
      return .FederationBankResult~success(receipts[key])
    end
  end
  return .FederationBankResult~success(.nil)
::method receipt
  use arg idempotencyKey
  found = self~lookupReceipt(idempotencyKey)
  if found~ok = .false then return .nil
  return found~value
::method copyDirectory private
  use arg original
  copy = .directory~new
  if original == .nil then return copy
  do key over original
    copy[key] = original[key]
  end
  return copy
::method replayReceipt private
  expose bouncer
  use arg command, receipt
  security = bouncer~evaluateReplay(command)
  if security~ok = .false then return security
  assessment = security~value
  d = self~copyDirectory(receipt)
  d["replayRecovered"] = "true"
  d["replaySecurityDisposition"] = assessment~disposition
  d["replaySecurityPolicyId"] = assessment~policy~policyId
  d["replaySecurityPolicyVersion"] = assessment~policy~version
  d["replaySecurityTraceIdentity"] = assessment~trace~traceIdentity
  return .FederationBankResult~new(.true, "REPLAY_RECOVERED", "Committed account operation was not re-executed", d)
::method openingOutcome private
  use arg outcome, reason, command, security = .nil, policy = .nil, legal = .nil, address = .nil, credit = .nil
  d = .directory~new
  d["outcome"] = outcome
  d["reason"] = reason
  d["operation"] = command~operation
  d["commandId"] = command~commandId
  d["idempotencyKey"] = command~idempotencyKey
  d["customerId"] = command~customerId
  d["accountId"] = command~accountId
  d["currency"] = command~currency
  if security <> .nil then do
    d["securityPolicyId"] = security~policy~policyId
    d["securityPolicyVersion"] = security~policy~version
    d["securityDisposition"] = security~disposition
    d["securityTraceIdentity"] = security~trace~traceIdentity
  end
  if policy <> .nil then do
    if policy~hasIndex("policyId") then d["corporatePolicyId"] = policy["policyId"]
    if policy~hasIndex("policyVersion") then d["corporatePolicyVersion"] = policy["policyVersion"]
    if policy~hasIndex("ruleId") then d["corporatePolicyRuleId"] = policy["ruleId"]
  end
  if legal <> .nil then do
    if legal~hasIndex("legalProfileId") then d["legalProfileId"] = legal["legalProfileId"]
    if legal~hasIndex("generationId") then d["legalGenerationId"] = legal["generationId"]
    if legal~hasIndex("generationVersion") then d["legalGenerationVersion"] = legal["generationVersion"]
    if legal~hasIndex("status") then d["legalStatus"] = legal["status"]
  end
  if address <> .nil then do
    if address~hasIndex("reference") then d["addressVerificationReference"] = address["reference"]
    if address~hasIndex("contractGeneration") then d["addressContractGeneration"] = address["contractGeneration"]
    if address~hasIndex("mappingGeneration") then d["addressMappingGeneration"] = address["mappingGeneration"]
  end
  if credit <> .nil then do
    d["creditBureauReference"] = credit~bureauReference
    if credit~hasMethod("OVERALLDISPOSITION") then do
      d["creditStatus"] = credit~overallDisposition
      if credit~hasScaledValue then d["creditScore"] = credit~scaledValue
      else d["creditScore"] = ""
      d["creditMethodologyVersion"] = credit~methodologyVersion
      d["creditNextPermittedRefreshNotBefore"] = credit~nextPermittedRefreshNotBefore
    end
    else do
      d["creditStatus"] = credit~status
      d["creditScore"] = credit~score
    end
  end
  return d
::method openAccount
  expose customers accounts profiles legalGate bouncer receipts openingPolicyGate externalChecks
  use arg command
  if command~operation <> "OPEN_ACCOUNT" then return .FederationBankResult~failure("OPERATION_INVALID", command~operation)
  if command~idempotencyKey = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  customer = customers~customer(command~customerId)
  isNewCustomer = (customer == .nil)

  security = bouncer~evaluateOpenAccount(command, isNewCustomer, .false)
  if security~ok = .false then return security
  assessment = security~value
  select
    when assessment~disposition = .SecurityConstant~DISP_REJECT then return .FederationBankResult~failure("SECURITY_REJECTED", assessment~trace~traceIdentity, self~openingOutcome("REJECTED","BOUNCER_REJECTED",command,assessment))
    when assessment~disposition = .SecurityConstant~DISP_HOLD then return .FederationBankResult~failure("SECURITY_HELD", assessment~trace~traceIdentity, self~openingOutcome("REFERRED","BOUNCER_HELD",command,assessment))
    when assessment~disposition = .SecurityConstant~DISP_REVIEW then return .FederationBankResult~failure("SECURITY_REVIEW_REQUIRED", assessment~trace~traceIdentity, self~openingOutcome("REFERRED","BOUNCER_REVIEW",command,assessment))
    otherwise nop
  end

  if accounts~account(command~accountId) <> .nil then return .FederationBankResult~failure("ACCOUNT_DUPLICATE", command~accountId)
  profile = profiles~byCurrency(command~currency)
  if profile == .nil then return .FederationBankResult~failure("UNSUPPORTED_CURRENCY", command~currency)
  if openingPolicyGate == .nil then return .FederationBankResult~failure("OPENING_POLICY_GATE_NOT_CONFIGURED")

  if isNewCustomer then do
    addressCountry = command~addressCountry
    customer = .FederationBankCustomer~new(command~customerId, command~applicantSegment, command~applicantDomicile, command~applicantResidence, command~applicantRiskTier, .FederationBankBuild~LIMIT_POLICY_DEFAULT, command~legalName, command~dateOfBirth, command~postcode, addressCountry)
  end

  /* Authority order is deliberate: Bouncer -> policy resolution -> Legal
     Effect -> required external observations -> final application of the
     already-resolved policy -> one durable core-state transaction. */
  requirements = openingPolicyGate~resolveRequirements(command, isNewCustomer)
  if requirements~ok = .false then return requirements
  req = requirements~value

  legal = legalGate~evaluateOpenAccount(command, customer, profile)
  if legal~ok = .false then return legal

  addressEvidence = .nil
  if req["addressVerificationRequired"] then do
    if externalChecks == .nil then return .FederationBankResult~failure("ADDRESS_VERIFIER_NOT_CONFIGURED")
    addressResult = externalChecks~verifyAddress(command)
    if addressResult~ok = .false then do
      out = self~openingOutcome("REJECTED","ADDRESS_VERIFICATION_FAILED",command,assessment,req,legal~value)
      return .FederationBankResult~failure("ADDRESS_VERIFICATION_REJECTED", addressResult~code || ":" || addressResult~detail, out)
    end
    addressEvidence = addressResult~value
  end

  creditReport = .nil
  if req["creditScoreRequired"] then do
    if externalChecks == .nil then return .FederationBankResult~failure("CREDIT_AGENCY_NOT_CONFIGURED")
    creditResult = externalChecks~obtainCreditReport(command, addressEvidence, req)
    if creditResult~ok = .false then do
      out = self~openingOutcome("REJECTED","CREDIT_SCORE_UNAVAILABLE",command,assessment,req,legal~value,addressEvidence)
      return .FederationBankResult~failure("CREDIT_SCORE_REJECTED", creditResult~code || ":" || creditResult~detail, out)
    end
    creditReport = creditResult~value
  end

  policyDecision = openingPolicyGate~decide(req, addressEvidence, creditReport)
  if policyDecision~ok = .false then return policyDecision
  pd = policyDecision~value
  if pd["outcome"] = "REFERRED" then do
    out = self~openingOutcome("REFERRED", pd["reason"], command, assessment, pd, legal~value, addressEvidence, creditReport)
    return .FederationBankResult~failure("ACCOUNT_OPEN_REFERRED", pd["reason"], out)
  end
  if pd["outcome"] <> "ACCEPTED" then do
    out = self~openingOutcome("REJECTED", pd["reason"], command, assessment, pd, legal~value, addressEvidence, creditReport)
    return .FederationBankResult~failure("ACCOUNT_OPEN_REJECTED", pd["reason"], out)
  end

  account = .FederationBankAccount~new(command~accountId, command~customerId, command~currency, command~productCode, profile~bookingJurisdiction, profile~profileId)
  receipt = self~openingOutcome("ACCEPTED","POLICY_SATISFIED",command,assessment,pd,legal~value,addressEvidence,creditReport)
  receipt["regulatoryProfileId"] = profile~profileId
  receipt["bookingJurisdiction"] = account~bookingJurisdiction
  receipt["createdAt"] = command~requestedAt~utcIsoDate

  evidence = .directory~new
  evidence["regulatoryProfileId"] = profile~profileId
  evidence["securityPolicyId"] = assessment~policy~policyId
  evidence["securityPolicyVersion"] = assessment~policy~version
  evidence["securityDisposition"] = assessment~disposition
  evidence["corporatePolicyId"] = pd["policyId"]
  evidence["corporatePolicyVersion"] = pd["policyVersion"]
  evidence["corporatePolicyRuleId"] = pd["ruleId"]
  evidence["legalProfileId"] = legal~value["legalProfileId"]
  evidence["legalGenerationId"] = legal~value["generationId"]
  evidence["legalGenerationVersion"] = legal~value["generationVersion"]
  if addressEvidence <> .nil then do
    evidence["addressVerificationReference"] = addressEvidence["reference"]
    evidence["addressContractGeneration"] = addressEvidence["contractGeneration"]
    evidence["addressMappingGeneration"] = addressEvidence["mappingGeneration"]
  end
  if creditReport <> .nil then do
    evidence["creditBureauReference"] = creditReport~bureauReference
    if creditReport~hasMethod("OVERALLDISPOSITION") then do
      evidence["creditStatus"] = creditReport~overallDisposition
      if creditReport~hasScaledValue then evidence["creditScore"] = creditReport~scaledValue
      else evidence["creditScore"] = ""
      evidence["creditIntelligenceEvidence"] = creditReport~asDirectory
    end
    else do
      evidence["creditStatus"] = creditReport~status
      evidence["creditScore"] = creditReport~score
    end
  end

  if accounts~store == .nil then return .FederationBankResult~failure("CORE_DATABASE_REQUIRED")
  committed = accounts~store~commitOpenAccount(customer, account, isNewCustomer, evidence, receipt)
  if committed~ok = .false then return committed

  /* DB truth exists now; only now may in-memory projections advance. */
  if isNewCustomer then do
    projectedCustomer = customers~add(customer)
    if projectedCustomer~ok = .false then return .FederationBankResult~failure("CUSTOMER_PROJECTION_FAILED_AFTER_COMMIT", projectedCustomer~code, receipt)
  end
  projectedAccount = accounts~addAccount(account)
  if projectedAccount~ok = .false then return .FederationBankResult~failure("ACCOUNT_PROJECTION_FAILED_AFTER_COMMIT", projectedAccount~code, receipt)

  receipt["databaseTransactionId"] = committed~value["databaseTransactionId"]
  receipt["databaseOutcome"] = committed~value["databaseOutcome"]
  receipt["databaseAttempts"] = committed~value["databaseAttempts"]
  receipts[command~idempotencyKey] = receipt
  return .FederationBankResult~success(receipt)
::method manageBeneficiary
  expose customers accounts profiles legalGate bouncer receipts beneficiaries beneficiaryPolicyGate
  use arg command
  op = command~operation
  if op <> "ADD_BENEFICIARY" & op <> "AMEND_BENEFICIARY" & op <> "SUSPEND_BENEFICIARY" then return .FederationBankResult~failure("BENEFICIARY_OPERATION_INVALID", op)
  customer = customers~customer(command~customerId)
  account = accounts~account(command~accountId)
  beneficiaryId = command~detail("beneficiaryId")~string
  existing = beneficiaries~beneficiary(command~customerId, beneficiaryId)
  security = bouncer~evaluateBeneficiary(command, customer, account, existing, .false)
  if security~ok = .false then return security
  assessment = security~value
  if assessment~disposition <> .SecurityConstant~DISP_ALLOW then return .FederationBankResult~failure("SECURITY_NOT_ALLOWED", assessment~disposition, assessment)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  if account == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND", command~accountId)
  if beneficiaryPolicyGate == .nil then return .FederationBankResult~failure("BENEFICIARY_POLICY_GATE_NOT_CONFIGURED")
  profile = profiles~byCurrency(account~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", account~currency)
  activeBefore = beneficiaries~activeCount(customer~customerId)
  policy = beneficiaryPolicyGate~evaluate(command, customer, activeBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legal = legalGate~evaluateBeneficiary(command, customer, account, profile)
  if legal~ok = .false then return legal

  select
    when op = "ADD_BENEFICIARY" then beneficiary = .FederationBankBeneficiary~new(beneficiaryId, command~customerId, command~accountId, command~detail("displayName"), command~detail("accountReference"), command~detail("bankCode"), command~detail("country"), command~detail("currency"), "ACTIVE", 1, command~requestedAt)
    when op = "AMEND_BENEFICIARY" then beneficiary = existing~amended(command~detail("displayName"), command~detail("accountReference"), command~detail("bankCode"), command~detail("country"), command~detail("currency"), command~requestedAt)
    otherwise beneficiary = existing~suspended(command~requestedAt)
  end

  receipt = .directory~new
  receipt["outcome"] = "ACCEPTED"
  receipt["operation"] = op
  receipt["commandId"] = command~commandId
  receipt["idempotencyKey"] = command~idempotencyKey
  receipt["customerId"] = command~customerId
  receipt["accountId"] = command~accountId
  receipt["currency"] = account~currency
  receipt["beneficiaryId"] = beneficiary~beneficiaryId
  receipt["beneficiaryStatus"] = beneficiary~status
  receipt["beneficiaryVersion"] = beneficiary~version
  receipt["beneficiaryDisplayName"] = beneficiary~displayName
  receipt["beneficiaryAccountReference"] = beneficiary~accountReference
  receipt["beneficiaryBankCode"] = beneficiary~bankCode
  receipt["beneficiaryCountry"] = beneficiary~country
  receipt["beneficiaryCurrency"] = beneficiary~currency
  receipt["securityPolicyId"] = assessment~policy~policyId
  receipt["securityPolicyVersion"] = assessment~policy~version
  receipt["securityDisposition"] = assessment~disposition
  receipt["securityTraceIdentity"] = assessment~trace~traceIdentity
  receipt["corporatePolicyId"] = policy~value["policyId"]
  receipt["corporatePolicyVersion"] = policy~value["policyVersion"]
  receipt["corporatePolicyRuleId"] = policy~value["ruleId"]
  receipt["legalProfileId"] = legal~value["legalProfileId"]
  receipt["legalGenerationId"] = legal~value["generationId"]
  receipt["legalGenerationVersion"] = legal~value["generationVersion"]
  receipt["regulatoryProfileId"] = profile~profileId
  receipt["createdAt"] = command~requestedAt~utcIsoDate

  evidence = .directory~new
  do key over .array~of("securityPolicyId","securityPolicyVersion","securityDisposition","corporatePolicyId","corporatePolicyVersion","corporatePolicyRuleId","legalProfileId","legalGenerationId","legalGenerationVersion","regulatoryProfileId")
    evidence[key] = receipt[key]
  end
  if accounts~store == .nil then return .FederationBankResult~failure("CORE_DATABASE_REQUIRED")
  committed = accounts~store~commitBeneficiaryChange(beneficiary, op, evidence, receipt)
  if committed~ok = .false then return committed
  projected = beneficiaries~upsert(beneficiary)
  if projected~ok = .false then return .FederationBankResult~failure("BENEFICIARY_PROJECTION_FAILED_AFTER_COMMIT", projected~code, receipt)
  receipt["databaseTransactionId"] = committed~value["databaseTransactionId"]
  receipt["databaseOutcome"] = committed~value["databaseOutcome"]
  receipt["databaseAttempts"] = committed~value["databaseAttempts"]
  receipts[command~idempotencyKey] = receipt
  return .FederationBankResult~success(receipt)
::method handle
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~idempotencyKey <> "" then do
    lookup = self~lookupReceipt(command~idempotencyKey)
    if lookup~ok = .false then return .FederationBankResult~failure("IDEMPOTENCY_LOOKUP_FAILED", lookup~code || ":" || lookup~detail, lookup)
    existingReceipt = lookup~value
    if existingReceipt <> .nil then return self~replayReceipt(command, existingReceipt)
  end
  select
    when command~operation = "OPEN_ACCOUNT" then return self~openAccount(command)
    when command~operation = "ADD_BENEFICIARY" then return self~manageBeneficiary(command)
    when command~operation = "AMEND_BENEFICIARY" then return self~manageBeneficiary(command)
    when command~operation = "SUSPEND_BENEFICIARY" then return self~manageBeneficiary(command)
    otherwise return .FederationBankResult~failure("ACCOUNT_AUTHORITY_OPERATION_UNSUPPORTED", command~operation)
  end

::class FederationBankEngine public
::method init
  expose customers ledger profiles policyGate legalGate bouncer usage receipts openingPolicyGate externalChecks accountAuthority
  use arg customersArg, ledgerArg, profilesArg, policyGateArg, legalGateArg, bouncerArg, usageArg = .nil, openingPolicyGateArg = .nil, externalChecksArg = .nil, beneficiariesArg = .nil, beneficiaryPolicyGateArg = .nil
  customers = customersArg
  ledger = ledgerArg
  profiles = profilesArg
  policyGate = policyGateArg
  legalGate = legalGateArg
  bouncer = bouncerArg
  if usageArg == .nil then usage = .FederationBankUsageTracker~new
  else usage = usageArg
  openingPolicyGate = openingPolicyGateArg
  externalChecks = externalChecksArg
  receipts = .directory~new
  accountAuthority = .FederationBankAccountAuthority~new(customers, ledger, profiles, legalGate, bouncer, openingPolicyGate, externalChecks, beneficiariesArg, beneficiaryPolicyGateArg)
::method customers
  expose customers
  return customers
::method ledger
  expose ledger
  return ledger
::method profiles
  expose profiles
  return profiles
::method lookupReceipt
  expose receipts ledger
  use arg idempotencyKey
  key = idempotencyKey~string
  if receipts~hasIndex(key) then return .FederationBankResult~success(receipts[key])
  if ledger~store <> .nil then do
    recovered = ledger~store~recoverReceipt(key)
    if recovered~ok = .false then return recovered
    if recovered~value <> .nil then do
      receipts[key] = recovered~value
      return .FederationBankResult~success(receipts[key])
    end
  end
  return .FederationBankResult~success(.nil)
::method receipt
  use arg idempotencyKey
  found = self~lookupReceipt(idempotencyKey)
  if found~ok = .false then return .nil
  return found~value
::method copyDirectory private
  use arg original
  copy = .directory~new
  if original == .nil then return copy
  do key over original
    copy[key] = original[key]
  end
  return copy
::method replayReceipt private
  expose bouncer
  use arg command, receipt
  security = bouncer~evaluateReplay(command)
  if security~ok = .false then return security
  assessment = security~value
  d = self~copyDirectory(receipt)
  d["replayRecovered"] = "true"
  d["replaySecurityDisposition"] = assessment~disposition
  d["replaySecurityPolicyId"] = assessment~policy~policyId
  d["replaySecurityPolicyVersion"] = assessment~policy~version
  d["replaySecurityTraceIdentity"] = assessment~trace~traceIdentity
  return .FederationBankResult~new(.true, "REPLAY_RECOVERED", "Committed banking operation was not re-executed", d)
::method accountAuthority
  expose accountAuthority
  return accountAuthority
::method openAccount
  expose accountAuthority
  use arg command
  return accountAuthority~openAccount(command)
::method manageBeneficiary
  expose accountAuthority
  use arg command
  return accountAuthority~manageBeneficiary(command)
::method transfer
  expose customers ledger profiles policyGate legalGate bouncer usage receipts
  use arg command
  if command~operation <> "TRANSFER" then return .FederationBankResult~failure("OPERATION_INVALID", command~operation)
  if command~idempotencyKey = "" then return .FederationBankResult~failure("IDEMPOTENCY_KEY_REQUIRED")
  customer = customers~customer(command~customerId)
  if customer == .nil then return .FederationBankResult~failure("CUSTOMER_NOT_FOUND", command~customerId)
  source = ledger~account(command~sourceAccountId)
  target = ledger~account(command~targetAccountId)
  security = bouncer~evaluate(command, source, target, .false)
  if security~ok = .false then return security
  assessment = security~value
  select
    when assessment~disposition = .SecurityConstant~DISP_REJECT then return .FederationBankResult~failure("SECURITY_REJECTED", assessment~trace~traceIdentity, assessment)
    when assessment~disposition = .SecurityConstant~DISP_HOLD then return .FederationBankResult~failure("SECURITY_HELD", assessment~trace~traceIdentity, assessment)
    when assessment~disposition = .SecurityConstant~DISP_REVIEW then return .FederationBankResult~failure("SECURITY_REVIEW_REQUIRED", assessment~trace~traceIdentity, assessment)
    otherwise nop
  end
  if source == .nil | target == .nil then return .FederationBankResult~failure("ACCOUNT_NOT_FOUND")
  profile = profiles~byCurrency(source~currency)
  if profile == .nil then return .FederationBankResult~failure("REGULATORY_PROFILE_NOT_FOUND", source~currency)
  if source~regulatoryProfileId <> profile~profileId then return .FederationBankResult~failure("REGULATORY_PROFILE_MISMATCH", source~regulatoryProfileId || " != " || profile~profileId)
  dailyBefore = usage~usedMinor(customer~customerId, command~currency, command~requestedAt)
  policy = policyGate~evaluate(command, customer, dailyBefore)
  if policy~ok = .false then return policy
  if policy~value["allowed"] = .false then return .FederationBankResult~failure("CORPORATE_POLICY_DENIED", policy~value["reason"] || ":" || policy~value["ruleId"], policy~value)
  legal = legalGate~evaluate(command, customer, source, profile)
  if legal~ok = .false then return legal

  receipt = .directory~new
  receipt["outcome"] = "ACCEPTED"
  receipt["operation"] = command~operation
  receipt["commandId"] = command~commandId
  receipt["idempotencyKey"] = command~idempotencyKey
  receipt["transactionId"] = command~idempotencyKey
  receipt["customerId"] = customer~customerId
  receipt["currency"] = command~currency
  receipt["amountMinor"] = command~amountMinor
  receipt["regulatoryProfileId"] = profile~profileId
  receipt["securityPolicyId"] = assessment~policy~policyId
  receipt["securityPolicyVersion"] = assessment~policy~version
  receipt["securityDisposition"] = assessment~disposition
  receipt["securityTraceIdentity"] = assessment~trace~traceIdentity
  receipt["corporatePolicyId"] = policy~value["policyId"]
  receipt["corporatePolicyVersion"] = policy~value["policyVersion"]
  receipt["corporatePolicyRuleId"] = policy~value["ruleId"]
  receipt["legalProfileId"] = legal~value["legalProfileId"]
  receipt["legalGenerationId"] = legal~value["generationId"]
  receipt["legalGenerationVersion"] = legal~value["generationVersion"]
  receipt["legalStatus"] = legal~value["status"]
  receipt["createdAt"] = command~requestedAt~utcIsoDate

  commitEvidence = .directory~new
  commitEvidence["regulatoryProfileId"] = profile~profileId
  commitEvidence["securityPolicyId"] = assessment~policy~policyId
  commitEvidence["securityPolicyVersion"] = assessment~policy~version
  commitEvidence["securityDisposition"] = assessment~disposition
  commitEvidence["corporatePolicyId"] = policy~value["policyId"]
  commitEvidence["corporatePolicyVersion"] = policy~value["policyVersion"]
  commitEvidence["corporatePolicyRuleId"] = policy~value["ruleId"]
  commitEvidence["legalProfileId"] = legal~value["legalProfileId"]
  commitEvidence["legalGenerationId"] = legal~value["generationId"]
  commitEvidence["legalGenerationVersion"] = legal~value["generationVersion"]
  posting = ledger~postTransfer(command~idempotencyKey, source~accountId, target~accountId, command~amountMinor, command~currency, command~requestedAt, commitEvidence, receipt)
  if posting~ok = .false then return posting

  dailyAfter = usage~record(customer~customerId, command~currency, command~amountMinor, command~requestedAt)
  if posting~value~hasIndex("databaseTransactionId") then do
    receipt["databaseTransactionId"] = posting~value["databaseTransactionId"]
    receipt["databaseOutcome"] = posting~value["databaseOutcome"]
    receipt["databaseAttempts"] = posting~value["databaseAttempts"]
  end
  receipt["dailyUsageAfterMinor"] = dailyAfter
  receipt["sourceBalanceMinor"] = ledger~balanceMinor(source~accountId)
  receipt["targetBalanceMinor"] = ledger~balanceMinor(target~accountId)
  receipts[command~idempotencyKey] = receipt
  return .FederationBankResult~success(receipt)
::method handle
  use arg command
  if command == .nil then return .FederationBankResult~failure("COMMAND_REQUIRED")
  if command~idempotencyKey <> "" then do
    lookup = self~lookupReceipt(command~idempotencyKey)
    if lookup~ok = .false then return .FederationBankResult~failure("IDEMPOTENCY_LOOKUP_FAILED", lookup~code || ":" || lookup~detail, lookup)
    existing = lookup~value
    if existing <> .nil then return self~replayReceipt(command, existing)
  end
  select
    when command~operation = "OPEN_ACCOUNT" then return self~openAccount(command)
    when command~operation = "ADD_BENEFICIARY" then return self~manageBeneficiary(command)
    when command~operation = "AMEND_BENEFICIARY" then return self~manageBeneficiary(command)
    when command~operation = "SUSPEND_BENEFICIARY" then return self~manageBeneficiary(command)
    when command~operation = "TRANSFER" then return self~transfer(command)
    otherwise return .FederationBankResult~failure("OPERATION_UNSUPPORTED", command~operation)
  end

::requires "SecurityEffect.cls"
::requires "LegalEffect.cls"
::requires "InstitutionalPolicy.cls"

::requires "database_core.cls"
::requires "CivicClient.cls"
::requires "CivicPostcode.cls"
::requires "JMSQueueBridge.cls"
::requires "ObjectQueueFabric.cls"
