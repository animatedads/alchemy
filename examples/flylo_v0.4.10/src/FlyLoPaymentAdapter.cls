/* FlyLo payment boundary.
   The application receives only opaque payment-method tokens. Raw PAN/CVV
   data belongs to a PCI-capable payment provider, never this process.

   Authorisation and capture are deliberately separate.  A booking may require
   an authorisation before inventory commitment, but native accounting posting
   requires explicit capture/settlement evidence. */

::class FlyLoPaymentAdapter public
::method authorize
  use arg paymentIntent
  raise syntax 88.900 array("FLYLO_PAYMENT_NOT_IMPLEMENTED")
::method capture
  use arg captureIntent
  raise syntax 88.900 array("FLYLO_PAYMENT_CAPTURE_NOT_IMPLEMENTED")

::class FlyLoPaymentIntent public
::attribute intentId get
::attribute paymentMethodToken get
::attribute amountMinor get
::attribute currency get
::attribute idempotencyKey get
::method init
  expose intentId paymentMethodToken amountMinor currency idempotencyKey
  use arg intentIdArg, paymentMethodTokenArg, amountMinorArg, currencyArg = "GBP", idempotencyKeyArg = ""
  intentId = intentIdArg~string
  paymentMethodToken = paymentMethodTokenArg~string
  amountMinor = amountMinorArg
  currency = currencyArg~string~translate
  idempotencyKey = idempotencyKeyArg~string
  if intentId = "" | paymentMethodToken = "" | idempotencyKey = "" then raise syntax 88.900 array("FLYLO_PAYMENT_INTENT_INCOMPLETE")
  if \datatype(amountMinor,"W") | amountMinor < 0 then raise syntax 88.900 array("FLYLO_PAYMENT_AMOUNT_INVALID", amountMinor)

::class FlyLoPaymentCaptureIntent public
::attribute captureIntentId get
::attribute authorizationId get
::attribute amountMinor get
::attribute currency get
::attribute idempotencyKey get
::method init
  expose captureIntentId authorizationId amountMinor currency idempotencyKey
  use arg captureIntentIdArg, authorizationIdArg, amountMinorArg, currencyArg="GBP", idempotencyKeyArg=""
  captureIntentId=captureIntentIdArg~string
  authorizationId=authorizationIdArg~string
  amountMinor=amountMinorArg
  currency=currencyArg~string~translate
  idempotencyKey=idempotencyKeyArg~string
  if captureIntentId="" | authorizationId="" | idempotencyKey="" then raise syntax 88.900 array("FLYLO_PAYMENT_CAPTURE_INTENT_INCOMPLETE")
  if \datatype(amountMinor,"W") | amountMinor<0 then raise syntax 88.900 array("FLYLO_PAYMENT_CAPTURE_AMOUNT_INVALID",amountMinor)

::class FlyLoDemoPaymentAdapter subclass FlyLoPaymentAdapter public
::method init
  expose enabled authorizations captures
  use arg explicitDemoMode = .false
  if \explicitDemoMode then raise syntax 88.900 array("FLYLO_DEMO_PAYMENT_MODE_MUST_BE_EXPLICIT")
  enabled = .true
  authorizations = .table~new
  captures = .table~new

::method authorize
  expose authorizations
  use arg paymentIntent
  key = paymentIntent~idempotencyKey
  if authorizations~hasIndex(key) then return authorizations[key]
  d = .directory~new
  d["status"] = "AUTHORIZED"
  d["authorizationId"] = "DEMO-AUTH-" || paymentIntent~intentId
  d["intentId"] = paymentIntent~intentId
  d["amountMinor"] = paymentIntent~amountMinor
  d["currency"] = paymentIntent~currency
  d["source"] = "DEMO_PAYMENT"
  authorizations[key] = d
  return d

::method capture
  expose authorizations captures
  use arg captureIntent
  key=captureIntent~idempotencyKey
  if captures~hasIndex(key) then return captures[key]
  auth=.nil
  do authKey over authorizations
    candidate=authorizations[authKey]
    if candidate["authorizationId"]~string=captureIntent~authorizationId then do; auth=candidate; leave; end
  end
  if auth==.nil then raise syntax 88.900 array("FLYLO_PAYMENT_AUTHORIZATION_NOT_FOUND",captureIntent~authorizationId)
  if auth["status"]<>"AUTHORIZED" then raise syntax 88.900 array("FLYLO_PAYMENT_AUTHORIZATION_NOT_CAPTURABLE",auth["status"])
  if auth["amountMinor"]+0<>captureIntent~amountMinor+0 then raise syntax 88.900 array("FLYLO_PAYMENT_CAPTURE_AMOUNT_MISMATCH")
  if auth["currency"]~string~upper<>captureIntent~currency~string~upper then raise syntax 88.900 array("FLYLO_PAYMENT_CAPTURE_CURRENCY_MISMATCH")
  d=.directory~new
  d["status"]="CAPTURED"
  d["captureId"]="DEMO-CAP-" || captureIntent~captureIntentId
  d["authorizationId"]=captureIntent~authorizationId
  d["amountMinor"]=captureIntent~amountMinor
  d["currency"]=captureIntent~currency
  d["source"]="DEMO_PAYMENT_CAPTURE"
  d["capturedAt"]=.DateTime~new~utcIsoDate
  d["idempotencyKey"]=key
  captures[key]=d
  return d
