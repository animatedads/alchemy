/* FlyLo retail transaction state machine.
   Search data comes from OperationsAdapter. Payment and booking creation are
   independent external side effects and are deliberately NOT represented as
   an atomic transaction. Idempotency and RECOVERY_REQUIRED preserve truth. */

::class FlyLoSalesProcess public
::attribute operations get
::attribute payments get
::attribute sales get

::method init
  expose operations payments accounting sales nextSale
  use arg operationsArg, paymentsArg, accountingArg=.nil, startingSaleSequence=0
  if operationsArg == .nil then raise syntax 88.900 array("FLYLO_OPERATIONS_ADAPTER_REQUIRED")
  if paymentsArg == .nil then raise syntax 88.900 array("FLYLO_PAYMENT_ADAPTER_REQUIRED")
  operations = operationsArg
  payments = paymentsArg
  accounting = accountingArg
  sales = .table~new
  if \datatype(startingSaleSequence,"W") | startingSaleSequence<0 then startingSaleSequence=0
  nextSale = startingSaleSequence + 0

::method search
  expose operations
  use arg origin, destination, travelDate, passengers = 1
  return operations~searchFlights(origin,destination,travelDate,passengers)

::method selectOffer
  expose sales nextSale
  use arg offer, passengers = 1
  if offer == .nil then raise syntax 88.900 array("FLYLO_OFFER_REQUIRED")
  nextSale += 1
  saleId = "SALE-" || right("00000" || nextSale, 5)
  s = .FlyLoSale~new(saleId, offer, passengers)
  sales[saleId] = s
  return s~snapshot

::method passengerDetails
  expose sales
  use arg saleId, passengerData
  s = self~sale(saleId)
  ignored = s~requireState("PASSENGERS")
  ignored = s~setPassengers(passengerData)
  ignored = s~move("EXTRAS")
  return s~snapshot

::method extras
  expose sales
  use arg saleId, selections
  s = self~sale(saleId)
  ignored = s~requireState("EXTRAS")
  ignored = s~setExtras(selections)
  ignored = s~move("REVIEW")
  return s~snapshot

::method review
  expose sales
  use arg saleId, termsVersion
  s = self~sale(saleId)
  ignored = s~requireState("REVIEW")
  if termsVersion~string = "" then raise syntax 88.900 array("FLYLO_TERMS_VERSION_REQUIRED")
  ignored = s~acceptTerms(termsVersion)
  ignored = s~move("PAYMENT")
  return s~snapshot

::method pay
  expose sales payments operations accounting
  use arg saleId, paymentMethodToken
  s = self~sale(saleId)
  ignored = s~requireState("PAYMENT")
  intentId = saleId || "-PAY-1"
  idem = "FLYLO:" || saleId || ":PAYMENT:1"
  intent = .FlyLoPaymentIntent~new(intentId,paymentMethodToken,s~totalMinor,"GBP",idem)
  auth = payments~authorize(intent)
  if auth["status"] \== "AUTHORIZED" then do
    ignored = s~markPayment("DECLINED", "")
    return s~snapshot
  end
  ignored = s~markPayment("AUTHORIZED", auth["authorizationId"])
  ignored = s~move("BOOKING_PENDING")

  /* Once payment is authorised, an uncertain booking response must not cause
     another payment attempt. The booking operation owns its own idempotency key. */
  bookingIdem = "FLYLO:" || saleId || ":BOOKING:1"
  signal on syntax name booking_uncertain
  booking = operations~createBooking(s~bookingRequest(bookingIdem))
  signal off syntax
  if booking == .nil then do
    ignored = s~move("RECOVERY_REQUIRED")
    return s~snapshot
  end
  if \booking~hasIndex("status") | booking["status"] \== "CONFIRMED" then do
    ignored = s~move("RECOVERY_REQUIRED")
    return s~snapshot
  end
  ignored = s~confirm(booking)
  ignored = s~move("CONFIRMED")

  /* Booking truth and payment capture are independent.  Once inventory has
     confirmed the booking, explicitly capture the prior authorisation.  A
     capture failure never causes a second booking or second authorisation; it
     becomes financial recovery state on the already-confirmed sale. */
  captureIdem = "FLYLO:" || saleId || ":CAPTURE:1"
  captureIntent = .FlyLoPaymentCaptureIntent~new(saleId || "-CAP-1", auth["authorizationId"], s~totalMinor, "GBP", captureIdem)
  signal on syntax name capture_uncertain
  capture = payments~capture(captureIntent)
  signal off syntax
  if capture == .nil | capture["status"] <> "CAPTURED" then do
    ignored = s~markCapture("RECOVERY_REQUIRED", "")
    return s~snapshot
  end
  ignored = s~markCapture("CAPTURED", capture["captureId"])
  if accounting <> .nil then do
    posted = accounting~recordBookingCapture(booking,capture)
    if posted~ok then ignored = s~markAccounting(posted~status, posted~entry~entryId)
    else ignored = s~markAccounting("RECOVERY_REQUIRED", posted~errorCode)
  end
  return s~snapshot

capture_uncertain:
  signal off syntax
  ignored = s~markCapture("RECOVERY_REQUIRED", "")
  return s~snapshot

booking_uncertain:
  signal off syntax
  ignored = s~move("RECOVERY_REQUIRED")
  return s~snapshot

::method status
  use arg saleId
  return self~sale(saleId)~snapshot

::method sale private
  expose sales
  use arg saleId
  if \sales~hasIndex(saleId) then raise syntax 88.900 array("FLYLO_SALE_NOT_FOUND", saleId)
  return sales[saleId]

::class FlyLoSale
::attribute saleId get
::attribute state get
::attribute offer get
::attribute passengers get
::attribute extras get
::attribute termsVersion get
::attribute paymentStatus get
::attribute paymentAuthorizationId get
::attribute paymentCaptureStatus get
::attribute paymentCaptureId get
::attribute accountingStatus get
::attribute accountingEntryId get
::attribute booking get
::attribute totalMinor get

::method init
  expose saleId state offer passengerCount passengers extras termsVersion paymentStatus paymentAuthorizationId paymentCaptureStatus paymentCaptureId accountingStatus accountingEntryId booking totalMinor
  use arg saleIdArg, offerArg, passengerCountArg = 1
  saleId = saleIdArg
  state = "PASSENGERS"
  offer = self~copyMap(offerArg)
  passengerCount = passengerCountArg
  passengers = .array~new
  extras = .directory~new
  termsVersion = ""
  paymentStatus = "NOT_STARTED"
  paymentAuthorizationId = ""
  paymentCaptureStatus = "NOT_STARTED"
  paymentCaptureId = ""
  accountingStatus = "NOT_POSTED"
  accountingEntryId = ""
  booking = .nil
  totalMinor = self~baseFareMinor * passengerCount

::method baseFareMinor private
  expose offer
  if offer~hasIndex("fareMinor") then return offer["fareMinor"]
  if offer~hasIndex("fareGBP") then return (offer["fareGBP"] * 100)~round
  raise syntax 88.900 array("FLYLO_OFFER_PRICE_REQUIRED")

::method requireState
  expose state
  use arg expected
  if state \== expected then raise syntax 88.900 array("FLYLO_SALE_STATE", state, expected)
  return .true

::method move
  expose state
  use arg nextState
  allowed = .table~new
  allowed["PASSENGERS"] = "EXTRAS"
  allowed["EXTRAS"] = "REVIEW"
  allowed["REVIEW"] = "PAYMENT"
  allowed["PAYMENT"] = "BOOKING_PENDING"
  allowed["BOOKING_PENDING"] = "CONFIRMED RECOVERY_REQUIRED"
  if \allowed~hasIndex(state) | wordpos(nextState,allowed[state]) = 0 then raise syntax 88.900 array("FLYLO_SALE_TRANSITION", state, nextState)
  state = nextState
  return .true

::method setPassengers
  expose passengers passengerCount
  use arg passengerData
  if passengerData == .nil then raise syntax 88.900 array("FLYLO_PASSENGERS_REQUIRED")
  if passengerData~items \= passengerCount then raise syntax 88.900 array("FLYLO_PASSENGER_COUNT_MISMATCH", passengerCount, passengerData~items)
  copy = .array~new
  do p over passengerData
    if \(p~isA(.Table) | p~isA(.Directory)) then raise syntax 88.900 array("FLYLO_PASSENGER_INVALID")
    if \p~hasIndex("givenName") | \p~hasIndex("familyName") then raise syntax 88.900 array("FLYLO_PASSENGER_NAME_REQUIRED")
    q = .directory~new
    q["givenName"] = p["givenName"]~string
    q["familyName"] = p["familyName"]~string
    if p~hasIndex("email") then q["email"] = p["email"]~string
    copy~append(q)
  end
  passengers = copy
  return .true

::method setExtras
  expose extras totalMinor passengerCount
  use arg selections
  e = .directory~new
  if selections \== .nil then do k over selections
    v = selections[k]
    if v then do
      select
        when k = "CABIN_BAG" then totalMinor += 2900 * passengerCount
        when k = "CHECKED_BAG" then totalMinor += 4900 * passengerCount
        when k = "SEAT_SELECTION" then totalMinor += 1400 * passengerCount
        when k = "PRIORITY_BOARDING" then totalMinor += 900 * passengerCount
        otherwise raise syntax 88.900 array("FLYLO_UNKNOWN_EXTRA", k)
      end
      e[k] = .true
    end
  end
  extras = e
  return .true

::method acceptTerms
  expose termsVersion
  use arg version
  termsVersion = version~string
  return .true

::method markPayment
  expose paymentStatus paymentAuthorizationId
  use arg statusArg, authId = ""
  paymentStatus = statusArg
  paymentAuthorizationId = authId
  return .true

::method markCapture
  expose paymentCaptureStatus paymentCaptureId
  use arg statusArg, captureIdArg=""
  paymentCaptureStatus=statusArg
  paymentCaptureId=captureIdArg
  return .true

::method markAccounting
  expose accountingStatus accountingEntryId
  use arg statusArg, entryOrError=""
  accountingStatus=statusArg
  accountingEntryId=entryOrError
  return .true

::method confirm
  expose booking
  use arg bookingArg
  booking = self~copyMap(bookingArg)
  return .true

::method bookingRequest
  expose saleId offer passengers extras termsVersion paymentAuthorizationId totalMinor
  use arg idempotencyKey
  d = .directory~new
  d["saleId"] = saleId
  d["idempotencyKey"] = idempotencyKey
  d["offer"] = self~copyMap(offer)
  d["passengers"] = passengers
  d["extras"] = self~copyMap(extras)
  d["termsVersion"] = termsVersion
  d["paymentAuthorizationId"] = paymentAuthorizationId
  d["amountMinor"] = totalMinor
  d["currency"] = "GBP"
  return d

::method snapshot
  expose saleId state offer passengers extras termsVersion paymentStatus paymentAuthorizationId paymentCaptureStatus paymentCaptureId accountingStatus accountingEntryId booking totalMinor
  d = .directory~new
  d["saleId"] = saleId
  d["state"] = state
  d["offer"] = self~copyMap(offer)
  d["passengers"] = passengers
  d["extras"] = self~copyMap(extras)
  d["termsVersion"] = termsVersion
  d["paymentStatus"] = paymentStatus
  d["paymentAuthorizationId"] = paymentAuthorizationId
  d["paymentCaptureStatus"] = paymentCaptureStatus
  d["paymentCaptureId"] = paymentCaptureId
  d["accountingStatus"] = accountingStatus
  d["accountingEntryId"] = accountingEntryId
  d["totalMinor"] = totalMinor
  d["currency"] = "GBP"
  if booking \== .nil then d["booking"] = self~copyMap(booking)
  return d

::method copyMap private
  use arg source
  out = .directory~new
  if source == .nil then return out
  do k over source
    out[k] = source[k]
  end
  return out

::requires "FlyLoOperationsAdapter.cls"
::requires "FlyLoPaymentAdapter.cls"
