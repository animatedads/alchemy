::class FederationBankFixtureSqlExecutor public subclass DatabaseCommandExecutor
::method init
  expose commands failNextFlag receipts postingRows beneficiaryRows holdRows
  commands = .array~new
  failNextFlag = .false
  receipts = .directory~new
  postingRows = .array~new
  beneficiaryRows = .directory~new
  holdRows = .directory~new
::method execute
  expose commands failNextFlag receipts postingRows beneficiaryRows holdRows
  use arg command
  commands~append(command)
  sql = command~stdinText
  if sql~pos("EXECUTE fb_receipt_select('") > 0 then do
    prefix = "EXECUTE fb_receipt_select('"
    at = sql~pos(prefix)
    rest = sql~substr(at + prefix~length)
    finish = rest~pos("');")
    if finish > 0 then key = rest~left(finish - 1)
    else key = ""
    return self~receiptQueryResult(command, key)
  end
  if sql~pos("EXECUTE fb_postings_recover") > 0 then return self~postingQueryResult(command)
  if sql~pos("EXECUTE fb_beneficiaries_recover") > 0 then return self~beneficiaryQueryResult(command)
  if sql~pos("EXECUTE fb_holds_recover") > 0 then return self~holdQueryResult(command)
  if failNextFlag then do
    failNextFlag = .false
    return .DatabaseCommandResult~new(1, "", "ERROR: synthetic FederationBank database write failure", command, "TEST")
  end
  return .DatabaseCommandResult~new(0, "", "", command, "TEST")
::method postingQueryResult private
  expose postingRows
  use arg command
  columns = "posting_id" || "09"x || "transaction_id" || "09"x || "account_id" || "09"x || "currency" || "09"x || "amount_minor" || "09"x || "posted_at" || "09"x || "side" || "09"x || "posting_role"
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || columns || .endOfLine
  do r over postingRows
    stdout ||= r["postingId"] || "09"x || r["transactionId"] || "09"x || r["accountId"] || "09"x || r["currency"] || "09"x || r["amountMinor"] || "09"x || r["postedAt"] || "09"x || r["side"] || "09"x || r["postingRole"] || .endOfLine
  end
  stdout ||= "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "TEST")
::method rememberTransfer
  use arg debitPosting, creditPosting
  return self~rememberPostings(.array~of(debitPosting, creditPosting))
::method rememberPostings
  expose postingRows
  use arg postingSet
  do posting over postingSet
    r = .directory~new
    r["postingId"] = posting~postingId
    r["transactionId"] = posting~transactionId
    r["accountId"] = posting~accountId
    r["currency"] = posting~currency
    r["amountMinor"] = posting~amountMinor~string
    r["postedAt"] = posting~postedAt~utcIsoDate
    r["side"] = posting~side
    r["postingRole"] = posting~postingRole
    postingRows~append(r)
  end
  return self
::method beneficiaryQueryResult private
  expose beneficiaryRows
  use arg command
  columns = "customer_id" || "09"x || "beneficiary_id" || "09"x || "owner_account_id" || "09"x || "display_name" || "09"x || "account_reference" || "09"x || "bank_code" || "09"x || "country" || "09"x || "currency" || "09"x || "status" || "09"x || "version" || "09"x || "updated_at"
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || columns || .endOfLine
  do key over beneficiaryRows
    r = beneficiaryRows[key]
    stdout ||= r["customerId"] || "09"x || r["beneficiaryId"] || "09"x || r["ownerAccountId"] || "09"x || r["displayName"] || "09"x || r["accountReference"] || "09"x || r["bankCode"] || "09"x || r["country"] || "09"x || r["currency"] || "09"x || r["status"] || "09"x || r["version"] || "09"x || r["updatedAt"] || .endOfLine
  end
  stdout ||= "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "TEST")
::method rememberBeneficiary
  expose beneficiaryRows
  use arg beneficiary
  r = .directory~new
  r["customerId"] = beneficiary~customerId
  r["beneficiaryId"] = beneficiary~beneficiaryId
  r["ownerAccountId"] = beneficiary~ownerAccountId
  r["displayName"] = beneficiary~displayName
  r["accountReference"] = beneficiary~accountReference
  r["bankCode"] = beneficiary~bankCode
  r["country"] = beneficiary~country
  r["currency"] = beneficiary~currency
  r["status"] = beneficiary~status
  r["version"] = beneficiary~version~string
  r["updatedAt"] = beneficiary~updatedAt~utcIsoDate
  beneficiaryRows[beneficiary~customerId || "|" || beneficiary~beneficiaryId] = r
  return self
::method holdQueryResult private
  expose holdRows
  use arg command
  columns = "hold_id" || "09"x || "account_id" || "09"x || "customer_id" || "09"x || "currency" || "09"x || "amount_minor" || "09"x || "status" || "09"x || "version" || "09"x || "placed_at" || "09"x || "released_at"
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || columns || .endOfLine
  do key over holdRows
    r = holdRows[key]
    stdout ||= r["holdId"] || "09"x || r["accountId"] || "09"x || r["customerId"] || "09"x || r["currency"] || "09"x || r["amountMinor"] || "09"x || r["status"] || "09"x || r["version"] || "09"x || r["placedAt"] || "09"x || r["releasedAt"] || .endOfLine
  end
  stdout ||= "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "TEST")
::method rememberHold
  expose holdRows
  use arg hold
  r = .directory~new
  r["holdId"] = hold~holdId
  r["accountId"] = hold~accountId
  r["customerId"] = hold~customerId
  r["currency"] = hold~currency
  r["amountMinor"] = hold~amountMinor~string
  r["status"] = hold~status
  r["version"] = hold~version~string
  r["placedAt"] = hold~placedAt~utcIsoDate
  if hold~releasedAt == .nil then r["releasedAt"] = ""
  else r["releasedAt"] = hold~releasedAt~utcIsoDate
  holdRows[hold~holdId] = r
  return self
::method receiptQueryResult private
  expose receipts
  use arg command, key
  columns = "idempotency_key" || "09"x || "command_id" || "09"x || "operation" || "09"x || "outcome_code" || "09"x || "customer_id" || "09"x || "account_id" || "09"x || "transaction_id" || "09"x || "currency" || "09"x || "amount_minor" || "09"x || "regulatory_profile_id" || "09"x || "security_policy_id" || "09"x || "security_policy_version" || "09"x || "security_disposition" || "09"x || "corporate_policy_id" || "09"x || "corporate_policy_version" || "09"x || "corporate_policy_rule_id" || "09"x || "legal_profile_id" || "09"x || "legal_generation_id" || "09"x || "legal_generation_version" || "09"x || "address_verification_reference" || "09"x || "credit_bureau_reference" || "09"x || "credit_status" || "09"x || "credit_score" || "09"x || "created_at" || "09"x || "result_payload"
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || columns || .endOfLine
  if receipts~hasIndex(key) then do
    r = receipts[key]
    line = self~rv(r,"idempotencyKey") || "09"x || self~rv(r,"commandId") || "09"x || self~rv(r,"operation") || "09"x || self~rv(r,"outcome") || "09"x || self~rv(r,"customerId") || "09"x || self~rv(r,"accountId") || "09"x || self~rv(r,"transactionId") || "09"x || self~rv(r,"currency") || "09"x || self~rv(r,"amountMinor","0") || "09"x || self~rv(r,"regulatoryProfileId") || "09"x || self~rv(r,"securityPolicyId") || "09"x || self~rv(r,"securityPolicyVersion") || "09"x || self~rv(r,"securityDisposition") || "09"x || self~rv(r,"corporatePolicyId") || "09"x || self~rv(r,"corporatePolicyVersion") || "09"x || self~rv(r,"corporatePolicyRuleId") || "09"x || self~rv(r,"legalProfileId") || "09"x || self~rv(r,"legalGenerationId") || "09"x || self~rv(r,"legalGenerationVersion") || "09"x || self~rv(r,"addressVerificationReference") || "09"x || self~rv(r,"creditBureauReference") || "09"x || self~rv(r,"creditStatus") || "09"x || self~rv(r,"creditScore","0") || "09"x || self~rv(r,"createdAt") || "09"x || self~rv(r,"_resultPayload")
    stdout ||= line || .endOfLine
  end
  stdout ||= "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "TEST")
::method rv private
  use arg r, key, defaultValue = ""
  if r~hasIndex(key) then do
    value = r[key]
    if value <> .nil then return value~string
  end
  return defaultValue
::method rememberReceipt
  expose receipts
  use arg receipt
  if receipt == .nil then return self
  copy = .directory~new
  do key over receipt
    value = receipt[key]
    if value == .nil then copy[key] = ""
    else copy[key] = value
  end
  copy["_resultPayload"] = c2x(.QueueGraphPayloadCodec~new~encode(receipt))
  receipts[receipt["idempotencyKey"]~string] = copy
  return self
::method failNext
  expose failNextFlag
  failNextFlag = .true
  return self
::method commands
  expose commands
  out = .array~new
  do c over commands
    out~append(c)
  end
  return out
::method lastCommand
  expose commands
  if commands~items = 0 then return .nil
  return commands[commands~items]

::class FederationBankFixtureCivicTransport public
::method init
  expose calls failNextFlag
  calls = 0
  failNextFlag = .false
::method execute
  expose calls failNextFlag
  use arg request
  calls += 1
  if failNextFlag then do
    failNextFlag = .false
    return .CivicTransportResponse~failure("FIXTURE_CIVIC_FAILURE", "synthetic CivicPort failure", "FEDERATIONBANK_FIXTURE")
  end
  url = request~url
  marker = "/postcodes/"
  at = url~pos(marker)
  if at > 0 then postcode = url~substr(at + marker~length)~changestr("%20", " ")
  else postcode = "UNKNOWN"
  headers = .directory~new
  headers["Content-Type"] = "application/json"
  body = '{"status":200,"result":{"postcode":"' || postcode || '","country":"United Kingdom","admin_district":"Fixture District","region":null,"longitude":-4.5,"latitude":54.2}}'
  raw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  return .CivicTransportResponse~success(200, "OK", headers, raw, body, "FEDERATIONBANK_FIXTURE")
::method failNext
  expose failNextFlag
  failNextFlag = .true
  return self
::method calls
  expose calls
  return calls

::class FederationBankFixtureCreditAgency public subclass FederationBankCreditAgencyPort
::method init
  expose calls score status failNextFlag lastRequest
  calls = 0
  score = 720
  status = "OK"
  failNextFlag = .false
  lastRequest = .nil
::method requestScore
  expose calls score status failNextFlag lastRequest
  use arg request
  calls += 1
  lastRequest = request
  if failNextFlag then do
    failNextFlag = .false
    return .FederationBankResult~failure("CREDIT_AGENCY_TIMEOUT", "synthetic credit-agency timeout")
  end
  report = .FederationBankCreditScoreReport~new(request~requestId, request~correlationId, "BUREAU-" || request~requestId, score, "FIXTURE", status, .array~new, .DateTime~new)
  return .FederationBankResult~success(report)
::method setScore
  expose score
  use arg newScore
  score = newScore + 0
  return self
::method setStatus
  expose status
  use arg newStatus
  status = newStatus~string~upper
  return self
::method failNext
  expose failNextFlag
  failNextFlag = .true
  return self
::method calls
  expose calls
  return calls
::method lastRequest
  expose lastRequest
  return lastRequest


::class FederationBankFixtureIJCIBAgency public subclass FederationBankIJCIBCreditAgencyPort
::method init
  expose calls scaledValue disposition suppressionFlags failNextFlag lastRequest
  self~init:super
  calls = 0
  scaledValue = 720
  disposition = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS"
  suppressionFlags = .array~new
  failNextFlag = .false
  lastRequest = .nil
::method requestIntelligence
  expose calls scaledValue disposition suppressionFlags failNextFlag lastRequest
  use arg request
  calls += 1
  lastRequest = request
  if failNextFlag then do
    failNextFlag = .false
    return .FederationBankResult~failure("IJCIB_TIMEOUT", "synthetic sealed-bureau timeout")
  end
  reasons = .array~of("IJCIB.QUAL.FIXTURE.OPAQUE")
  raw = .directory~new
  raw["protocolVersion"] = "IJCIB-CIP/0.1"
  raw["requestId"] = request~requestId
  raw["correlationToken"] = request~correlationToken
  raw["bureauProductId"] = "IJCIB-PRODUCT-OPAQUE-" || request~requestId
  raw["bureauReference"] = "IJCIB-REF-OPAQUE-" || request~requestId
  raw["generationTimestamp"] = request~requestedAtText
  raw["methodologyVersion"] = "IJCIB-METH-2026.3-REDACTED"
  raw["overallDisposition"] = disposition
  if scaledValue == .nil then raw["scaledValue"] = ""
  else raw["scaledValue"] = scaledValue
  raw["scaleMinimum"] = 0
  raw["scaleMaximum"] = 999
  raw["scaleDirection"] = "HIGHER_INDICATES_LOWER_OBSERVED_STRESS"
  raw["normalisationMethod"] = "IJCIB-INTERNAL-REDACTED"
  raw["scoreBandLabel"] = "IJCIB-FIXTURE-BAND"
  raw["suppressionFlags"] = suppressionFlags
  raw["reasonCodeTree"] = reasons
  raw["nextPermittedRefreshNotBefore"] = request~requestedAtText
  product = .FederationBankCreditIntelligenceProduct~new("IJCIB-CIP/0.1", request~requestId, request~correlationToken, raw["bureauProductId"], raw["bureauReference"], raw["generationTimestamp"], raw["methodologyVersion"], disposition, scaledValue, 0, 999, "HIGHER_INDICATES_LOWER_OBSERVED_STRESS", "IJCIB-INTERNAL-REDACTED", "IJCIB-FIXTURE-BAND", .directory~new, suppressionFlags, reasons, .directory~new, .directory~new, .array~of("fixture disclaimer"), request~requestedAtText, raw, .directory~new)
  return .FederationBankResult~success(product)
::method setScaledValue
  expose scaledValue
  use arg value
  if value == .nil | value~string = "" then scaledValue = .nil
  else scaledValue = value + 0
  return self
::method setDisposition
  expose disposition
  use arg value
  disposition = value~string~upper
  return self
::method suppress
  expose suppressionFlags scaledValue
  use arg flag = "IJCIB.SUPPRESSION.FIXTURE"
  suppressionFlags = .array~of(flag~string)
  scaledValue = .nil
  return self
::method clearSuppression
  expose suppressionFlags
  suppressionFlags = .array~new
  return self
::method failNext
  expose failNextFlag
  failNextFlag = .true
  return self
::method calls
  expose calls
  return calls
::method lastRequest
  expose lastRequest
  return lastRequest

/* Test/reference fixtures. Numerical limits and score thresholds are invented
   FederationBank corporate-policy fixtures, never real regulatory content. */
::class FederationBankFixtureFxQuotePort public subclass FederationBankFxQuotePort
::method quote
  use arg command, sourceAccount, targetAccount
  if command == .nil | sourceAccount == .nil | targetAccount == .nil then return .FederationBankResult~failure("FX_QUOTE_INPUT_REQUIRED")
  src = sourceAccount~currency
  dst = targetAccount~currency
  key = src || "/" || dst
  rates = .directory~new
  rates["GBP/USD"] = .array~of(125, 100)
  rates["USD/GBP"] = .array~of(80, 100)
  rates["EUR/GBP"] = .array~of(85, 100)
  rates["GBP/EUR"] = .array~of(117, 100)
  rates["AUD/USD"] = .array~of(65, 100)
  rates["USD/AUD"] = .array~of(153, 100)
  rates["EUR/USD"] = .array~of(108, 100)
  rates["USD/EUR"] = .array~of(92, 100)
  if \rates~hasIndex(key) then return .FederationBankResult~failure("FX_QUOTE_PAIR_UNAVAILABLE", key)
  r = rates[key]
  quote = .FederationBankFxQuote~new("FXQ-" || command~idempotencyKey, "FB-FX-FIXTURE", src, dst, r[1], r[2], command~requestedAt, command~requestedAt + .TimeSpan~new(0,0,0,5), "TEST FIXTURE RATE ONLY")
  return .FederationBankResult~success(quote)

::class FederationBankFixtures public
::method limitCatalog class
  p = .FederationBankLimitPolicy~new
  p~addRule(.FederationBankLimitRule~new("USD-RETAIL-WEB", "RETAIL", "USD", "TRANSFER", "WEB", 5000000, 10000000, "illustrative FederationBank corporate USD limit"))
  p~addRule(.FederationBankLimitRule~new("AUD-RETAIL-WEB", "RETAIL", "AUD", "TRANSFER", "WEB", 7500000, 15000000, "illustrative FederationBank corporate AUD limit"))
  p~addRule(.FederationBankLimitRule~new("GBP-RETAIL-WEB", "RETAIL", "GBP", "TRANSFER", "WEB", 2500000, 5000000, "illustrative FederationBank corporate GBP limit"))
  p~addRule(.FederationBankLimitRule~new("EUR-RETAIL-WEB", "RETAIL", "EUR", "TRANSFER", "WEB", 3000000, 6000000, "illustrative FederationBank corporate EUR limit"))
  do cur over .array~of("USD", "AUD", "GBP", "EUR")
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-FX-WEB", "RETAIL", cur, "FX_CONVERT", "WEB", 2500000, 5000000, "illustrative FederationBank FX source-currency limit"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-OFFLINE-AUTH", "RETAIL", cur, "ATM_OFFLINE_AUTHORITY_ISSUE", "ATM", 20000, 100000, "illustrative bank-issued offline ATM authority envelope"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-OFFLINE", "RETAIL", cur, "OFFLINE_WITHDRAWAL_ADVICE", "ATM", 20000, 100000, "illustrative delegated ATM stand-in settlement evidence rule"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-HOLD", "RETAIL", cur, "PLACE_HOLD", "ATM", 50000, 100000, "illustrative online ATM withdrawal reservation limit"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-RELEASE", "RETAIL", cur, "RELEASE_HOLD", "ATM", 0, 0, "illustrative online ATM withdrawal cancellation rule"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-WITHDRAW-COMMIT", "RETAIL", cur, "WITHDRAW_COMMIT", "ATM", 50000, 100000, "illustrative online ATM physical withdrawal commit envelope"))
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-ATM-DEPOSIT", "RETAIL", cur, "DEPOSIT_COMMIT", "ATM", 100000, 0, "illustrative ATM physical deposit acceptance envelope"))
  end
  p~addRule(.FederationBankLimitRule~new("USD-RETAIL-HOLD-WEB", "RETAIL", "USD", "PLACE_HOLD", "WEB", 5000000, 0, "illustrative FederationBank USD reservation limit"))
  p~addRule(.FederationBankLimitRule~new("AUD-RETAIL-HOLD-WEB", "RETAIL", "AUD", "PLACE_HOLD", "WEB", 7500000, 0, "illustrative FederationBank AUD reservation limit"))
  p~addRule(.FederationBankLimitRule~new("GBP-RETAIL-HOLD-WEB", "RETAIL", "GBP", "PLACE_HOLD", "WEB", 2500000, 0, "illustrative FederationBank GBP reservation limit"))
  p~addRule(.FederationBankLimitRule~new("EUR-RETAIL-HOLD-WEB", "RETAIL", "EUR", "PLACE_HOLD", "WEB", 3000000, 0, "illustrative FederationBank EUR reservation limit"))
  do cur over .array~of("USD", "AUD", "GBP", "EUR")
    p~addRule(.FederationBankLimitRule~new(cur || "-RETAIL-RELEASE-HOLD-WEB", "RETAIL", cur, "RELEASE_HOLD", "WEB", 0, 0, "illustrative FederationBank reservation release policy"))
  end
  p~seal
  release = .InstitutionalPolicyRelease~new(.FederationBankBuild~LIMIT_POLICY_DEFAULT, "1", .DateTime~new - .TimeSpan~new(0,0,0,0,1), .nil, "FederationBank Product", "FederationBank Risk", "", p)~seal
  c = .InstitutionalPolicyCatalog~new
  published = c~publish(release)
  if published~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_POLICY_PUBLISH_FAILED", published~code, published~detail)
  return c
::method fxCatalog class
  p = .FederationBankFxPolicy~new
  do src over .array~of("USD", "AUD", "GBP", "EUR")
    do dst over .array~of("USD", "AUD", "GBP", "EUR")
      if src = dst then iterate
      p~addRule(.FederationBankFxRule~new("FX-" || src || "-" || dst || "-RETAIL-WEB", "RETAIL", src, dst, "FX_CONVERT", "WEB", 2500000, 20, "illustrative FederationBank FX spread fixture"))
    end
  end
  p~seal
  release = .InstitutionalPolicyRelease~new(.FederationBankBuild~FX_POLICY_DEFAULT, "1", .DateTime~new - .TimeSpan~new(0,0,0,0,1), .nil, "FederationBank Treasury", "FederationBank Risk", "", p)~seal
  c = .InstitutionalPolicyCatalog~new
  published = c~publish(release)
  if published~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_FX_POLICY_PUBLISH_FAILED", published~code, published~detail)
  return c
::method feeCatalog class
  p = .FederationBankFeePolicy~new
  p~addRule(.FederationBankFeeRule~new("USD-RETAIL-TRANSFER-FEE-WEB", "RETAIL", "USD", "TRANSFER", "WEB", 125, 0, 0, 0, 0, "STANDARD_TRANSFER", "illustrative FederationBank USD transfer fee"))
  p~addRule(.FederationBankFeeRule~new("AUD-RETAIL-TRANSFER-FEE-WEB", "RETAIL", "AUD", "TRANSFER", "WEB", 150, 0, 0, 0, 0, "STANDARD_TRANSFER", "illustrative FederationBank AUD transfer fee"))
  p~addRule(.FederationBankFeeRule~new("GBP-RETAIL-TRANSFER-FEE-WEB", "RETAIL", "GBP", "TRANSFER", "WEB", 200, 0, 0, 0, 0, "STANDARD_TRANSFER", "illustrative FederationBank GBP transfer fee"))
  p~addRule(.FederationBankFeeRule~new("EUR-RETAIL-TRANSFER-FEE-WEB", "RETAIL", "EUR", "TRANSFER", "WEB", 175, 0, 0, 0, 0, "STANDARD_TRANSFER", "illustrative FederationBank EUR transfer fee"))
  p~seal
  release = .InstitutionalPolicyRelease~new(.FederationBankBuild~FEE_POLICY_DEFAULT, "1", .DateTime~new - .TimeSpan~new(0,0,0,0,1), .nil, "FederationBank Product", "FederationBank Risk", "", p)~seal
  c = .InstitutionalPolicyCatalog~new
  published = c~publish(release)
  if published~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_FEE_POLICY_PUBLISH_FAILED", published~code, published~detail)
  return c
::method beneficiaryCatalog class
  p = .FederationBankBeneficiaryPolicy~new
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-ADD-WEB", "RETAIL", "ADD_BENEFICIARY", "WEB", 2, "illustrative FederationBank active-beneficiary limit"))
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-AMEND-WEB", "RETAIL", "AMEND_BENEFICIARY", "WEB", 2, "illustrative FederationBank beneficiary amendment policy"))
  p~addRule(.FederationBankBeneficiaryRule~new("BEN-RETAIL-SUSPEND-WEB", "RETAIL", "SUSPEND_BENEFICIARY", "WEB", 2, "illustrative FederationBank beneficiary suspension policy"))
  p~seal
  release = .InstitutionalPolicyRelease~new(.FederationBankBuild~BENEFICIARY_POLICY_DEFAULT, "1", .DateTime~new - .TimeSpan~new(0,0,0,0,1), .nil, "FederationBank Product", "FederationBank Risk", "", p)~seal
  c = .InstitutionalPolicyCatalog~new
  published = c~publish(release)
  if published~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_BENEFICIARY_POLICY_PUBLISH_FAILED", published~code, published~detail)
  return c
::method openingCatalog class
  p = .FederationBankAccountOpeningPolicy~new
  do cur over .array~of("USD", "AUD", "GBP", "EUR")
    p~addRule(.FederationBankOpeningRule~new("OPEN-" || cur || "-OFFSHORE-CURRENT", "OFFSHORE_CURRENT", cur, "WEB", .true, .true, 650, 550, .false, "illustrative account-opening intelligence policy", "FB-IJCIB-FIXTURE-" || cur))
  end
  p~seal
  release = .InstitutionalPolicyRelease~new(.FederationBankBuild~OPENING_POLICY_DEFAULT, "1", .DateTime~new - .TimeSpan~new(0,0,0,0,1), .nil, "FederationBank Product", "FederationBank Risk", "", p)~seal
  c = .InstitutionalPolicyCatalog~new
  published = c~publish(release)
  if published~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_OPENING_POLICY_PUBLISH_FAILED", published~code, published~detail)
  return c
::method legalGeneration class
  use arg currency
  cur = currency~string~upper
  g = .LegalRuleGeneration~new("FB-LEGAL-" || cur, "1")
  source = .NormativeSource~new("FB-TEST-LEGAL-SOURCE-" || cur, "REGULATION", cur || " reference regulatory behaviour fixture", "TEST FIXTURE ONLY", "IOM", "TEST FIXTURE - replace with verified authoritative sources")
  added = g~addSource(source)
  if added~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_LEGAL_SOURCE_FAILED", added~code)
  transferNorm = .LegalNorm~new("FB-" || cur || "-TRANSFER-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", "TRANSFER", "REQUIRES_OBLIGATION", "BANKING", "route transfer through its currency-specific Legal Effect generation")
  transferNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
  transferNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
  transferNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
  g~addNorm(transferNorm)
  fxNorm = .LegalNorm~new("FB-" || cur || "-FX-CONVERT-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", "FX_CONVERT", "REQUIRES_OBLIGATION", "BANKING", "route FX conversion through each currency-specific Legal Effect generation")
  fxNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
  fxNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
  fxNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
  g~addNorm(fxNorm)
  atmNorm = .LegalNorm~new("FB-" || cur || "-ATM-OFFLINE-SETTLEMENT", source~sourceId, "FIXTURE", "OBLIGATION", "OFFLINE_WITHDRAWAL_ADVICE", "REQUIRES_OBLIGATION", "BANKING", "record physical cash already dispensed under delegated offline authority")
  atmNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
  atmNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
  atmNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
  g~addNorm(atmNorm)
  atmAuthorityNorm = .LegalNorm~new("FB-" || cur || "-ATM-OFFLINE-AUTHORITY", source~sourceId, "FIXTURE", "OBLIGATION", "ATM_OFFLINE_AUTHORITY_ISSUE", "REQUIRES_OBLIGATION", "BANKING", "issue bounded offline ATM authority before connectivity loss")
  atmAuthorityNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
  atmAuthorityNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
  atmAuthorityNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
  g~addNorm(atmAuthorityNorm)
  do atmOperation over .array~of("WITHDRAW_COMMIT", "DEPOSIT_COMMIT")
    atmOnlineNorm = .LegalNorm~new("FB-" || cur || "-ATM-" || atmOperation || "-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", atmOperation, "REQUIRES_OBLIGATION", "BANKING", "route physical ATM banking fact through currency-specific Legal Effect")
    atmOnlineNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
    atmOnlineNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
    atmOnlineNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
    g~addNorm(atmOnlineNorm)
  end
  openNorm = .LegalNorm~new("FB-" || cur || "-OPEN-ACCOUNT-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", "OPEN_ACCOUNT", "REQUIRES_OBLIGATION", "BANKING", "route account opening through its currency-specific Legal Effect generation")
  openNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
  openNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
  openNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
  g~addNorm(openNorm)
  do holdOperation over .array~of("PLACE_HOLD", "RELEASE_HOLD")
    holdNorm = .LegalNorm~new("FB-" || cur || "-" || holdOperation || "-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", holdOperation, "REQUIRES_OBLIGATION", "BANKING", "route reservation lifecycle through its currency-specific Legal Effect generation")
    holdNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
    holdNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
    holdNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
    g~addNorm(holdNorm)
  end
  do beneficiaryOperation over .array~of("ADD_BENEFICIARY", "AMEND_BENEFICIARY", "SUSPEND_BENEFICIARY")
    beneficiaryNorm = .LegalNorm~new("FB-" || cur || "-" || beneficiaryOperation || "-OBLIGATION", source~sourceId, "FIXTURE", "OBLIGATION", beneficiaryOperation, "REQUIRES_OBLIGATION", "BANKING", "route beneficiary lifecycle through its account-currency Legal Effect generation")
    beneficiaryNorm~addCondition(.LegalPredicate~new("CURRENCY", "EQUALS", cur))
    beneficiaryNorm~addCondition(.LegalPredicate~new("BOOKING_JURISDICTION", "EQUALS", "IOM"))
    beneficiaryNorm~addJurisdiction(.LegalJurisdictionClaim~new("FEDERATIONBANK", "IOM", "BANKING", "FederationBank IOM booking entity"))
    g~addNorm(beneficiaryNorm)
  end
  return g~seal
::method legalRegistry class
  r = .FederationBankLegalGenerationRegistry~new
  do cur over .array~of("USD", "AUD", "GBP", "EUR")
    result = r~register("FB-LEGAL-" || cur, self~legalGeneration(cur))
    if result~ok = .false then raise syntax 88.900 array("FEDERATIONBANK_FIXTURE_LEGAL_REGISTER_FAILED", result~code)
  end
  return r
::method database class
  use arg executor = .nil
  connection = .DatabaseConnection~new("localhost", 5432, "federationbank_test", "federationbank", .DatabaseCredential~new("none"), "postgresql")
  if executor == .nil then executor = .FederationBankFixtureSqlExecutor~new
  return .Database~new(connection, .nil, executor)
::method externalEnvironment class
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  civicTransport = .FederationBankFixtureCivicTransport~new
  client = .CivicClient~new(civicTransport, allow)
  verifier = .FederationBankCivicPortAddressVerifier~new(client)
  creditAgency = .FederationBankFixtureCreditAgency~new
  checks = .FederationBankExternalChecks~new(verifier, creditAgency)
  d = .directory~new
  d["checks"] = checks
  d["civicTransport"] = civicTransport
  d["creditAgency"] = creditAgency
  return d
::method ijcibExternalEnvironment class
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  civicTransport = .FederationBankFixtureCivicTransport~new
  client = .CivicClient~new(civicTransport, allow)
  verifier = .FederationBankCivicPortAddressVerifier~new(client)
  creditAgency = .FederationBankFixtureIJCIBAgency~new
  checks = .FederationBankExternalChecks~new(verifier, creditAgency)
  d = .directory~new
  d["checks"] = checks
  d["civicTransport"] = civicTransport
  d["creditAgency"] = creditAgency
  return d
::method freshIJCIBEnvironment class
  executor = .FederationBankFixtureSqlExecutor~new
  database = self~database(executor)
  external = self~ijcibExternalEnvironment
  engine = self~buildEngine(database, .false, external)
  d = .directory~new
  d["engine"] = engine
  d["database"] = database
  d["executor"] = executor
  d["external"] = external
  return d
::method buildAccountAuthority class
  use arg database, preloadCustomers = .false, externalEnvironment = .nil
  customers = .FederationBankCustomerRegistry~new
  if preloadCustomers then do
    customers~add(.FederationBankCustomer~new("CUST-001", "RETAIL", "GB", "GB", "STANDARD", .nil, "Existing Customer", "1980-01-01", "SW1A 1AA", "GB"))
    customers~add(.FederationBankCustomer~new("CUST-002", "RETAIL", "AU", "AU", "STANDARD", .nil, "Existing Australian Customer", "1985-01-01", "2000", "AU"))
  end
  store = .FederationBankSqlLedgerStore~new(database, 3, 15)
  accounts = .FederationBankLedger~new(store)
  profiles = .FederationBankRegulatoryProfileRegistry~standard
  openingGate = .FederationBankOpeningPolicyGate~new(self~openingCatalog)
  beneficiaryGate = .FederationBankBeneficiaryPolicyGate~new(self~beneficiaryCatalog)
  legalGate = .FederationBankLegalGate~new(self~legalRegistry)
  bouncer = .FederationBankBouncer~new(.FederationBankBouncer~standardFramework)
  beneficiaries = .FederationBankBeneficiaryRegistry~new
  if externalEnvironment == .nil then externalEnvironment = self~externalEnvironment
  return .FederationBankAccountAuthority~new(customers, accounts, profiles, legalGate, bouncer, openingGate, externalEnvironment["checks"], beneficiaries, beneficiaryGate)
::method freshAccountEnvironment class
  use arg useIJCIB = .false
  executor = .FederationBankFixtureSqlExecutor~new
  database = self~database(executor)
  if useIJCIB then external = self~ijcibExternalEnvironment
  else external = self~externalEnvironment
  authority = self~buildAccountAuthority(database, .false, external)
  d = .directory~new
  d["authority"] = authority
  d["database"] = database
  d["executor"] = executor
  d["external"] = external
  d["customers"] = authority~customers
  d["accounts"] = authority~accounts
  d["beneficiaries"] = authority~beneficiaries
  return d

::method buildEngine class
  use arg database, preloadCustomers = .true, externalEnvironment = .nil
  customers = .FederationBankCustomerRegistry~new
  if preloadCustomers then do
    customers~add(.FederationBankCustomer~new("CUST-001", "RETAIL", "GB", "GB", "STANDARD", .nil, "Existing Customer", "1980-01-01", "SW1A 1AA", "GB"))
    customers~add(.FederationBankCustomer~new("CUST-002", "RETAIL", "AU", "AU", "STANDARD", .nil, "Existing Australian Customer", "1985-01-01", "2000", "AU"))
  end
  store = .FederationBankSqlLedgerStore~new(database, 3, 15)
  ledger = .FederationBankLedger~new(store)
  profiles = .FederationBankRegulatoryProfileRegistry~standard
  do cur over .array~of("USD", "AUD", "GBP", "EUR")
    profile = profiles~byCurrency(cur)
    ledger~addAccount(.FederationBankAccount~new("FB-SETTLEMENT-" || cur, "FEDERATIONBANK", cur, "INTERNAL_SETTLEMENT", "IOM", profile~profileId, .true, .true))
  end
  policyGate = .FederationBankPolicyGate~new(self~limitCatalog)
  openingGate = .FederationBankOpeningPolicyGate~new(self~openingCatalog)
  beneficiaryGate = .FederationBankBeneficiaryPolicyGate~new(self~beneficiaryCatalog)
  legalGate = .FederationBankLegalGate~new(self~legalRegistry)
  bouncer = .FederationBankBouncer~new(.FederationBankBouncer~standardFramework)
  if externalEnvironment == .nil then externalEnvironment = self~externalEnvironment
  return .FederationBankEngine~new(customers, ledger, profiles, policyGate, legalGate, bouncer, .nil, openingGate, externalEnvironment["checks"], .FederationBankBeneficiaryRegistry~new, beneficiaryGate)
::method engine class
  return self~buildEngine(self~database, .true, self~externalEnvironment)
::method freshEnvironment class
  executor = .FederationBankFixtureSqlExecutor~new
  database = self~database(executor)
  external = self~externalEnvironment
  engine = self~buildEngine(database, .false, external)
  d = .directory~new
  d["engine"] = engine
  d["database"] = database
  d["executor"] = executor
  d["external"] = external
  return d

::requires "FederationBankIJCIB.cls"
::requires "FederationBankEngine.cls"
