/* FlyLo accounting integration over Accounting Core v0.7.
 *
 * Booking, inventory and payment providers remain operational authorities.
 * FlyLo emits normalized accounting.event/0.1 projections only after explicit
 * payment capture evidence exists. Accounting Core resolves exact effective-
 * dated FlyLo policy and posts the immutable journal through transact().
 * AUTHORISED payment alone is deliberately not an accounting event.
 */

::options digits 50

::class FlyLoAccountingBuild public
::constant VERSION "0.4"
::constant API "flylo.accounting/0.4"
::constant CORE_EVENT_API "accounting.event/0.1"
::constant CORE_TRANSACTION_API "accounting.transaction/0.1"
::constant CORE_STORE_API "accounting.store/0.1"
::constant LEGAL_ENTITY_ID "FLYLO_AIR_LTD"
::constant BOOK_ID "FLYLO-STAT"
::constant POLICY_BOOKING_CAPTURE "flylo.accounting.booking-payment-captured/0.2"
::constant POLICY_ANCILLARY_CAPTURE "flylo.accounting.ancillary-payment-captured/0.2"
::constant POLICY_IMPL_SHA256 "f2e698dd645b76589af4dff396327a9ee3a20cef1fbba246ce3ee0c44b61afd1"
::constant ACCOUNT_PROCESSOR_RECEIVABLE "1100"
::constant ACCOUNT_PASSENGER_CONTRACT_LIABILITY "2100"
::constant ACCOUNT_CARRIAGE_REVENUE "4100"
::constant ACCOUNT_ANCILLARY_REVENUE "4110"

::class FlyLoAccountingPolicy public
::method newEngine class
  use arg storePathArg=""
  storePath=storePathArg~string~strip
  recovered=.false
  if storePath="" then do
    e=.AccountingEngine~new(.FlyLoAccountingBuild~LEGAL_ENTITY_ID,.FlyLoAccountingBuild~BOOK_ID,"ENTITY_GAAP")
  end
  else do
    store=.AccountingFileStore~new(storePath)
    existing=stream(storePath,"c","query exists")
    if existing="" then do
      b=store~createBook(.FlyLoAccountingBuild~LEGAL_ENTITY_ID,.FlyLoAccountingBuild~BOOK_ID,"ENTITY_GAAP")
    end
    else do
      b=store~recoverBook
      recovered=.true
      if b~legalEntityId<>.FlyLoAccountingBuild~LEGAL_ENTITY_ID | b~bookId<>.FlyLoAccountingBuild~BOOK_ID | b~reportingBasis<>"ENTITY_GAAP" then -
        raise syntax 88.900 array("FLYLO_ACCOUNTING_RECOVERED_BOOK_IDENTITY_MISMATCH")
    end
    e=.AccountingEngine~new(b~legalEntityId,b~bookId,b~reportingBasis,b)
  end
  b=e~book
  if \recovered then do
    b~chart~add(.AccountingAccount~new(.FlyLoAccountingBuild~ACCOUNT_PROCESSOR_RECEIVABLE,"Card processor receivable","ASSET"))
    b~chart~add(.AccountingAccount~new(.FlyLoAccountingBuild~ACCOUNT_PASSENGER_CONTRACT_LIABILITY,"Passenger service contract liability","LIABILITY"))
    b~chart~add(.AccountingAccount~new(.FlyLoAccountingBuild~ACCOUNT_CARRIAGE_REVENUE,"Passenger carriage revenue","REVENUE"))
    b~chart~add(.AccountingAccount~new(.FlyLoAccountingBuild~ACCOUNT_ANCILLARY_REVENUE,"Ancillary service revenue","REVENUE"))
    b~chart~seal
  end
  else do accountId over .array~of(.FlyLoAccountingBuild~ACCOUNT_PROCESSOR_RECEIVABLE,.FlyLoAccountingBuild~ACCOUNT_PASSENGER_CONTRACT_LIABILITY,.FlyLoAccountingBuild~ACCOUNT_CARRIAGE_REVENUE,.FlyLoAccountingBuild~ACCOUNT_ANCILLARY_REVENUE)
    if \b~chart~contains(accountId) then raise syntax 88.900 array("FLYLO_ACCOUNTING_RECOVERED_CHART_INCOMPLETE",accountId)
  end
  base="sha256:" || .FlyLoAccountingBuild~POLICY_IMPL_SHA256
  e~registerPolicy(.FlyLoCapturedPaymentAccountingPolicy~new(.FlyLoAccountingBuild~POLICY_BOOKING_CAPTURE,base || "#BOOKING_PAYMENT_CAPTURED","BOOKING_PAYMENT_CAPTURED","2026-01-01"))
  e~registerPolicy(.FlyLoCapturedPaymentAccountingPolicy~new(.FlyLoAccountingBuild~POLICY_ANCILLARY_CAPTURE,base || "#ANCILLARY_PAYMENT_CAPTURED","ANCILLARY_PAYMENT_CAPTURED","2026-01-01"))
  return e

::method ensurePeriod class
  use arg engine, postingDate
  periodId=postingDate~substr(1,7)
  if engine~book~period(periodId)==.nil then do
    year=postingDate~substr(1,4)+0
    month=postingDate~substr(6,2)+0
    days=31
    if wordpos(month,"4 6 9 11")>0 then days=30
    if month=2 then do
      leap=(year//4=0 & year//100<>0) | year//400=0
      if leap then days=29; else days=28
    end
    start=right(year,4,"0") || "-" || right(month,2,"0") || "-01"
    endDate=right(year,4,"0") || "-" || right(month,2,"0") || "-" || right(days,2,"0")
    engine~book~addPeriod(.AccountingPeriod~new(periodId,start,endDate))
  end
  return periodId

::class FlyLoAccountingAuthority public
::attribute engine get
::method init
  expose topology engine
  use arg topologyArg=.nil, engineArg=.nil, storePathArg=""
  topology=topologyArg
  if engineArg==.nil then engine=.FlyLoAccountingPolicy~newEngine(storePathArg)
  else engine=engineArg
  if topology<>.nil then do
    rebuilt=self~rebuildFromRetained
    if \rebuilt~ok then raise syntax 88.900 array("FLYLO_ACCOUNTING_REBUILD_FAILED",rebuilt~errorCode,rebuilt~message)
  end

::method bookingCaptureEvent private
  use arg booking,capture
  if booking==.nil | \booking~isA(.Directory) then return .nil
  if capture==.nil | \capture~isA(.Directory) then return .nil
  payload=.directory~new
  payload["status"]=capture["status"]
  payload["bookingRef"]=booking["bookingRef"]
  payload["saleId"]=booking["saleId"]
  payload["captureId"]=capture["captureId"]
  payload["paymentAuthorizationId"]=capture["authorizationId"]
  payload["amountMinor"]=capture["amountMinor"]
  payload["currency"]=capture["currency"]
  payload["paymentSource"]=capture["source"]
  evidence=.array~of("bookingRef:" || booking["bookingRef"],"saleId:" || booking["saleId"],"captureId:" || capture["captureId"],"paymentAuthorizationId:" || capture["authorizationId"])
  metadata=.directory~new; metadata["sourceSchema"]="flylo.payment.capture/0.1"; metadata["revenueRecognition"]="DEFERRED_UNTIL_PERFORMANCE"
  return .AccountingEvent~new("FLYLO:PAYMENT_CAPTURE:" || capture["captureId"],.FlyLoAccountingBuild~LEGAL_ENTITY_ID,"BOOKING_PAYMENT_CAPTURED",capture["capturedAt"]~string~substr(1,10),booking["bookingRef"],"","FLYLO.BOOKING.ENGINE",payload,evidence,metadata)

::method ancillaryCaptureEvent private
  use arg service,capture
  if service==.nil | \service~isA(.Directory) then return .nil
  if capture==.nil | \capture~isA(.Directory) then return .nil
  payload=.directory~new
  payload["status"]=capture["status"]
  payload["bookingRef"]=service["bookingRef"]
  payload["serviceId"]=service["serviceId"]
  payload["serviceType"]=service["type"]
  payload["captureId"]=capture["captureId"]
  payload["paymentAuthorizationId"]=capture["authorizationId"]
  payload["amountMinor"]=capture["amountMinor"]
  payload["currency"]=capture["currency"]
  payload["paymentSource"]=capture["source"]
  evidence=.array~of("bookingRef:" || service["bookingRef"],"serviceId:" || service["serviceId"],"captureId:" || capture["captureId"],"paymentAuthorizationId:" || capture["authorizationId"])
  metadata=.directory~new; metadata["sourceSchema"]="flylo.payment.capture/0.1"; metadata["revenueRecognition"]="DEFERRED_UNTIL_PERFORMANCE"
  return .AccountingEvent~new("FLYLO:PAYMENT_CAPTURE:" || capture["captureId"],.FlyLoAccountingBuild~LEGAL_ENTITY_ID,"ANCILLARY_PAYMENT_CAPTURED",capture["capturedAt"]~string~substr(1,10),service["bookingRef"],"","FLYLO.BOOKING.ENGINE",payload,evidence,metadata)

::method recordBookingCapture
  use arg booking,capture
  event=self~bookingCaptureEvent(booking,capture)
  if event==.nil then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_BOOKING_CAPTURE_REQUIRED","booking and capture evidence required")
  bookingAmount=self~canonicalAmount(booking["amountMinor"]); captureAmount=self~canonicalAmount(capture["amountMinor"])
  if bookingAmount==.nil | captureAmount==.nil | bookingAmount<>captureAmount | booking["currency"]~string~upper<>capture["currency"]~string~upper then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_BOOKING_CAPTURE_MISMATCH",booking["bookingRef"])
  return self~recordEvent(event)

::method recordAncillaryCapture
  use arg service,capture
  event=self~ancillaryCaptureEvent(service,capture)
  if event==.nil then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_ANCILLARY_CAPTURE_REQUIRED","service and capture evidence required")
  serviceAmount=self~canonicalAmount(service["amountMinor"]); captureAmount=self~canonicalAmount(capture["amountMinor"])
  if serviceAmount==.nil | captureAmount==.nil | serviceAmount<>captureAmount | service["currency"]~string~upper<>capture["currency"]~string~upper then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_ANCILLARY_CAPTURE_MISMATCH",service["serviceId"])
  return self~recordEvent(event)

::method recordEvent
  expose topology engine
  use arg event
  if event==.nil | \event~isA(.AccountingEvent) then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_EVENT_REQUIRED","AccountingEvent required")
  if event~legalEntityId<>.FlyLoAccountingBuild~LEGAL_ENTITY_ID then return .AccountingTransactionResult~failure("LEGAL_ENTITY_MISMATCH",event~legalEntityId)

  /* Replay/conflict authority comes first.  This deliberately preserves the
     Accounting Core v0.7 invariant that historical source identity is decided
     before current policy/schema evaluation.  It also prevents a changed
     replay from overwriting the retained source-event slot. */
  existing=engine~book~sourceEntry(event~sourceEventRef)
  if existing<>.nil then return engine~transact(event)

  evidenceCheck=self~validateOperationalEvent(event)
  if evidenceCheck<>.nil then return evidenceCheck
  .FlyLoAccountingPolicy~ensurePeriod(engine,event~eventDate)
  projection=.AccountingEventCodec~toProjection(event)
  if topology<>.nil then do
    o=.table~new; o["subtopic"]="capture/" || self~safeToken(event~sourceEventRef); o["retain"]=.true; o["persistent"]=topology~persistent; o["correlationId"]=event~correlationRef
    pub=topology~topics~publish(.FlyLoServiceTopology~ACCOUNTING_TOPIC,projection,o,.FlyLoServiceTopology~FINANCE_PRINCIPAL)
    if \pub~ok then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_EVENT_PUBLISH_FAILED",pub~code || ":" || pub~detail)
  end
  return engine~transact(event)

::method validateOperationalEvent private
  use arg event
  if wordpos(event~eventType,"BOOKING_PAYMENT_CAPTURED ANCILLARY_PAYMENT_CAPTURED")=0 then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_EVENT_TYPE_UNSUPPORTED",event~eventType)
  if event~sourceAuthorityRef<>"FLYLO.BOOKING.ENGINE" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_SOURCE_AUTHORITY_INVALID",event~sourceAuthorityRef)
  status=event~value("status","")~string~upper
  if status<>"CAPTURED" then return .AccountingTransactionResult~failure("PAYMENT_CAPTURE_REQUIRED","payment authorisation alone is not durable accounting evidence")
  amount=self~canonicalAmount(event~value("amountMinor",.nil))
  if amount==.nil | amount="0" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_AMOUNT_INVALID",event~value("amountMinor",.nil))
  if event~value("currency","")~string~strip="" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_CURRENCY_REQUIRED",event~sourceEventRef)
  captureId=event~value("captureId","")~string~strip
  authId=event~value("paymentAuthorizationId","")~string~strip
  if captureId="" | authId="" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_PAYMENT_EVIDENCE_INCOMPLETE",event~sourceEventRef)
  if event~sourceEventRef<>"FLYLO:PAYMENT_CAPTURE:" || captureId then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_SOURCE_EVENT_REF_INVALID",event~sourceEventRef)
  if event~value("bookingRef","")~string~strip="" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_BOOKING_REF_REQUIRED",event~sourceEventRef)
  if event~eventType="BOOKING_PAYMENT_CAPTURED" then do
    if event~value("saleId","")~string~strip="" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_SALE_ID_REQUIRED",event~sourceEventRef)
  end
  else do
    if event~value("serviceId","")~string~strip="" | event~value("serviceType","")~string~strip="" then return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_SERVICE_EVIDENCE_INCOMPLETE",event~sourceEventRef)
  end
  return .nil

::method rebuildFromRetained
  expose topology engine
  if topology==.nil then return .AccountingTransactionResult~success("REBUILT",.nil)
  events=.directory~new
  do publication over topology~topics~retainedPublications
    if publication~topicName=.FlyLoServiceTopology~ACCOUNTING_TOPIC then do
      p=publication~payload
      if p<>.nil then if p~isA(.Directory) then if p~hasIndex("source_event_ref") then events[p["source_event_ref"]~string]=p
    end
  end
  refs=events~allIndexes; refs~sort
  do ref over refs
    projection=events[ref]
    signal on syntax name badProjection
    event=.AccountingEventCodec~fromProjection(projection)
    signal off syntax
    .FlyLoAccountingPolicy~ensurePeriod(engine,event~eventDate)
    r=engine~transact(event)
    if \r~ok then return r
  end
  return .AccountingTransactionResult~success("REBUILT",.nil)
badProjection:
  signal off syntax
  return .AccountingTransactionResult~failure("FLYLO_ACCOUNTING_RETAINED_EVENT_INVALID",condition("D"))

::method trialBalance
  expose engine
  return engine~book~trialBalance

::method canonicalAmount private
  use arg value
  if value==.nil then return .nil
  signal on syntax name badAmount
  amount=.AccountingUtil~requireWholeNonNegative(value,"FlyLo amountMinor")
  signal off syntax
  return amount
badAmount:
  signal off syntax
  return .nil

::method safeToken private
  use arg value
  t=value~string~upper
  t=t~changestr("/","_"); t=t~changestr(" ","_"); t=t~changestr(":","_")
  return t

::requires "FlyLoAccountingPolicyImpl.cls"
::requires "AccountingEngine.cls"
::requires "AccountingPersistence.cls"
::requires "FlyLoServices.cls"
