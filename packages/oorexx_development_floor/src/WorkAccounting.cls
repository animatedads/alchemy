/* WorkAccounting.cls
   Development Floor WLU admission and cross-resource accounting projection.

   WLU Authority remains authoritative for work entitlement, reservation,
   admission, consumption and settlement.  DFAccountingLedger records durable
   correlated usage facts (tokens, money, GPU seconds, wall time, bytes, etc.)
   but cannot grant work or alter a WLU reservation.

   The ledger's totals index is a derived in-memory projection rebuilt entirely
   from the append-only ledger at startup.  It is never an entitlement source.
*/

::class DFAccountingBuild public
::constant API_VERSION "development.floor.accounting/0.1"
::constant RECORD_FORMAT "DF_ACCOUNTING/0.1"

::class DFAccountingEvent public
::attribute sequence get
::attribute tick get
::attribute eventType get
::attribute assignmentId get
::attribute reservationId get
::attribute resourceKind get
::attribute quantity get
::attribute unit get
::attribute externalRef get
::attribute detail get

::method init
  expose sequence tick eventType assignmentId reservationId resourceKind quantity unit externalRef detail
  use strict arg sequence, tick, eventType, assignmentId="", reservationId="", resourceKind="", quantity=0, unit="", externalRef="", detail=""

/* Package-private codec.  Its methods are intentionally public on a class that
   itself is package-local.  This keeps activity dispatch safe without making
   codec internals part of the package's public class surface. */
::class DFAccountingCodec
::method encode
  use strict arg event
  return .DFAccountingBuild~RECORD_FORMAT || "|" || event~sequence || "|" || event~tick || "|" || -
    self~hex(event~eventType) || "|" || self~hex(event~assignmentId) || "|" || self~hex(event~reservationId) || "|" || -
    self~hex(event~resourceKind) || "|" || event~quantity || "|" || self~hex(event~unit) || "|" || -
    self~hex(event~externalRef) || "|" || self~hex(event~detail)

::method decode
  use strict arg line
  numeric digits 30
  parts = self~split(line, "|")
  if parts~items \= 11 then return .Array~of(.false, "field-count=" || parts~items, .nil)
  if parts[1] \= .DFAccountingBuild~RECORD_FORMAT then return .Array~of(.false, "record-format", .nil)
  if \datatype(parts[2], "W") then return .Array~of(.false, "sequence", .nil)
  if parts[2] < 1 then return .Array~of(.false, "sequence", .nil)
  if \datatype(parts[3], "W") then return .Array~of(.false, "tick", .nil)
  if \datatype(parts[8], "W") then return .Array~of(.false, "quantity", .nil)
  if parts[8] < 0 then return .Array~of(.false, "quantity", .nil)

  hexFields = .Array~of(4, 5, 6, 7, 9, 10, 11)
  do fieldIndex over hexFields
    if \self~validHex(parts[fieldIndex]) then return .Array~of(.false, "hex-field=" || fieldIndex, .nil)
  end

  event = .DFAccountingEvent~new(parts[2], parts[3], self~unhex(parts[4]), self~unhex(parts[5]), self~unhex(parts[6]), self~unhex(parts[7]), parts[8], self~unhex(parts[9]), self~unhex(parts[10]), self~unhex(parts[11]))
  return .Array~of(.true, "", event)

::method split
  use strict arg text, separator
  answer = .Array~new
  rest = text
  do forever
    p = rest~pos(separator)
    if p = 0 then do
      answer~append(rest)
      leave
    end
    answer~append(rest~left(p - 1))
    rest = rest~substr(p + separator~length)
  end
  return answer

::method hex
  use strict arg value
  return c2x(value~string)~lower

::method validHex
  use strict arg value
  if value = "" then return .true
  if value~length // 2 \= 0 then return .false
  return verify(value~lower, "0123456789abcdef") = 0

::method unhex
  use strict arg value
  if value = "" then return ""
  return x2c(value)

/* Package-private derived index.  It is rebuilt from durable events and has no
   authority to create, admit, consume or settle work. */
::class DFAccountingIndex
::method init
  expose byAssignment
  byAssignment = .Directory~new

::method add
  expose byAssignment
  use strict arg event
  if event~eventType \= "RESOURCE_USE" then return 0

  assignmentTotals = byAssignment~at(event~assignmentId)
  if assignmentTotals == .nil then do
    assignmentTotals = .Directory~new
    byAssignment[event~assignmentId] = assignmentTotals
  end

  resourceTotals = assignmentTotals~at(event~resourceKind)
  if resourceTotals == .nil then do
    resourceTotals = .Directory~new
    assignmentTotals[event~resourceKind] = resourceTotals
  end

  current = resourceTotals~at(event~unit)
  if current == .nil then current = 0
  resourceTotals[event~unit] = current + event~quantity
  return resourceTotals[event~unit]

::method totalFor
  expose byAssignment
  use strict arg assignmentId, resourceKind, unit
  assignmentTotals = byAssignment~at(assignmentId)
  if assignmentTotals == .nil then return 0
  resourceTotals = assignmentTotals~at(translate(resourceKind))
  if resourceTotals == .nil then return 0
  total = resourceTotals~at(translate(unit))
  if total == .nil then return 0
  return total

::class DFAccountingLedger public
::attribute path get
::attribute sequence get

::method init
  expose path sequence codec totalsIndex
  use strict arg path
  path = path~string~strip
  if path = "" then raise syntax 93.900 array("Accounting ledger path must not be empty")
  sequence = 0
  codec = .DFAccountingCodec~new
  totalsIndex = .DFAccountingIndex~new
  recovered = self~readAll
  if \recovered[1] then raise syntax 93.900 array("Cannot recover Development Floor accounting ledger", recovered[2])
  sequence = recovered[3]~items
  do event over recovered[3]
    ignore = totalsIndex~add(event)
  end

::method append
  expose path sequence codec totalsIndex
  use strict arg eventType, assignmentId="", reservationId="", resourceKind="", quantity=0, unit="", externalRef="", detail=""
  guard on
  if \datatype(quantity, "W") then raise syntax 93.900 array("Accounting quantity must be a whole number", quantity)
  if quantity < 0 then raise syntax 93.900 array("Accounting quantity must not be negative", quantity)
  sequence += 1
  numeric digits 30
  tick = time("F")
  event = .DFAccountingEvent~new(sequence, tick, translate(eventType~string~strip), assignmentId~string, reservationId~string, translate(resourceKind~string~strip), quantity, translate(unit~string~strip), externalRef~string, detail~string)
  line = codec~encode(event)
  stream = .Stream~new(path)
  status = stream~open("write append")
  if status \= "READY:" then do
    sequence -= 1
    raise syntax 93.900 array("Cannot open Development Floor accounting ledger", path, status)
  end
  ignore = stream~lineOut(line)
  ignore = stream~close
  ignore = totalsIndex~add(event)
  return event

::method recordResourceUse
  use strict arg assignmentId, reservationId, resourceKind, quantity, unit, externalRef="", detail=""
  return self~append("RESOURCE_USE", assignmentId, reservationId, resourceKind, quantity, unit, externalRef, detail)

::method readAll
  expose path codec
  events = .Array~new
  stream = .Stream~new(path)
  if stream~query("exists") = "" then return .Array~of(.true, "", events)
  status = stream~open("read")
  if status \= "READY:" then return .Array~of(.false, "open:" || status, events)
  expected = 1
  do while stream~lines > 0
    line = stream~lineIn
    decoded = codec~decode(line)
    if \decoded[1] then do
      ignore = stream~close
      return .Array~of(.false, decoded[2], events)
    end
    event = decoded[3]
    if event~sequence \= expected then do
      ignore = stream~close
      return .Array~of(.false, "sequence expected=" || expected || " actual=" || event~sequence, events)
    end
    events~append(event)
    expected += 1
  end
  ignore = stream~close
  return .Array~of(.true, "", events)

::method eventsForAssignment
  use strict arg assignmentId
  all = self~readAll
  if \all[1] then raise syntax 93.900 array("Accounting ledger read failed", all[2])
  answer = .Array~new
  do event over all[3]
    if event~assignmentId = assignmentId then answer~append(event)
  end
  return answer

::method totalFor
  expose totalsIndex
  use strict arg assignmentId, resourceKind, unit
  return totalsIndex~totalFor(assignmentId, resourceKind, unit)

::class DFWLUControl public
::attribute authority get
::attribute accountingLedger get

::method init
  expose authority accountingLedger reservations admitted
  use strict arg authority, accountingLedger
  if authority == .nil then raise syntax 93.900 array("WLU authority is required")
  if \authority~hasMethod("RESERVEDEMAND") then raise syntax 93.900 array("WLU authority lacks RESERVEDEMAND")
  if \authority~hasMethod("ADMIT") then raise syntax 93.900 array("WLU authority lacks ADMIT")
  if \authority~hasMethod("CONSUME") then raise syntax 93.900 array("WLU authority lacks CONSUME")
  if \authority~hasMethod("SETTLE") then raise syntax 93.900 array("WLU authority lacks SETTLE")
  if \authority~hasMethod("RELEASE") then raise syntax 93.900 array("WLU authority lacks RELEASE")
  if accountingLedger == .nil then raise syntax 93.900 array("Development Floor accounting ledger is required")
  authority = authority
  accountingLedger = accountingLedger
  reservations = .Directory~new
  admitted = .Directory~new

::method reserveAssignment
  expose authority accountingLedger reservations admitted
  use strict arg assignment, expectedMicroWlu, ceilingMicroWlu, targetSeconds=0, ttlSeconds=30, requestId=""
  if assignment == .nil then raise syntax 93.900 array("Assignment is required for WLU reservation")
  if assignment~botProfileId = "" then raise syntax 93.900 array("Assignment execution bot must be bound before WLU reservation", assignment~id)
  demand = .WLUWorkDemand~new(expectedMicroWlu, ceilingMicroWlu, targetSeconds)
  identity = "bot:" || assignment~botProfileId
  scope = "project:" || assignment~project || "/package:" || assignment~packageId || "/assignment:" || assignment~id
  if requestId = "" then requestId = "df-wlu-" || assignment~id
  wluReply = authority~reserveDemand(identity, scope, demand, ttlSeconds, requestId)
  if \wluReply~ok then return wluReply
  reservation = wluReply~value
  reservations[assignment~id] = reservation
  admitted[assignment~id] = .false
  assignment~bindWLUReservation(reservation~reservationId)
  ignore = accountingLedger~append("WLU_RESERVED", assignment~id, reservation~reservationId, "WLU", ceilingMicroWlu, "MICRO_WLU", requestId, "expected=" || expectedMicroWlu || " target-seconds=" || targetSeconds)
  return wluReply

::method admitAssignment
  expose authority accountingLedger reservations admitted
  use strict arg assignment
  reservation = reservations~at(assignment~id)
  if reservation == .nil then raise syntax 93.900 array("Assignment has no active WLU reservation", assignment~id)
  wluReply = authority~admit(reservation)
  if \wluReply~ok then return wluReply
  admitted[assignment~id] = .true
  assignment~markWLUAdmitted
  ignore = accountingLedger~append("WLU_ADMITTED", assignment~id, reservation~reservationId, "WLU", 0, "MICRO_WLU", "", "")
  return wluReply

::method requireAdmitted
  expose reservations admitted
  use strict arg assignment
  reservation = reservations~at(assignment~id)
  if reservation == .nil then raise syntax 93.900 array("Substantive work requires a WLU reservation", assignment~id)
  flag = admitted~at(assignment~id)
  if flag == .nil then flag = .false
  if \flag then raise syntax 93.900 array("Substantive work requires WLU admission", assignment~id)
  return reservation

::method consumeAssignment
  expose authority accountingLedger reservations admitted
  use strict arg assignment, microWlu, operationId=""
  reservation = self~requireAdmitted(assignment)
  wluReply = authority~consume(reservation, microWlu, operationId)
  if \wluReply~ok then return wluReply
  ignore = accountingLedger~append("WLU_CONSUMED", assignment~id, reservation~reservationId, "WLU", microWlu, "MICRO_WLU", operationId, "")
  return wluReply

::method settleAssignment
  expose authority accountingLedger reservations admitted
  use strict arg assignment, actualMicroWlu=.nil
  reservation = reservations~at(assignment~id)
  if reservation == .nil then raise syntax 93.900 array("Assignment has no WLU reservation to settle", assignment~id)
  wluReply = authority~settle(reservation, actualMicroWlu)
  if \wluReply~ok then return wluReply
  amount = actualMicroWlu
  if amount == .nil then amount = 0
  ignore = accountingLedger~append("WLU_SETTLED", assignment~id, reservation~reservationId, "WLU", amount, "MICRO_WLU", "", wluReply~value~string)
  reservations~remove(assignment~id)
  admitted~remove(assignment~id)
  assignment~clearWLUReservation("SETTLED")
  return wluReply

::method releaseAssignment
  expose authority accountingLedger reservations admitted
  use strict arg assignment
  reservation = reservations~at(assignment~id)
  if reservation == .nil then raise syntax 93.900 array("Assignment has no WLU reservation to release", assignment~id)
  wluReply = authority~release(reservation)
  if \wluReply~ok then return wluReply
  ignore = accountingLedger~append("WLU_RELEASED", assignment~id, reservation~reservationId, "WLU", 0, "MICRO_WLU", "", wluReply~value~string)
  reservations~remove(assignment~id)
  admitted~remove(assignment~id)
  assignment~clearWLUReservation("RELEASED")
  return wluReply

::method recordResourceUse
  expose accountingLedger reservations
  use strict arg assignment, resourceKind, quantity, unit, externalRef="", detail=""
  reservation = reservations~at(assignment~id)
  reservationId = ""
  if reservation <> .nil then reservationId = reservation~reservationId
  return accountingLedger~recordResourceUse(assignment~id, reservationId, resourceKind, quantity, unit, externalRef, detail)

::method reservationFor
  expose reservations
  use strict arg assignmentId
  return reservations~at(assignmentId)

::requires "WorkLoadUnits.cls"
