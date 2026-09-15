/* FederationBankIJCIB.cls
   FederationBank-side contract adapter for the sealed IJCIB credit-reference
   bureau.  This file contains no bureau policy and no broker credentials.
   IJCIB supplies evidence; FederationBank Institutional Policy decides what
   the evidence means for a banking product.
*/

::class FederationBankCreditIntelligenceRequest public
::constant PROTOCOL_VERSION "IJCIB-CIR/0.1"
::constant REQUESTING_INSTITUTION "FEDERATIONBANK-IOM-OFFSHORE"
::attribute requestId get
::attribute correlationToken get
::attribute requestDigest get
::attribute nonce get
::attribute requestedAtText get
::attribute customerReference get
::attribute subjectLegalName get
::attribute subjectDateOfBirth get
::attribute subjectAddressReference get
::attribute requestedProductCode get
::attribute requestedCurrency get
::attribute purposeCode get
::attribute supplementaryFeedRefs get
::method init
  expose requestId correlationToken requestDigest nonce requestedAtText customerReference subjectLegalName subjectDateOfBirth subjectAddressReference requestedProductCode requestedCurrency purposeCode supplementaryFeedRefs
  use arg requestIdArg, correlationTokenArg, nonceArg, requestedAtTextArg, customerReferenceArg, legalNameArg, dobArg, addressReferenceArg, productCodeArg, currencyArg, purposeArg = "ACCOUNT_OPENING", supplementaryArg = .nil
  requestId = requestIdArg~string
  correlationToken = correlationTokenArg~string
  nonce = nonceArg~string~lower
  requestedAtText = requestedAtTextArg~string
  customerReference = customerReferenceArg~string
  subjectLegalName = legalNameArg~string
  subjectDateOfBirth = dobArg~string
  subjectAddressReference = addressReferenceArg~string
  requestedProductCode = productCodeArg~string
  requestedCurrency = currencyArg~string~upper
  purposeCode = purposeArg~string~upper
  if supplementaryArg == .nil then supplementaryFeedRefs = .array~new
  else supplementaryFeedRefs = supplementaryArg
  requestDigest = .SHA512~new(self~canonicalBody)~digest
::method supplementaryText private
  expose supplementaryFeedRefs
  text = ""
  first = .true
  do ref over supplementaryFeedRefs
    if first then first = .false
    else text ||= ","
    text ||= ref~string
  end
  return text
::method canonicalBody
  expose requestId correlationToken nonce requestedAtText customerReference subjectLegalName subjectDateOfBirth subjectAddressReference requestedProductCode requestedCurrency purposeCode
  return self~PROTOCOL_VERSION || "|" || requestId || "|" || correlationToken || "|" || self~requestDigestPlaceholder || "|" || nonce || "|" || requestedAtText || "|" || self~REQUESTING_INSTITUTION || "|" || customerReference || "|" || subjectLegalName || "|" || subjectDateOfBirth || "|" || subjectAddressReference || "|" || requestedProductCode || "|" || requestedCurrency || "|" || purposeCode || "|" || self~supplementaryText
::method requestDigestPlaceholder private
  /* The contract describes the digest field among the ordered request fields,
     which cannot recursively contain its own digest.  IJCIB's JMS contract
     requires the property to be present "in spirit".  FederationBank uses an
     empty digest slot in the canonical input, then places the resulting
     SHA-512 in IJCIB_REQUEST_DIGEST. */
  return ""
::method properties
  expose requestId correlationToken requestDigest nonce requestedAtText customerReference subjectLegalName subjectDateOfBirth subjectAddressReference requestedProductCode requestedCurrency purposeCode
  p = .directory~new
  p["IJCIB_PROTOCOL_VERSION"] = self~PROTOCOL_VERSION
  p["IJCIB_REQUEST_ID"] = requestId
  p["IJCIB_CORRELATION_TOKEN"] = correlationToken
  p["IJCIB_REQUEST_DIGEST"] = requestDigest
  p["IJCIB_NONCE"] = nonce
  p["IJCIB_REQUESTED_AT"] = requestedAtText
  p["IJCIB_REQUESTING_INSTITUTION"] = self~REQUESTING_INSTITUTION
  p["IJCIB_CUSTOMER_REFERENCE"] = customerReference
  p["IJCIB_SUBJECT_LEGAL_NAME"] = subjectLegalName
  p["IJCIB_SUBJECT_DATE_OF_BIRTH"] = subjectDateOfBirth
  p["IJCIB_SUBJECT_ADDRESS_REFERENCE"] = subjectAddressReference
  p["IJCIB_REQUESTED_PRODUCT_CODE"] = requestedProductCode
  p["IJCIB_REQUESTED_CURRENCY"] = requestedCurrency
  p["IJCIB_PURPOSE_CODE"] = purposeCode
  return p
::method asMapBody
  expose requestId correlationToken requestDigest nonce requestedAtText customerReference subjectLegalName subjectDateOfBirth subjectAddressReference requestedProductCode requestedCurrency purposeCode
  d = .directory~new
  d["protocolVersion"] = self~PROTOCOL_VERSION
  d["requestId"] = requestId
  d["correlationToken"] = correlationToken
  d["requestDigest"] = requestDigest
  d["nonce"] = nonce
  d["requestedAt"] = requestedAtText
  d["requestingInstitution"] = self~REQUESTING_INSTITUTION
  d["customerReference"] = customerReference
  d["subjectLegalName"] = subjectLegalName
  d["subjectDateOfBirth"] = subjectDateOfBirth
  d["subjectAddressReference"] = subjectAddressReference
  d["requestedProductCode"] = requestedProductCode
  d["requestedCurrency"] = requestedCurrency
  d["purposeCode"] = purposeCode
  d["supplementaryFeedRefs"] = self~supplementaryText
  return d

::class FederationBankCreditIntelligenceProduct public
::constant PROTOCOL_VERSION "IJCIB-CIP/0.1"
::attribute protocolVersion get
::attribute requestId get
::attribute correlationToken get
::attribute bureauProductId get
::attribute bureauReference get
::attribute generationTimestamp get
::attribute methodologyVersion get
::attribute overallDisposition get
::attribute scaledValue get
::attribute scaleMinimum get
::attribute scaleMaximum get
::attribute scaleDirection get
::attribute normalisationMethod get
::attribute scoreBandLabel get
::attribute confidenceInterval get
::attribute suppressionFlags get
::attribute reasonCodeTree get
::attribute sourceCitationBlock get
::attribute adverseIndicatorSummary get
::attribute disclaimerBlock get
::attribute nextPermittedRefreshNotBefore get
::attribute rawBody get
::attribute rawProperties get
::method init
  expose protocolVersion requestId correlationToken bureauProductId bureauReference generationTimestamp methodologyVersion overallDisposition scaledValue scaleMinimum scaleMaximum scaleDirection normalisationMethod scoreBandLabel confidenceInterval suppressionFlags reasonCodeTree sourceCitationBlock adverseIndicatorSummary disclaimerBlock nextPermittedRefreshNotBefore rawBody rawProperties
  use arg protocolArg = "IJCIB-CIP/0.1", requestIdArg = "", correlationArg = "", productIdArg = "", bureauRefArg = "", generatedArg = "", methodologyArg = "", dispositionArg = "", scaledArg = .nil, minArg = 0, maxArg = 999, directionArg = "", normArg = "", bandArg = "", confidenceArg = .nil, suppressionArg = .nil, reasonsArg = .nil, sourceArg = .nil, adverseArg = .nil, disclaimerArg = .nil, nextRefreshArg = "", rawBodyArg = .nil, rawPropertiesArg = .nil
  protocolVersion = protocolArg~string
  requestId = requestIdArg~string
  correlationToken = correlationArg~string
  bureauProductId = productIdArg~string
  bureauReference = bureauRefArg~string
  generationTimestamp = generatedArg~string
  methodologyVersion = methodologyArg~string
  overallDisposition = dispositionArg~string~upper
  if scaledArg == .nil | scaledArg~string = "" then scaledValue = .nil
  else scaledValue = scaledArg + 0
  scaleMinimum = minArg
  scaleMaximum = maxArg
  scaleDirection = directionArg~string~upper
  normalisationMethod = normArg~string
  scoreBandLabel = bandArg~string
  if confidenceArg == .nil then confidenceInterval = .directory~new
  else confidenceInterval = confidenceArg
  if suppressionArg == .nil then suppressionFlags = .array~new
  else suppressionFlags = suppressionArg
  if reasonsArg == .nil then reasonCodeTree = .array~new
  else reasonCodeTree = reasonsArg
  if sourceArg == .nil then sourceCitationBlock = .directory~new
  else sourceCitationBlock = sourceArg
  if adverseArg == .nil then adverseIndicatorSummary = .directory~new
  else adverseIndicatorSummary = adverseArg
  if disclaimerArg == .nil then disclaimerBlock = .array~new
  else disclaimerBlock = disclaimerArg
  nextPermittedRefreshNotBefore = nextRefreshArg~string
  if rawBodyArg == .nil then rawBody = .directory~new
  else rawBody = rawBodyArg
  if rawPropertiesArg == .nil then rawProperties = .directory~new
  else rawProperties = rawPropertiesArg
::method hasScaledValue
  expose scaledValue
  return scaledValue <> .nil
/* Compatibility accessors let the existing receipt schema carry a concise
   bureau summary while the full product is persisted separately. */
::method status
  expose overallDisposition
  return overallDisposition
::method score
  expose scaledValue
  if scaledValue == .nil then return ""
  return scaledValue
::method scoreBand
  expose scoreBandLabel
  return scoreBandLabel
::method reasonCodes
  expose reasonCodeTree
  return reasonCodeTree
::method asDirectory
  expose protocolVersion requestId correlationToken bureauProductId bureauReference generationTimestamp methodologyVersion overallDisposition scaledValue scaleMinimum scaleMaximum scaleDirection normalisationMethod scoreBandLabel confidenceInterval suppressionFlags reasonCodeTree sourceCitationBlock adverseIndicatorSummary disclaimerBlock nextPermittedRefreshNotBefore rawBody rawProperties
  d = .directory~new
  d["schema"] = "federationbank.ijcib.credit-intelligence-product/0.3"
  d["protocolVersion"] = protocolVersion
  d["requestId"] = requestId
  d["correlationToken"] = correlationToken
  d["bureauProductId"] = bureauProductId
  d["bureauReference"] = bureauReference
  d["generationTimestamp"] = generationTimestamp
  d["methodologyVersion"] = methodologyVersion
  d["overallDisposition"] = overallDisposition
  if scaledValue == .nil then d["scaledValue"] = ""
  else d["scaledValue"] = scaledValue
  d["scaleMinimum"] = scaleMinimum
  d["scaleMaximum"] = scaleMaximum
  d["scaleDirection"] = scaleDirection
  d["normalisationMethod"] = normalisationMethod
  d["scoreBandLabel"] = scoreBandLabel
  d["confidenceInterval"] = confidenceInterval
  d["suppressionFlags"] = suppressionFlags
  d["reasonCodeTree"] = reasonCodeTree
  d["sourceCitationBlock"] = sourceCitationBlock
  d["adverseIndicatorSummary"] = adverseIndicatorSummary
  d["disclaimerBlock"] = disclaimerBlock
  d["nextPermittedRefreshNotBefore"] = nextPermittedRefreshNotBefore
  d["rawBody"] = rawBody
  d["rawProperties"] = rawProperties
  return d

::class FederationBankIJCIBJmsCodec public
::method requestMessage
  use arg request
  if request == .nil then return .FederationBankResult~failure("IJCIB_REQUEST_REQUIRED")
  headers = .directory~new
  headers["schema"] = "IJCIB.CreditIntelligenceRequest/0.1"
  headers["JMSCORRELATIONID"] = request~correlationToken
  msg = .JMSBridgeMessage~new(request~requestId, "MAP", request~asMapBody, headers, request~properties, "IJCIB", "FEDERATIONBANK", request~requestedAtText)
  return .FederationBankResult~success(msg)
::method splitPipe private
  use arg text
  a = .array~new
  value = text~string
  if value = "" then return a
  do while value <> ""
    parse var value one "|" value
    if one <> "" then a~append(one)
  end
  return a
::method value private
  use arg body, properties, bodyKey, propertyKey = "", defaultValue = ""
  if body <> .nil then if body~hasMethod("HASINDEX") then if body~hasIndex(bodyKey) then return body[bodyKey]
  if propertyKey <> "" then if properties <> .nil then if properties~hasMethod("HASINDEX") then if properties~hasIndex(propertyKey) then return properties[propertyKey]
  return defaultValue
::method productFromMessage
  use arg message
  if message == .nil | \message~isA(.JMSBridgeMessage) then return .FederationBankResult~failure("IJCIB_REPLY_MESSAGE_INVALID")
  body = message~body
  properties = message~properties
  if body == .nil | \body~hasMethod("HASINDEX") then body = .directory~new
  protocol = self~value(body,properties,"protocolVersion","IJCIB_PROTOCOL_VERSION","IJCIB-CIP/0.1")
  requestId = self~value(body,properties,"requestId","IJCIB_REQUEST_ID","")
  correlation = self~value(body,properties,"correlationToken","IJCIB_CORRELATION_TOKEN","")
  if correlation = "" then correlation = self~value(message~headers,properties,"JMSCORRELATIONID","","")
  productId = self~value(body,properties,"bureauProductId","IJCIB_BUREAU_PRODUCT_ID","")
  bureauRef = self~value(body,properties,"bureauReference","IJCIB_BUREAU_REFERENCE","")
  generated = self~value(body,properties,"generationTimestamp","IJCIB_GENERATED_AT","")
  methodology = self~value(body,properties,"methodologyVersion","IJCIB_METHODOLOGY","")
  disposition = self~value(body,properties,"overallDisposition","IJCIB_OVERALL_DISPOSITION","")
  scaled = self~value(body,properties,"scaledValue","IJCIB_SCORE_SCALED_VALUE","")
  minv = self~value(body,properties,"scaleMinimum","IJCIB_SCORE_SCALE_MIN",0)
  maxv = self~value(body,properties,"scaleMaximum","IJCIB_SCORE_SCALE_MAX",999)
  direction = self~value(body,properties,"scaleDirection","IJCIB_SCORE_SCALE_DIRECTION","")
  norm = self~value(body,properties,"normalisationMethod","IJCIB_SCORE_NORM_METHOD","")
  band = self~value(body,properties,"scoreBandLabel","IJCIB_SCORE_BAND","")
  suppressText = self~value(body,properties,"suppressionFlags","IJCIB_SUPPRESSION_FLAGS","")
  reasonText = self~value(body,properties,"reasonCodeTree","IJCIB_REASON_CODE_TREE","")
  nextRefresh = self~value(body,properties,"nextPermittedRefreshNotBefore","IJCIB_NEXT_REFRESH","")
  confidence = .directory~new
  if body~hasIndex("confidenceInterval") then confidence = body["confidenceInterval"]
  sources = .directory~new
  if body~hasIndex("sourceCitationBlock") then sources = body["sourceCitationBlock"]
  adverse = .directory~new
  if body~hasIndex("adverseIndicatorSummary") then adverse = body["adverseIndicatorSummary"]
  disclaimers = .array~new
  if body~hasIndex("disclaimerBlock") then disclaimers = body["disclaimerBlock"]
  product = .FederationBankCreditIntelligenceProduct~new(protocol, requestId, correlation, productId, bureauRef, generated, methodology, disposition, scaled, minv, maxv, direction, norm, band, confidence, self~splitPipe(suppressText), self~splitPipe(reasonText), sources, adverse, disclaimers, nextRefresh, body, properties)
  return .FederationBankResult~success(product)

::class FederationBankIJCIBCreditAgencyPort public
::attribute codec get
::method init
  expose codec
  codec = .FederationBankIJCIBJmsCodec~new
::method isoUtcWithOffset private
  use arg atTime
  text = atTime~utcIsoDate
  if text~right(1) = "Z" then text = text~left(text~length - 1) || "+00:00"
  return text
::method safeId private
  use arg text
  value = text~string
  value = value~changestr(" ", "-")~changestr(":", "-")~changestr("/", "-")
  if value~length > 54 then value = value~left(54)
  if value~length < 12 then value ||= "-FEDERATION"
  return value
::method buildRequest
  use arg command, addressEvidence, requirements
  if command == .nil then return .FederationBankResult~failure("IJCIB_COMMAND_REQUIRED")
  if addressEvidence == .nil | \addressEvidence~hasIndex("reference") then return .FederationBankResult~failure("IJCIB_CIVICPORT_ADDRESS_REFERENCE_REQUIRED")
  if requirements == .nil | \requirements~hasIndex("creditProductCode") then return .FederationBankResult~failure("IJCIB_PRODUCT_POLICY_MAPPING_REQUIRED")
  productCode = requirements["creditProductCode"]~string
  if productCode = "" then return .FederationBankResult~failure("IJCIB_PRODUCT_POLICY_MAPPING_REQUIRED")
  requestId = self~safeId(command~commandId || "-IJCIB")
  correlation = self~safeId("FB-CORR-" || command~commandId)
  if correlation = requestId then correlation ||= "-C"
  atText = self~isoUtcWithOffset(command~requestedAt)
  seed = requestId || "|" || correlation || "|" || atText || "|" || command~customerId || "|" || random(0,999999999) || "|" || random(0,999999999)
  nonce = .SHA512~new(seed)~digest~left(24)
  request = .FederationBankCreditIntelligenceRequest~new(requestId, correlation, nonce, atText, command~customerId, command~legalName, command~dateOfBirth, addressEvidence["reference"], productCode, command~currency, "ACCOUNT_OPENING", .array~new)
  return .FederationBankResult~success(request)
::method requestFor
  use arg command, addressEvidence, requirements
  built = self~buildRequest(command, addressEvidence, requirements)
  if \built~ok then return built
  return self~requestIntelligence(built~value)
::method requestIntelligence
  use arg request
  return .FederationBankResult~failure("IJCIB_JMS_NOT_CONFIGURED")

::requires "FederationBankEngine.cls"
::requires "crypto.cls"
