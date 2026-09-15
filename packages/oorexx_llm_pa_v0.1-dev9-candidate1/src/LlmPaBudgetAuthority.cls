/* PA external-reasoning authority.
 * WLU is the work ledger. Rates value settled WLU; the hourly allowance is a
 * separate money ledger used only for admission protection. */

::class LlmPaExternalBudgetAuthority public
::attribute policy get
::attribute ledger get
::attribute ledgerPath get

::method init
  expose policy clock rates windows reservations ledger ledgerPath sequence
  use arg policyArg, clockArg = .nil, ledgerPathArg = ""
  policy = policyArg
  clock = clockArg
  rates = .table~new
  windows = .table~new
  reservations = .table~new
  ledger = .array~new
  ledgerPath = ledgerPathArg~string~strip
  sequence = 0
  if ledgerPath <> "" then self~loadLedger

::method registerRate public
  expose rates
  use arg providerArg, modelArg, microDollarsPerWluArg, versionArg = "1"
  provider = providerArg~string~strip~lower
  model = modelArg~string~strip
  if provider = "" | model = "" then return .LlmPaResult~failure("PA_RATE_KEY_REQUIRED")
  if \datatype(microDollarsPerWluArg, "W") | microDollarsPerWluArg < 0 then return .LlmPaResult~failure("PA_RATE_INVALID")
  key = provider || "|" || model
  rate = .directory~new
  rate["provider"] = provider
  rate["model"] = model
  rate["microdollars_per_wlu"] = microDollarsPerWluArg
  rate["rate_book_version"] = versionArg~string~strip
  rates[key] = rate
  return .LlmPaResult~success(rate)

::method reserve public
  expose policy rates windows reservations ledger sequence
  use arg providerArg, modelArg, estimatedMicroWluArg, requestIdArg = ""
  if \datatype(estimatedMicroWluArg, "W") | estimatedMicroWluArg < 1 then return .LlmPaResult~failure("PA_WLU_ESTIMATE_INVALID")
  key = providerArg~string~strip~lower || "|" || modelArg~string~strip
  rate = rates[key]
  if rate == .nil then return .LlmPaResult~failure("PA_RATE_NOT_CONFIGURED", key)
  windowId = self~windowId
  state = self~windowState(windowId)
  if state["frozen"] then return .LlmPaResult~failure("PA_WINDOW_FROZEN", windowId)
  estimatedCost = self~cost(estimatedMicroWluArg, rate["microdollars_per_wlu"])
  if state["settled_micro_wlu"] + state["reserved_micro_wlu"] + estimatedMicroWluArg > policy~hourlyMicroWlu then return .LlmPaResult~failure("PA_WLU_HOURLY_CEILING", policy~hourlyMicroWlu)
  if state["settled_microdollars"] + state["reserved_microdollars"] + estimatedCost > policy~budgetMicroDollars then return .LlmPaResult~failure("PA_MONEY_HOURLY_CEILING", policy~budgetMicroDollars)
  sequence += 1
  reservationId = "pa-budget-" || sequence
  reservation = .directory~new
  reservation["reservation_id"] = reservationId
  reservation["provider"] = rate["provider"]
  reservation["model"] = modelArg~string~strip
  reservation["rate_book_version"] = rate["rate_book_version"]
  reservation["microdollars_per_wlu"] = rate["microdollars_per_wlu"]
  reservation["window_id"] = windowId
  reservation["estimated_micro_wlu"] = estimatedMicroWluArg
  reservation["estimated_microdollars"] = estimatedCost
  reservation["request_id"] = requestIdArg~string
  reservation["status"] = "RESERVED"
  reservations[reservationId] = reservation
  state["reserved_micro_wlu"] += estimatedMicroWluArg
  state["reserved_microdollars"] += estimatedCost
  self~recordEvent("RESERVE", reservation)
  return .LlmPaResult~success(reservation)

::method settle public
  expose policy reservations windows ledger
  use arg reservationIdArg, actualMicroWluArg
  reservation = reservations[reservationIdArg~string]
  if reservation == .nil then return .LlmPaResult~failure("PA_RESERVATION_NOT_FOUND")
  if reservation["status"] \= "RESERVED" then return .LlmPaResult~failure("PA_RESERVATION_NOT_ACTIVE")
  if \datatype(actualMicroWluArg, "W") | actualMicroWluArg < 0 then return .LlmPaResult~failure("PA_ACTUAL_WLU_INVALID")
  if actualMicroWluArg > reservation["estimated_micro_wlu"] then do
    state = self~windowState(reservation["window_id"])
    actualCost = self~cost(actualMicroWluArg, reservation["microdollars_per_wlu"])
    state["reserved_micro_wlu"] -= reservation["estimated_micro_wlu"]
    state["reserved_microdollars"] -= reservation["estimated_microdollars"]
    state["settled_micro_wlu"] += actualMicroWluArg
    state["settled_microdollars"] += actualCost
    state["frozen"] = .true
    reservation["actual_micro_wlu"] = actualMicroWluArg
    reservation["actual_microdollars"] = actualCost
    reservation["status"] = "OVERRUN"
    self~recordEvent("OVERRUN", reservation)
    return .LlmPaResult~failure("PA_WLU_OVERRUN_WINDOW_FROZEN", reservation)
  end
  actualCost = self~cost(actualMicroWluArg, reservation["microdollars_per_wlu"])
  state = self~windowState(reservation["window_id"])
  state["reserved_micro_wlu"] -= reservation["estimated_micro_wlu"]
  state["reserved_microdollars"] -= reservation["estimated_microdollars"]
  state["settled_micro_wlu"] += actualMicroWluArg
  state["settled_microdollars"] += actualCost
  reservation["actual_micro_wlu"] = actualMicroWluArg
  reservation["actual_microdollars"] = actualCost
  reservation["status"] = "SETTLED"
  self~recordEvent("SETTLE", reservation)
  return .LlmPaResult~success(reservation)

::method release public
  expose reservations ledger
  use arg reservationIdArg
  reservation = reservations[reservationIdArg~string]
  if reservation == .nil then return .LlmPaResult~failure("PA_RESERVATION_NOT_FOUND")
  if reservation["status"] \= "RESERVED" then return .LlmPaResult~failure("PA_RESERVATION_NOT_ACTIVE")
  state = self~windowState(reservation["window_id"])
  state["reserved_micro_wlu"] -= reservation["estimated_micro_wlu"]
  state["reserved_microdollars"] -= reservation["estimated_microdollars"]
  reservation["status"] = "RELEASED"
  self~recordEvent("RELEASE", reservation)
  return .LlmPaResult~success(reservation)

::method snapshot public
  use arg windowArg = ""
  if windowArg = "" then windowArg = self~windowId
  return .LlmPaResult~success(self~windowState(windowArg))

::method cost private
  use arg microWlu, microDollarsPerWlu
  return .WLUUnits~ceilDivide(microWlu * microDollarsPerWlu, 1000000)

::method windowId private
  /* Fixed UTC clock-hour bucket; this is not a rolling 3600-second window. */
  return trunc(self~nowMicros / 3600000000)

::method recordEvent private
  expose ledger ledgerPath
  use arg eventType, reservation
  event = .directory~new
  event["event"] = eventType
  event["reservation_id"] = reservation["reservation_id"]
  event["window_id"] = reservation["window_id"]
  event["provider"] = reservation["provider"]
  event["model"] = reservation["model"]
  event["rate_book_version"] = reservation["rate_book_version"]
  event["microdollars_per_wlu"] = reservation["microdollars_per_wlu"]
  event["estimated_micro_wlu"] = reservation["estimated_micro_wlu"]
  event["estimated_microdollars"] = reservation["estimated_microdollars"]
  if eventType = "SETTLE" | eventType = "OVERRUN" then do
    event["actual_micro_wlu"] = reservation["actual_micro_wlu"]
    event["actual_microdollars"] = reservation["actual_microdollars"]
  end
  ledger~append(event)
  if ledgerPath <> "" then do
    call lineout ledgerPath, .JSON~toJSON(event)
    /* Close after every event so a daemon restart can replay committed work. */
    call lineout ledgerPath
  end

::method loadLedger private
  expose ledgerPath ledger windows reservations sequence
  signal on syntax name badLedger
  ignore = stream(ledgerPath, "c", "open read")
  line = linein(ledgerPath)
  do while line <> ""
    event = .JSON~fromJSON(line)
    /* Tolerate a non-event JSON value, but always advance the reader. */
    if \event~isa(.Directory) then do
      line = linein(ledgerPath)
      iterate
    end
    ledger~append(event)
    id = event["reservation_id"]~string
    if id <> "" then do
      reservation = reservations[id]
      if event["event"] = "RESERVE" then do
        reservation = .directory~new
        reservation["reservation_id"] = id
        reservation["provider"] = event["provider"]
        reservation["model"] = event["model"]
        reservation["rate_book_version"] = event["rate_book_version"]
        reservation["microdollars_per_wlu"] = event["microdollars_per_wlu"]
        reservation["window_id"] = event["window_id"]
        reservation["estimated_micro_wlu"] = event["estimated_micro_wlu"]
        reservation["estimated_microdollars"] = event["estimated_microdollars"]
        reservation["status"] = "RESERVED"
        reservations[id] = reservation
        state = self~windowState(event["window_id"])
        state["reserved_micro_wlu"] += event["estimated_micro_wlu"]
        state["reserved_microdollars"] += event["estimated_microdollars"]
      end
      else if event["event"] = "SETTLE" then do
        if reservation <> .nil then do
          state = self~windowState(event["window_id"])
          state["reserved_micro_wlu"] -= reservation["estimated_micro_wlu"]
          state["reserved_microdollars"] -= reservation["estimated_microdollars"]
          state["settled_micro_wlu"] += event["actual_micro_wlu"]
          state["settled_microdollars"] += event["actual_microdollars"]
          reservation["actual_micro_wlu"] = event["actual_micro_wlu"]
          reservation["actual_microdollars"] = event["actual_microdollars"]
          reservation["status"] = "SETTLED"
        end
      end
      else if event["event"] = "RELEASE" then do
        if reservation <> .nil then do
          state = self~windowState(event["window_id"])
          state["reserved_micro_wlu"] -= reservation["estimated_micro_wlu"]
          state["reserved_microdollars"] -= reservation["estimated_microdollars"]
          reservation["status"] = "RELEASED"
        end
      end
      number = id~substr(11)
      if datatype(number, "W") & number > sequence then sequence = number
    end
    line = linein(ledgerPath)
  end
  ignore = stream(ledgerPath, "c", "close")
  signal off syntax
  return
badLedger:
  signal off syntax
  ignore = stream(ledgerPath, "c", "close")
  raise syntax 88.900 array("PA budget ledger is malformed; refusing startup", ledgerPath)

::method nowMicros private
  expose clock
  if clock \== .nil then do
    if clock~hasMethod("ABSOLUTEMICROSECONDS") then return clock~absoluteMicroseconds
    return clock~microseconds
  end
  return .LlmPaClock~absoluteMicroseconds

::method windowState private
  expose windows
  use arg id
  state = windows[id]
  if state == .nil then do
    state = .directory~new
    state["window_id"] = id
    state["reserved_micro_wlu"] = 0
    state["settled_micro_wlu"] = 0
    state["reserved_microdollars"] = 0
    state["settled_microdollars"] = 0
    state["frozen"] = .false
    windows[id] = state
  end
  return state

::requires "LlmPaBudget.cls"
::requires "WorkLoadUnits.cls"
::requires "json.cls"
