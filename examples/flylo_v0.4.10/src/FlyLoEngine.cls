/* FlyLo v0.4 backend domain authorities.
 *
 * The backend deliberately separates customer/channel intent from durable
 * airline state.  Queue-facing orchestration lives in FlyLoServices.cls;
 * this file owns the domain authorities and their deterministic projections.
 *
 * Test/demo schedules are explicit fixtures.  Production host truth remains
 * behind FlyLoOperationsAdapter / the AS/400 transport boundary.
 */

::class FlyLoEngineBuild public
::constant VERSION "0.4.1"
::constant API "flylo.engine/0.4"

::class FlyLoEngineResult public
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

::class FlyLoEngineCommand public
::attribute commandId get
::attribute operation get
::attribute idempotencyKey get
::attribute requestedAt get
::attribute details get
::method init
  expose commandId operation idempotencyKey requestedAt details
  use arg commandIdArg, operationArg, idempotencyKeyArg, detailsArg = .nil, requestedAtArg = ""
  commandId = commandIdArg~string
  operation = operationArg~string~upper
  idempotencyKey = idempotencyKeyArg~string
  if requestedAtArg~string = "" then requestedAt = .DateTime~new~utcIsoDate
  else requestedAt = requestedAtArg~string
  if detailsArg == .nil then details = .directory~new
  else details = detailsArg
::method detail
  expose details
  use arg key, defaultValue = ""
  if details == .nil then return defaultValue
  if details~hasIndex(key) then return details[key]
  return defaultValue
::method asPayload
  expose commandId operation idempotencyKey requestedAt details
  d = .directory~new
  d["schema"] = .FlyLoEngineBuild~API || "/command"
  d["commandId"] = commandId
  d["operation"] = operation
  d["idempotencyKey"] = idempotencyKey
  d["requestedAt"] = requestedAt
  d["details"] = details
  return d
::method fromPayload class
  use arg p
  if p == .nil then return .nil
  details = .directory~new
  if p~hasIndex("details") then if p["details"] <> .nil then details = p["details"]
  requestedAt = ""
  if p~hasIndex("requestedAt") then requestedAt = p["requestedAt"]
  return self~new(p["commandId"], p["operation"], p["idempotencyKey"], details, requestedAt)

::class FlyLoFlightLeg public
::attribute flightNo get
::attribute origin get
::attribute destination get
::attribute departureMinute get
::attribute arrivalMinute get
::attribute fareMinor get
::attribute capacity get
::attribute currency get
::method init
  expose flightNo origin destination departureMinute arrivalMinute fareMinor capacity currency
  use arg flightNoArg, originArg, destinationArg, departureMinuteArg, arrivalMinuteArg, fareMinorArg, capacityArg = 180, currencyArg = "GBP"
  flightNo = flightNoArg~string~upper
  origin = originArg~string~upper
  destination = destinationArg~string~upper
  departureMinute = departureMinuteArg + 0
  arrivalMinute = arrivalMinuteArg + 0
  fareMinor = fareMinorArg + 0
  capacity = capacityArg + 0
  currency = currencyArg~string~upper
  if flightNo = "" then raise syntax 88.900 array("FLYLO_FLIGHT_NUMBER_REQUIRED")
  if origin~length <> 3 | destination~length <> 3 then raise syntax 88.900 array("FLYLO_IATA_REQUIRED", origin, destination)
  if origin = destination then raise syntax 88.900 array("FLYLO_ROUTE_INVALID", origin, destination)
  if departureMinute < 0 | arrivalMinute <= departureMinute then raise syntax 88.900 array("FLYLO_FLIGHT_TIME_INVALID", flightNo)
  if fareMinor < 0 | capacity < 1 then raise syntax 88.900 array("FLYLO_FLIGHT_COMMERCIAL_INVALID", flightNo)
::method snapshot
  expose flightNo origin destination departureMinute arrivalMinute fareMinor capacity currency
  d = .directory~new
  d["flightNo"] = flightNo
  d["origin"] = origin
  d["destination"] = destination
  d["departureMinute"] = departureMinute
  d["arrivalMinute"] = arrivalMinute
  d["fareMinor"] = fareMinor
  d["capacity"] = capacity
  d["currency"] = currency
  return d

::class FlyLoScheduleRegistry public
::method init
  expose flights byNumber
  flights = .array~new
  byNumber = .directory~new
::method add
  expose flights byNumber
  use arg leg
  if leg == .nil then return .FlyLoEngineResult~failure("FLIGHT_REQUIRED")
  key = leg~flightNo
  if byNumber~hasIndex(key) then return .FlyLoEngineResult~failure("FLIGHT_DUPLICATE", key)
  byNumber[key] = leg
  flights~append(leg)
  return .FlyLoEngineResult~success(leg)
::method flight
  expose byNumber
  use arg flightNo
  key = flightNo~string~upper
  if byNumber~hasIndex(key) then return byNumber[key]
  return .nil
::method all
  expose flights
  out = .array~new
  do leg over flights
    out~append(leg)
  end
  return out
::method fromAirport
  expose flights
  use arg airport
  wanted = airport~string~upper
  out = .array~new
  do leg over flights
    if leg~origin = wanted then out~append(leg)
  end
  return out
::method fixture class
  /* Explicit development fixture.  These are invented FlyLo services, not a
     representation of a live airline timetable.  The topology is deliberate:
     GLA/EDI/MAN/LHR can reach EWR through PIK, and return paths also exist. */
  s = self~new
  ignored = s~add(.FlyLoFlightLeg~new("FL101", "PIK", "EWR", 540, 720, 19900, 12, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL102", "EWR", "PIK", 840, 1080, 20500, 12, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL201", "GLA", "PIK", 420, 465, 3900, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL202", "EDI", "PIK", 390, 450, 4500, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL203", "MAN", "PIK", 360, 430, 5900, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL204", "LHR", "PIK", 345, 420, 6900, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL211", "PIK", "GLA", 1170, 1215, 3900, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL212", "PIK", "EDI", 1150, 1210, 4500, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL213", "PIK", "MAN", 1110, 1180, 5900, 8, "GBP"))
  ignored = s~add(.FlyLoFlightLeg~new("FL214", "PIK", "LHR", 1095, 1170, 6900, 8, "GBP"))
  return s

::class FlyLoJourneyAuthority public
::attribute schedule get
::method init
  expose schedule seats appliedInventory
  use arg scheduleArg
  if scheduleArg == .nil then raise syntax 88.900 array("FLYLO_SCHEDULE_REQUIRED")
  schedule = scheduleArg
  seats = .directory~new
  appliedInventory = .directory~new
::method seatKey private
  use arg flightNo, travelDate
  return flightNo~string~upper || "|" || travelDate~string
::method availableSeats
  expose schedule seats
  use arg flightNo, travelDate
  leg = schedule~flight(flightNo)
  if leg == .nil then return 0
  key = self~seatKey(flightNo, travelDate)
  if seats~hasIndex(key) then return seats[key]
  return leg~capacity
::method validateSearch private
  use arg origin, destination, travelDate, passengers
  o = origin~string~upper
  d = destination~string~upper
  if o~length <> 3 | d~length <> 3 then return .FlyLoEngineResult~failure("AIRPORT_IATA_INVALID", o || "/" || d)
  if o = d then return .FlyLoEngineResult~failure("ORIGIN_DESTINATION_SAME", o)
  if travelDate~string = "" then return .FlyLoEngineResult~failure("TRAVEL_DATE_REQUIRED")
  p = passengers + 0
  if p < 1 then return .FlyLoEngineResult~failure("PASSENGER_COUNT_INVALID", p)
  return .FlyLoEngineResult~success(.true)
::method routeAvailable private
  use arg legs, travelDate, passengers
  do leg over legs
    if self~availableSeats(leg~flightNo, travelDate) < passengers then return .false
  end
  return .true
::method minAvailable private
  use arg legs, travelDate
  min = 999999
  do leg over legs
    a = self~availableSeats(leg~flightNo, travelDate)
    if a < min then min = a
  end
  if min = 999999 then return 0
  return min
::method totalFare private
  use arg legs
  total = 0
  do leg over legs
    total += leg~fareMinor
  end
  return total
::method candidateBetter private
  use arg candidate, best
  if best == .nil then return .true
  cfare = self~totalFare(candidate)
  bfare = self~totalFare(best)
  if cfare < bfare then return .true
  if cfare > bfare then return .false
  return candidate~items < best~items
::method search
  expose schedule
  use arg origin, destination, travelDate, passengers = 1
  valid = self~validateSearch(origin, destination, travelDate, passengers)
  if \valid~ok then return valid
  origin = origin~string~upper
  destination = destination~string~upper
  passengers = passengers + 0
  best = .nil

  do first over schedule~fromAirport(origin)
    direct = .array~of(first)
    if first~destination = destination then do
      if self~routeAvailable(direct, travelDate, passengers) then if self~candidateBetter(direct, best) then best = direct
      iterate
    end
    do second over schedule~fromAirport(first~destination)
      if second~destination <> destination then iterate
      /* Same-day fixture routing with a realistic minimum and bounded wait. */
      connect = second~departureMinute - first~arrivalMinute
      if connect < 45 | connect > 360 then iterate
      candidate = .array~of(first, second)
      if self~routeAvailable(candidate, travelDate, passengers) then if self~candidateBetter(candidate, best) then best = candidate
    end
  end

  if best == .nil then return .FlyLoEngineResult~failure("NO_ITINERARY_AVAILABLE", origin || "->" || destination)
  return .FlyLoEngineResult~success(self~offerFrom(best, travelDate, passengers), "itinerary found")
::method safeToken private
  use arg value
  t = value~string~upper
  t = t~changestr("/", "_")
  t = t~changestr(" ", "_")
  t = t~changestr(":", "_")
  return t
::method offerFrom private
  use arg legs, travelDate, passengers
  farePerPassenger = self~totalFare(legs)
  total = farePerPassenger * passengers
  routeToken = ""
  legRows = .array~new
  do i = 1 to legs~items
    leg = legs[i]
    if i > 1 then routeToken ||= "+"
    routeToken ||= leg~flightNo
    row = leg~snapshot
    row["date"] = travelDate~string
    row["availableSeats"] = self~availableSeats(leg~flightNo, travelDate)
    legRows~append(row)
  end
  first = legs[1]
  last = legs[legs~items]
  offerId = "OFFER-" || self~safeToken(travelDate) || "-" || routeToken || "-P" || passengers || "-" || total
  d = .directory~new
  d["schema"] = "flylo.offer/0.4"
  d["source"] = "ENGINE_FIXTURE"
  d["offerId"] = offerId
  d["itineraryId"] = "ITIN-" || self~safeToken(travelDate) || "-" || routeToken
  d["flightNo"] = first~flightNo
  d["origin"] = first~origin
  d["destination"] = last~destination
  d["date"] = travelDate~string
  d["passengers"] = passengers
  d["fareMinor"] = farePerPassenger
  d["totalFareMinor"] = total
  d["fareGBP"] = self~moneyText(farePerPassenger)
  d["currency"] = first~currency
  d["mandatoryChargesIncluded"] = .true
  d["availableSeats"] = self~minAvailable(legs, travelDate)
  d["legs"] = legRows
  return d
::method moneyText private
  use arg minor
  whole = minor % 100
  cents = minor // 100
  return whole || "." || right("0" || cents, 2)
::method validateOffer private
  expose schedule
  use arg offer, passengers
  if offer == .nil | \offer~isA(.Directory) then return .FlyLoEngineResult~failure("OFFER_REQUIRED")
  if \offer~hasIndex("schema") | offer["schema"] <> "flylo.offer/0.4" then return .FlyLoEngineResult~failure("OFFER_SCHEMA_INVALID")
  if \offer~hasIndex("legs") then return .FlyLoEngineResult~failure("OFFER_LEGS_REQUIRED")
  legs = offer["legs"]
  if legs == .nil | \legs~isA(.Array) | legs~items < 1 | legs~items > 2 then return .FlyLoEngineResult~failure("OFFER_LEGS_INVALID")
  expectedOrigin = offer["origin"]~string~upper
  totalOne = 0
  currency = ""
  do i = 1 to legs~items
    row = legs[i]
    if row == .nil | \row~isA(.Directory) then return .FlyLoEngineResult~failure("OFFER_LEG_INVALID", i)
    leg = schedule~flight(row["flightNo"])
    if leg == .nil then return .FlyLoEngineResult~failure("OFFER_FLIGHT_UNKNOWN", row["flightNo"])
    if leg~origin <> expectedOrigin then return .FlyLoEngineResult~failure("OFFER_ROUTE_TAMPERED", leg~flightNo)
    if row["origin"]~string~upper <> leg~origin | row["destination"]~string~upper <> leg~destination then return .FlyLoEngineResult~failure("OFFER_ROUTE_TAMPERED", leg~flightNo)
    if i > 1 then do
      prev = schedule~flight(legs[i - 1]["flightNo"])
      connect = leg~departureMinute - prev~arrivalMinute
      if connect < 45 | connect > 360 then return .FlyLoEngineResult~failure("OFFER_CONNECTION_INVALID", leg~flightNo)
    end
    expectedOrigin = leg~destination
    totalOne += leg~fareMinor
    if currency = "" then currency = leg~currency
    else if currency <> leg~currency then return .FlyLoEngineResult~failure("OFFER_CURRENCY_MIXED")
  end
  if expectedOrigin <> offer["destination"]~string~upper then return .FlyLoEngineResult~failure("OFFER_DESTINATION_TAMPERED")
  expectedFare = totalOne
  if offer["fareMinor"] + 0 <> expectedFare then return .FlyLoEngineResult~failure("OFFER_PRICE_TAMPERED", offer["fareMinor"] || "/" || expectedFare)
  if offer~hasIndex("totalFareMinor") then if offer["totalFareMinor"] + 0 <> expectedFare * passengers then return .FlyLoEngineResult~failure("OFFER_TOTAL_PRICE_TAMPERED")
  if offer["currency"]~string~upper <> currency then return .FlyLoEngineResult~failure("OFFER_CURRENCY_TAMPERED")
  if offer~hasIndex("passengers") then if offer["passengers"] + 0 <> passengers then return .FlyLoEngineResult~failure("OFFER_PASSENGER_COUNT_TAMPERED")
  return .FlyLoEngineResult~success(.true)
::method commitOffer
  expose seats appliedInventory
  use arg bookingId, idempotencyKey, offer, passengers
  idem = idempotencyKey~string
  if idem = "" then return .FlyLoEngineResult~failure("INVENTORY_IDEMPOTENCY_REQUIRED")
  if appliedInventory~hasIndex(idem) then return .FlyLoEngineResult~success(appliedInventory[idem], "inventory replay")
  passengers = passengers + 0
  valid = self~validateOffer(offer, passengers)
  if \valid~ok then return valid
  travelDate = offer["date"]~string
  legRows = offer["legs"]
  do row over legRows
    if self~availableSeats(row["flightNo"], travelDate) < passengers then return .FlyLoEngineResult~failure("SEATS_NO_LONGER_AVAILABLE", row["flightNo"])
  end
  do row over legRows
    key = self~seatKey(row["flightNo"], travelDate)
    seats[key] = self~availableSeats(row["flightNo"], travelDate) - passengers
  end
  p = .directory~new
  p["schema"] = "flylo.inventory.commit/0.4"
  p["bookingId"] = bookingId~string
  p["idempotencyKey"] = idem
  p["offerId"] = offer["offerId"]
  p["origin"] = offer["origin"]
  p["destination"] = offer["destination"]
  p["travelDate"] = travelDate
  p["passengers"] = passengers
  p["fareMinorPerPassenger"] = offer["fareMinor"] + 0
  p["mandatoryFareMinor"] = (offer["fareMinor"] + 0) * passengers
  p["currency"] = offer["currency"]
  p["legs"] = self~copyLegRows(legRows)
  p["committedAt"] = .DateTime~new~utcIsoDate
  appliedInventory[idem] = p
  return .FlyLoEngineResult~success(p, "inventory committed")
::method applyInventoryProjection
  expose seats appliedInventory schedule
  use arg p
  if p == .nil | \p~isA(.Directory) then return .FlyLoEngineResult~failure("INVENTORY_PROJECTION_REQUIRED")
  if \p~hasIndex("schema") | p["schema"] <> "flylo.inventory.commit/0.4" then return .FlyLoEngineResult~failure("INVENTORY_PROJECTION_SCHEMA_INVALID")
  idem = p["idempotencyKey"]~string
  if idem = "" then return .FlyLoEngineResult~failure("INVENTORY_PROJECTION_IDEMPOTENCY_REQUIRED")
  if appliedInventory~hasIndex(idem) then return .FlyLoEngineResult~success(.true, "already projected")
  passengers = p["passengers"] + 0
  travelDate = p["travelDate"]~string
  do row over p["legs"]
    leg = schedule~flight(row["flightNo"])
    if leg == .nil then return .FlyLoEngineResult~failure("INVENTORY_PROJECTION_FLIGHT_UNKNOWN", row["flightNo"])
    if self~availableSeats(leg~flightNo, travelDate) < passengers then return .FlyLoEngineResult~failure("INVENTORY_PROJECTION_CAPACITY_INVALID", leg~flightNo)
  end
  do row over p["legs"]
    key = self~seatKey(row["flightNo"], travelDate)
    seats[key] = self~availableSeats(row["flightNo"], travelDate) - passengers
  end
  appliedInventory[idem] = p
  return .FlyLoEngineResult~success(.true)
::method copyLegRows private
  use arg source
  out = .array~new
  do row over source
    copy = .directory~new
    do k over row
      copy[k] = row[k]
    end
    out~append(copy)
  end
  return out

::class FlyLoBookingAuthority public
::method init
  expose bookings byIdempotency serviceByIdempotency maxSaleSequence
  bookings = .directory~new
  byIdempotency = .directory~new
  serviceByIdempotency = .directory~new
  maxSaleSequence = 0
::method safeToken private
  use arg value
  t = value~string~upper
  t = t~changestr("/", "_")
  t = t~changestr(" ", "_")
  t = t~changestr(":", "_")
  t = t~changestr("-", "")
  return t
::method noteSaleSequence private
  expose maxSaleSequence
  use arg saleId
  text=saleId~string~upper~strip
  if text~startsWith("SALE-") then do
    suffix=text~substr(6)
    if datatype(suffix,"W") then if suffix+0>maxSaleSequence then maxSaleSequence=suffix+0
  end
  return maxSaleSequence
::method highestSaleSequence
  expose maxSaleSequence
  return maxSaleSequence
::method bookingRefFor private
  use arg idempotencyKey, saleId
  token = self~safeToken(saleId)
  if token = "" then token = self~safeToken(idempotencyKey)
  return "FL" || right("000000" || token, 8)
::method bookingIdFor private
  use arg idempotencyKey
  return "BKG-" || self~safeToken(idempotencyKey)
::method confirmedByIdempotency
  expose byIdempotency
  use arg idempotencyKey
  key = idempotencyKey~string
  if byIdempotency~hasIndex(key) then return byIdempotency[key]
  return .nil
::method ancillaryMinor private
  use arg extras, passengerCount
  if extras == .nil then return 0
  if \extras~isA(.Directory) & \extras~isA(.Table) then raise syntax 88.900 array("FLYLO_EXTRAS_INVALID")
  total = 0
  do k over extras
    if extras[k] then do
      select
        when k = "CABIN_BAG" then total += 2900 * passengerCount
        when k = "CHECKED_BAG" then total += 4900 * passengerCount
        when k = "SEAT_SELECTION" then total += 1400 * passengerCount
        when k = "PRIORITY_BOARDING" then total += 900 * passengerCount
        otherwise raise syntax 88.900 array("FLYLO_UNKNOWN_EXTRA", k)
      end
    end
  end
  return total
::method prepare
  use arg command
  if command == .nil then return .FlyLoEngineResult~failure("BOOKING_COMMAND_REQUIRED")
  idem = command~idempotencyKey
  if idem = "" then return .FlyLoEngineResult~failure("BOOKING_IDEMPOTENCY_REQUIRED")
  existing = self~confirmedByIdempotency(idem)
  if existing <> .nil then return .FlyLoEngineResult~success(existing, "booking replay")
  details = command~details
  do required over .array~of("saleId", "offer", "passengers", "paymentAuthorizationId", "amountMinor", "currency")
    if \details~hasIndex(required) then return .FlyLoEngineResult~failure("BOOKING_FIELD_REQUIRED", required)
  end
  if details["paymentAuthorizationId"]~string = "" then return .FlyLoEngineResult~failure("PAYMENT_AUTHORITY_REQUIRED")
  if details["offer"] == .nil | \details["offer"]~isA(.Directory) then return .FlyLoEngineResult~failure("BOOKING_OFFER_REQUIRED")
  if details["passengers"] == .nil | \details["passengers"]~isA(.Array) | details["passengers"]~items < 1 then return .FlyLoEngineResult~failure("BOOKING_PASSENGERS_REQUIRED")
  passengerCount = details["passengers"]~items
  extrasForPrice = .directory~new
  if details~hasIndex("extras") then if details["extras"] <> .nil then extrasForPrice = details["extras"]
  expectedAmount = ((details["offer"]["fareMinor"] + 0) * passengerCount) + self~ancillaryMinor(extrasForPrice, passengerCount)
  if details["amountMinor"] + 0 <> expectedAmount then return .FlyLoEngineResult~failure("BOOKING_AMOUNT_TAMPERED", details["amountMinor"] || "/" || expectedAmount)
  if details["currency"]~string~upper <> details["offer"]["currency"]~string~upper then return .FlyLoEngineResult~failure("BOOKING_CURRENCY_TAMPERED")
  saleId = details["saleId"]~string
  instruction = .directory~new
  instruction["schema"] = "flylo.booking.inventory-request/0.4"
  instruction["commandId"] = command~commandId
  instruction["idempotencyKey"] = idem
  instruction["inventoryIdempotencyKey"] = "INVENTORY:" || idem
  instruction["bookingId"] = self~bookingIdFor(idem)
  instruction["bookingRef"] = self~bookingRefFor(idem, saleId)
  instruction["saleId"] = saleId
  instruction["offer"] = details["offer"]
  instruction["passengers"] = details["passengers"]
  instruction["passengerCount"] = details["passengers"]~items
  instruction["paymentAuthorizationId"] = details["paymentAuthorizationId"]
  instruction["amountMinor"] = details["amountMinor"] + 0
  instruction["currency"] = details["currency"]~string~upper
  if details~hasIndex("extras") then instruction["extras"] = details["extras"]
  else instruction["extras"] = .directory~new
  if details~hasIndex("termsVersion") then instruction["termsVersion"] = details["termsVersion"]
  else instruction["termsVersion"] = ""
  instruction["requestedAt"] = command~requestedAt
  return .FlyLoEngineResult~success(instruction, "inventory commitment required")
::method finalize
  expose bookings byIdempotency
  use arg inventoryOutcome
  if inventoryOutcome == .nil | \inventoryOutcome~isA(.Directory) then return .FlyLoEngineResult~failure("INVENTORY_OUTCOME_REQUIRED")
  if inventoryOutcome["schema"] <> "flylo.booking.inventory-outcome/0.4" then return .FlyLoEngineResult~failure("INVENTORY_OUTCOME_SCHEMA_INVALID")
  instruction = inventoryOutcome["bookingRequest"]
  if instruction == .nil | \instruction~isA(.Directory) then return .FlyLoEngineResult~failure("BOOKING_REQUEST_MISSING")
  idem = instruction["idempotencyKey"]~string
  if byIdempotency~hasIndex(idem) then return .FlyLoEngineResult~success(byIdempotency[idem], "booking replay")
  if inventoryOutcome["ok"] <> .true then return .FlyLoEngineResult~failure(inventoryOutcome["code"], inventoryOutcome["detail"])
  p = .directory~new
  p["schema"] = "flylo.booking.projection/0.4"
  p["source"] = "ENGINE_FIXTURE"
  p["status"] = "CONFIRMED"
  p["bookingId"] = instruction["bookingId"]
  p["bookingRef"] = instruction["bookingRef"]
  p["saleId"] = instruction["saleId"]
  ignore=self~noteSaleSequence(p["saleId"])
  p["idempotencyKey"] = idem
  p["inventoryIdempotencyKey"] = instruction["inventoryIdempotencyKey"]
  p["offerId"] = instruction["offer"]["offerId"]
  p["origin"] = instruction["offer"]["origin"]
  p["destination"] = instruction["offer"]["destination"]
  p["travelDate"] = instruction["offer"]["date"]
  p["flightNo"] = instruction["offer"]["flightNo"]
  p["legs"] = instruction["offer"]["legs"]
  p["passengers"] = self~passengersWithIds(instruction["passengers"])
  p["extras"] = instruction["extras"]
  p["ancillaryServices"] = .array~new
  p["termsVersion"] = instruction["termsVersion"]
  p["paymentAuthorizationId"] = instruction["paymentAuthorizationId"]
  p["amountMinor"] = instruction["amountMinor"]
  p["currency"] = instruction["currency"]
  p["confirmedAt"] = .DateTime~new~utcIsoDate
  bookings[p["bookingRef"]] = p
  byIdempotency[idem] = p
  return .FlyLoEngineResult~success(p, "booking confirmed")
::method passengersWithIds private
  use arg source
  out = .array~new
  i = 0
  do passenger over source
    i += 1
    q = .directory~new
    do k over passenger; q[k] = passenger[k]; end
    q["passengerId"] = "PAX-" || right("000" || i,3)
    q["checkedBagCount"] = 0
    out~append(q)
  end
  return out

::method addCheckedBags
  expose bookings serviceByIdempotency
  use arg bookingRef, passengerIds, quantity=1, paymentAuthorizationId="", idempotencyKey=""
  key = bookingRef~string~upper
  if \bookings~hasIndex(key) then return .FlyLoEngineResult~failure("BOOKING_NOT_FOUND", key)
  if passengerIds == .nil | \passengerIds~isA(.Array) | passengerIds~items < 1 then return .FlyLoEngineResult~failure("BOOKING_PASSENGER_SELECTION_REQUIRED")
  if \datatype(quantity,"W") | quantity < 1 | quantity > 10 then return .FlyLoEngineResult~failure("CHECKED_BAG_QUANTITY_INVALID", quantity)
  paymentAuthorizationId = paymentAuthorizationId~string~strip
  if paymentAuthorizationId = "" then return .FlyLoEngineResult~failure("ANCILLARY_PAYMENT_AUTHORITY_REQUIRED")
  idempotencyKey = idempotencyKey~string~strip
  if idempotencyKey = "" then return .FlyLoEngineResult~failure("ANCILLARY_IDEMPOTENCY_REQUIRED")
  if serviceByIdempotency~hasIndex(idempotencyKey) then return .FlyLoEngineResult~success(serviceByIdempotency[idempotencyKey], "ancillary replay")

  p = bookings[key]
  wanted = .set~new
  do id over passengerIds
    token = id~string~strip
    if token <> "" then wanted~put(token)
  end
  if wanted~items = 0 then return .FlyLoEngineResult~failure("BOOKING_PASSENGER_SELECTION_REQUIRED")
  found = .set~new
  do passenger over p["passengers"]
    pid = passenger["passengerId"]~string
    if wanted~hasIndex(pid) then found~put(pid)
  end
  if found~items <> wanted~items then return .FlyLoEngineResult~failure("BOOKING_PASSENGER_ID_INVALID")

  do passenger over p["passengers"]
    pid = passenger["passengerId"]~string
    if wanted~hasIndex(pid) then do
      current = 0
      if passenger~hasIndex("checkedBagCount") then current = passenger["checkedBagCount"] + 0
      passenger["checkedBagCount"] = current + quantity
    end
  end
  service = .directory~new
  service["schema"] = "flylo.booking.ancillary-service/0.1"
  service["serviceId"] = "SVC-" || self~safeToken(idempotencyKey)
  service["type"] = "CHECKED_BAG"
  service["bookingRef"] = key
  selected = .array~new; do id over wanted; selected~append(id); end; selected~sort
  service["passengerIds"] = selected
  service["quantityPerPassenger"] = quantity + 0
  service["unitPriceMinor"] = 4900
  service["amountMinor"] = 4900 * quantity * selected~items
  service["currency"] = "GBP"
  service["paymentAuthorizationId"] = paymentAuthorizationId
  service["idempotencyKey"] = idempotencyKey
  service["source"] = "ENGINE_FIXTURE"
  service["confirmedAt"] = .DateTime~new~utcIsoDate
  if \p~hasIndex("ancillaryServices") | p["ancillaryServices"] == .nil then p["ancillaryServices"] = .array~new
  p["ancillaryServices"]~append(service)
  p["lastAncillaryService"] = service
  bookings[key] = p
  serviceByIdempotency[idempotencyKey] = p
  return .FlyLoEngineResult~success(p, "checked baggage added")

::method applyProjection
  expose bookings byIdempotency serviceByIdempotency maxSaleSequence
  use arg p
  if p == .nil | \p~isA(.Directory) then return .FlyLoEngineResult~failure("BOOKING_PROJECTION_REQUIRED")
  if p["schema"] <> "flylo.booking.projection/0.4" then return .FlyLoEngineResult~failure("BOOKING_PROJECTION_SCHEMA_INVALID")
  /* Older v0.4 projections may predate stable passenger identities.  Assign
     deterministic identities during recovery rather than binding workspace
     commands to display order or passenger names. */
  if p~hasIndex("passengers") then do
    index=0
    do passenger over p["passengers"]
      index += 1
      if \passenger~hasIndex("passengerId") | passenger["passengerId"]~string="" then passenger["passengerId"]="PAX-" || right("000" || index,3)
      if \passenger~hasIndex("checkedBagCount") then passenger["checkedBagCount"]=0
    end
  end
  ignore=self~noteSaleSequence(p["saleId"])
  bookings[p["bookingRef"]] = p
  byIdempotency[p["idempotencyKey"]] = p
  if p~hasIndex("ancillaryServices") then do service over p["ancillaryServices"]
    if service~hasIndex("idempotencyKey") then serviceByIdempotency[service["idempotencyKey"]]=p
  end
  return .FlyLoEngineResult~success(.true)
::method lookup
  expose bookings
  use arg bookingRef, familyName = ""
  key = bookingRef~string~upper
  if \bookings~hasIndex(key) then return .FlyLoEngineResult~failure("BOOKING_NOT_FOUND", key)
  p = bookings[key]
  if familyName~string <> "" then do
    wanted = familyName~string~upper
    matched = .false
    do passenger over p["passengers"]
      if passenger~hasIndex("familyName") then if passenger["familyName"]~string~upper = wanted then matched = .true
    end
    if \matched then return .FlyLoEngineResult~failure("BOOKING_NAME_MISMATCH")
  end
  return .FlyLoEngineResult~success(p)

::class FlyLoOperationsAuthority public
::method init
  expose schedule statusByKey
  use arg scheduleArg
  if scheduleArg == .nil then raise syntax 88.900 array("FLYLO_SCHEDULE_REQUIRED")
  schedule = scheduleArg
  statusByKey = .directory~new
::method statusKey private
  use arg flightNo, travelDate
  return flightNo~string~upper || "|" || travelDate~string
::method flightStatus
  expose schedule statusByKey
  use arg flightNo, travelDate
  leg = schedule~flight(flightNo)
  if leg == .nil then return .FlyLoEngineResult~failure("FLIGHT_NOT_FOUND", flightNo)
  key = self~statusKey(flightNo, travelDate)
  status = "ON_TIME"
  if statusByKey~hasIndex(key) then status = statusByKey[key]
  d = leg~snapshot
  d["schema"] = "flylo.operations.status/0.4"
  d["source"] = "ENGINE_FIXTURE"
  d["date"] = travelDate~string
  d["status"] = status
  return .FlyLoEngineResult~success(d)
::method setFlightStatus
  expose schedule statusByKey
  use arg flightNo, travelDate, statusArg
  if schedule~flight(flightNo) == .nil then return .FlyLoEngineResult~failure("FLIGHT_NOT_FOUND", flightNo)
  status = statusArg~string~upper
  if wordpos(status, "ON_TIME DELAYED CANCELLED DIVERTED DEPARTED ARRIVED") = 0 then return .FlyLoEngineResult~failure("FLIGHT_STATUS_INVALID", status)
  statusByKey[self~statusKey(flightNo, travelDate)] = status
  return .FlyLoEngineResult~success(status)

