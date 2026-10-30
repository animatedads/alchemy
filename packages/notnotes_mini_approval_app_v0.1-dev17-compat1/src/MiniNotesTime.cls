/* Mini NotNotes temporal integration.
 * NotNotes owns field semantics; Single Time Service owns civil/timezone rules;
 * ConnectSelector owns how a zoned time request reaches the service.
 */

::class MiniNotesTimeReply public
::attribute ok get
::attribute fault get
::method init
  expose ok replyValue fault
  use strict arg ok, newValue = .nil, fault = .nil
  replyValue = newValue
::method result
  expose replyValue
  return replyValue

/* Direct-call endpoint implementing only the Time Service operations NotNotes uses. */
::class MiniNotesTimeDirectEndpoint public
::method init
  expose service
  use strict arg service

::method request
  expose service
  use strict arg operation, params = .nil
  if params == .nil then params = .Directory~new
  signal on syntax name RequestFailed
  select
    when operation == "time.resolveIsoLocal" then do
      resolution = service~resolveIsoLocal(params["zone"], params["local"])
      return .MiniNotesTimeReply~new(.true, resolution)
    end
    when operation == "time.zoneMetadata" then do
      metadata = service~zoneMetadata(params["zone"])
      return .MiniNotesTimeReply~new(.true, metadata)
    end
    otherwise return .MiniNotesTimeReply~new(.false, .nil, "UNSUPPORTED_OPERATION")
  end
RequestFailed:
  say "MiniNotesTime direct request failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  return .MiniNotesTimeReply~new(.false, .nil, condition("D"))

::method notify
  use strict arg operation, params = .nil
  return .false

/* NotNotes-facing temporal service boundary. */
::class MiniNotesTimeGateway public
::method init
  expose selector destination
  use strict arg newSelector, newDestination = "TIME"
  selector = newSelector
  destination = newDestination~string~upper

::method direct class
  use strict arg service, destination = "TIME"
  policy = .ConnectRoutePolicy~new
  policy~allow("time.resolveIsoLocal", "REQUEST", "DIRECT", destination)
  policy~allow("time.zoneMetadata", "REQUEST", "DIRECT", destination)
  selector = .ConnectSelector~new(policy)
  endpoint = .MiniNotesTimeDirectEndpoint~new(service)
  selector~register("DIRECT", .ConnectCallAdapter~new(endpoint, "DIRECT", destination), destination)
  return self~new(selector, destination)

/* Validate and canonicalise a civil date without inventing an instant. */
::method normalizeDate
  use strict arg value
  resultObject = .Directory~new
  text = value~string~strip
  if text == "" then do
    resultObject["STATUS"] = "EMPTY"
    resultObject["VALUE"] = ""
    return resultObject
  end
  signal on syntax name BadDate
  reading = .IsoCivilClock~parseLocal(text || "T00:00:00")
  canonical = .IsoCivilClock~formatLocal(reading)~left(10)
  signal off syntax
  resultObject["STATUS"] = "VALID"
  resultObject["VALUE"] = canonical
  resultObject["KIND"] = "CIVIL_DATE"
  return resultObject
BadDate:
  say "MiniNotesTime invalid date rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "INVALID"
  resultObject["DETAIL"] = condition("D")
  return resultObject

/* Validate a floating local datetime, or resolve it through ConnectSelector when zoned. */
::method normalizeDateTime
  expose selector destination
  use strict arg value, zone = "", ambiguityPolicy = ""
  resultObject = .Directory~new
  text = value~string~strip
  if text == "" then do
    resultObject["STATUS"] = "EMPTY"
    resultObject["VALUE"] = ""
    return resultObject
  end
  signal on syntax name BadLocal
  reading = .IsoCivilClock~parseLocal(text)
  canonical = .IsoCivilClock~formatLocal(reading)
  signal off syntax
  if zone~string~strip == "" then do
    resultObject["STATUS"] = "VALID"
    resultObject["VALUE"] = canonical
    resultObject["KIND"] = "FLOATING_LOCAL_DATETIME"
    return resultObject
  end

  params = .Directory~new
  params["zone"] = zone
  params["local"] = canonical
  intent = .ConnectIntent~new("time.resolveIsoLocal", "REQUEST", "IMMEDIATE", "AUTO", destination)
  callResult = selector~execute(intent, params)
  if \callResult~ok then do
    resultObject["STATUS"] = "SERVICE_ERROR"
    resultObject["DETAIL"] = callResult~code || ": " || callResult~detail
    return resultObject
  end
  resolution = callResult~value
  status = resolution~status
  if status == "GAP" then do
    resultObject["STATUS"] = "GAP"
    resultObject["DETAIL"] = "Local civil time does not exist in " || zone
    return resultObject
  end
  chosen = .nil
  if status == "FOLD" then do
    policy = ambiguityPolicy~string~upper~strip
    if policy \== "EARLIER" then do
      if policy \== "LATER" then do
        resultObject["STATUS"] = "AMBIGUOUS"
        resultObject["DETAIL"] = "Local civil time is ambiguous; choose EARLIER or LATER"
        return resultObject
      end
    end
    chosen = resolution~choose(policy)
  end
  else chosen = resolution~choose("ONLY")

  metaParams = .Directory~new
  metaParams["zone"] = zone
  metaIntent = .ConnectIntent~new("time.zoneMetadata", "REQUEST", "IMMEDIATE", "AUTO", destination)
  metaResult = selector~execute(metaIntent, metaParams)
  edition = ""
  if metaResult~ok then edition = metaResult~value["edition"]
  resultObject["STATUS"] = "VALID"
  resultObject["VALUE"] = canonical
  resultObject["KIND"] = "ZONED_LOCAL_DATETIME"
  resultObject["ZONE"] = zone
  resultObject["INSTANT_POSIX_SECONDS"] = chosen~ticks
  resultObject["TZDB_EDITION"] = edition
  resultObject["RESOLUTION"] = status
  return resultObject
BadLocal:
  say "MiniNotesTime invalid datetime rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  signal off syntax
  resultObject["STATUS"] = "INVALID"
  resultObject["DETAIL"] = condition("D")
  return resultObject

::requires 'vendor/connect/ConnectSelector.cls'
::requires 'vendor/time/src/TzifZoneProvider.cls'
::requires 'vendor/time/src/SingleTime.cls'
