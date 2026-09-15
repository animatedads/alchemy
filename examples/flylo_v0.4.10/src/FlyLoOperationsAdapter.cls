/* Backend boundary: real AS/400 in production, explicit demo double only when
   requested. No silent failover from production to invented booking data. */

::class FlyLoOperationsAdapter public
::method flightStatus
  use arg flightNo, flightDate
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", flightNo, flightDate)
::method bookingLookup
  use arg bookingRef, familyName
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", bookingRef)
::method searchFlights
  use arg origin, destination, travelDate, passengers = 1
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", origin, destination, travelDate)
::method disruptionFacts
  use arg flightNo, flightDate, bookingRef = ""
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", flightNo, flightDate)
::method createBooking
  use arg bookingRequest
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", "BOOKING_CREATE")
::method addCheckedBags
  use arg bookingRef, passengerIds, quantity=1, paymentAuthorizationId="", idempotencyKey=""
  raise syntax 88.900 array("FLYLO_OPERATIONS_NOT_IMPLEMENTED", "BOOKING_ADD_CHECKED_BAG")

::class FlyLoAS400OperationsAdapter subclass FlyLoOperationsAdapter public
::method init
  expose transport
  use arg transportArg
  if transportArg == .nil then raise syntax 88.900 array("FLYLO_AS400_TRANSPORT_REQUIRED")
  transport = transportArg
::method flightStatus
  expose transport
  use arg flightNo, flightDate
  return transport~request("FLIGHT_STATUS", .FlyLoOperationsPayload~two("flightNo", flightNo, "flightDate", flightDate))
::method bookingLookup
  expose transport
  use arg bookingRef, familyName
  return transport~request("BOOKING_LOOKUP", .FlyLoOperationsPayload~two("bookingRef", bookingRef, "familyName", familyName))
::method searchFlights
  expose transport
  use arg origin, destination, travelDate, passengers = 1
  p = .directory~new; p["origin"] = origin; p["destination"] = destination; p["travelDate"] = travelDate; p["passengers"] = passengers
  return transport~request("FLIGHT_SEARCH", p)
::method disruptionFacts
  expose transport
  use arg flightNo, flightDate, bookingRef = ""
  p = .directory~new; p["flightNo"] = flightNo; p["flightDate"] = flightDate; p["bookingRef"] = bookingRef
  return transport~request("DISRUPTION_FACTS", p)
::method createBooking
  expose transport
  use arg bookingRequest
  return transport~request("BOOKING_CREATE", bookingRequest)

::class FlyLoDemoOperationsAdapter subclass FlyLoOperationsAdapter public
::method init
  expose enabled
  use arg explicitDemoMode = .false
  enabled = explicitDemoMode
  if \enabled then raise syntax 88.900 array("FLYLO_DEMO_MODE_MUST_BE_EXPLICIT")
::method flightStatus
  expose enabled
  use arg flightNo, flightDate
  d = .directory~new; d["source"]="DEMO"; d["flightNo"]=flightNo; d["date"]=flightDate; d["origin"]="PIK"; d["destination"]="EWR"; d["status"]="ON_TIME"; return d
::method bookingLookup
  use arg bookingRef, familyName
  d=.directory~new; d["source"]="DEMO"; d["bookingRef"]=bookingRef; d["familyName"]=familyName; d["flightNo"]="FL101"; d["origin"]="PIK"; d["destination"]="EWR"; d["status"]="CONFIRMED"; return d
::method searchFlights
  use arg origin, destination, travelDate, passengers = 1
  d=.directory~new; d["source"]="DEMO"; d["offerId"]="DEMO-FL101-" || travelDate; d["flightNo"]="FL101"; d["origin"]=origin; d["destination"]=destination; d["date"]=travelDate; d["passengers"]=passengers; d["fareGBP"]="199.00"; d["fareMinor"]=19900; d["currency"]="GBP"; d["mandatoryChargesIncluded"]=.true; return d
::method createBooking
  use arg bookingRequest
  d=.directory~new; d["source"]="DEMO"; d["status"]="CONFIRMED"; d["bookingRef"]="FL" || right(bookingRequest["saleId"],5); d["saleId"]=bookingRequest["saleId"]; d["idempotencyKey"]=bookingRequest["idempotencyKey"]; return d
::method addCheckedBags
  use arg bookingRef, passengerIds, quantity=1, paymentAuthorizationId="", idempotencyKey=""
  d=.directory~new; d["source"]="DEMO"; d["status"]="CONFIRMED"; d["bookingRef"]=bookingRef; d["passengerIds"]=passengerIds; d["quantityPerPassenger"]=quantity; d["paymentAuthorizationId"]=paymentAuthorizationId; d["idempotencyKey"]=idempotencyKey; return d
::method disruptionFacts
  use arg flightNo, flightDate, bookingRef = ""
  f=.LegalFactSet~new
  ignored = f~putKnown("DEPARTS_UK", .true, "DEMO operations", "DEMO")
  ignored = f~putKnown("US_COVERED_FLIGHT", .true, "DEMO operations", "DEMO")
  ignored = f~putKnown("FLYLO_MERCHANT_OF_RECORD", .true, "DEMO booking", "DEMO")
  ignored = f~putKnown("FLIGHT_CANCELLED", .false, "DEMO operations", "DEMO")
  ignored = f~putKnown("CARE_THRESHOLD_REACHED", .false, "DEMO operations", "DEMO")
  return f

::class FlyLoOperationsPayload
::method two class
  use arg k1,v1,k2,v2
  d=.directory~new; d[k1]=v1; d[k2]=v2; return d

::requires "LegalEffect.cls"
