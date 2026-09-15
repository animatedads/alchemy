/* Synchronous application adapter over the FlyLo v0.4 Queue Fabric backend.
 * Intended for the single-process acceptance harness and Wire UI application.
 * Production host truth remains behind the AS/400 adapter boundary; this
 * adapter proves that the application talks to backend authorities through
 * Queue Fabric rather than embedding airline state in the browser/UI layer.
 */

::class FlyLoQueueOperationsAdapter subclass FlyLoOperationsAdapter public
::method init
  expose runtime
  use arg runtimeArg
  if runtimeArg == .nil then raise syntax 88.900 array("FLYLO_BACKEND_RUNTIME_REQUIRED")
  runtime = runtimeArg
::method command private
  expose runtime
  use arg operation, idempotencyKey, details
  return .FlyLoEngineCommand~new(runtime~nextCommandId, operation, idempotencyKey, details)
::method payload private
  use arg queueResult
  if queueResult == .nil then raise syntax 88.900 array("FLYLO_BACKEND_NO_RESULT")
  if \queueResult~ok then raise syntax 88.900 array("FLYLO_BACKEND_QUEUE_FAILED", queueResult~code, queueResult~detail)
  package = queueResult~value
  if package == .nil then raise syntax 88.900 array("FLYLO_BACKEND_RESULT_PACKAGE_MISSING")
  p = package~payload
  if p == .nil | \p~isA(.Directory) then raise syntax 88.900 array("FLYLO_BACKEND_RESULT_INVALID")
  if \p~hasIndex("ok") then raise syntax 88.900 array("FLYLO_BACKEND_RESULT_OUTCOME_MISSING")
  if \p["ok"] then raise syntax 88.900 array("FLYLO_BACKEND_REJECTED", p["code"], p["detail"])
  return p
::method flightStatus
  expose runtime
  use arg flightNo, flightDate
  d = .directory~new
  d["flightNo"] = flightNo
  d["flightDate"] = flightDate
  c = self~command("FLIGHT_STATUS", "STATUS:" || flightNo || ":" || flightDate || ":" || runtime~nextCommandId, d)
  return self~payload(runtime~requestOperations(c))
::method bookingLookup
  expose runtime
  use arg bookingRef, familyName
  d = .directory~new
  d["bookingRef"] = bookingRef
  d["familyName"] = familyName
  c = self~command("BOOKING_LOOKUP", "LOOKUP:" || bookingRef || ":" || runtime~nextCommandId, d)
  return self~payload(runtime~requestBooking(c))
::method searchFlights
  expose runtime
  use arg origin, destination, travelDate, passengers = 1
  d = .directory~new
  d["origin"] = origin
  d["destination"] = destination
  d["travelDate"] = travelDate
  d["passengers"] = passengers
  c = self~command("SEARCH", "SEARCH:" || origin || ":" || destination || ":" || travelDate || ":" || passengers || ":" || runtime~nextCommandId, d)
  return self~payload(runtime~requestJourney(c))
::method createBooking
  expose runtime
  use arg bookingRequest
  if bookingRequest == .nil | \bookingRequest~isA(.Directory) then raise syntax 88.900 array("FLYLO_BOOKING_REQUEST_REQUIRED")
  idem = ""
  if bookingRequest~hasIndex("idempotencyKey") then idem = bookingRequest["idempotencyKey"]~string
  if idem = "" then raise syntax 88.900 array("FLYLO_BOOKING_IDEMPOTENCY_REQUIRED")
  c = self~command("BOOKING_CREATE", idem, bookingRequest)
  return self~payload(runtime~requestBooking(c))
::method addCheckedBags
  expose runtime
  use arg bookingRef, passengerIds, quantity=1, paymentAuthorizationId="", idempotencyKey=""
  d=.directory~new
  d["bookingRef"]=bookingRef; d["passengerIds"]=passengerIds; d["quantity"]=quantity; d["paymentAuthorizationId"]=paymentAuthorizationId
  if idempotencyKey~string="" then idempotencyKey="BAG:" || bookingRef || ":" || runtime~nextCommandId
  c=self~command("BOOKING_ADD_CHECKED_BAG",idempotencyKey,d)
  return self~payload(runtime~requestBooking(c))
::method disruptionFacts
  use arg flightNo, flightDate, bookingRef = ""
  status = self~flightStatus(flightNo, flightDate)
  f = .LegalFactSet~new
  ukOrigin = wordpos(status["origin"]~string~upper, "PIK GLA EDI MAN LHR LGW STN") > 0
  usFlight = wordpos(status["origin"]~string~upper, "EWR JFK") > 0 | wordpos(status["destination"]~string~upper, "EWR JFK") > 0
  cancelled = status["status"]~string~upper = "CANCELLED"
  ignored = f~putKnown("DEPARTS_UK", ukOrigin, "FlyLo Operations Engine fixture", "ENGINE_FIXTURE")
  ignored = f~putKnown("US_COVERED_FLIGHT", usFlight, "FlyLo Operations Engine fixture", "ENGINE_FIXTURE")
  ignored = f~putKnown("FLYLO_MERCHANT_OF_RECORD", .true, "FlyLo booking engine fixture", "ENGINE_FIXTURE")
  ignored = f~putKnown("FLIGHT_CANCELLED", cancelled, "FlyLo Operations Engine fixture", "ENGINE_FIXTURE")
  ignored = f~putKnown("CARE_THRESHOLD_REACHED", .false, "No elapsed-time disruption evidence in fixture", "ENGINE_FIXTURE")
  return f

::requires "FlyLoOperationsAdapter.cls"
::requires "FlyLoServices.cls"
