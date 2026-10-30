/* Mini NotNotes date/time field integration with Single Time Service + ConnectSelector. */
root = "tmp-time-service-fields-" || random(10000,99999)
address command "rm -rf " || root

provider = .TzifZoneProvider~new("vendor/time/fixtures", "2025b")
timeService = .SingleTimeService~new
timeService~registerZone(provider~load("Europe/London"))

policy = .ConnectRoutePolicy~new
policy~allow("time.resolveIsoLocal", "REQUEST", "DIRECT", "TIME")
policy~allow("time.zoneMetadata", "REQUEST", "DIRECT", "TIME")
selector = .ConnectSelector~new(policy)
endpoint = .MiniNotesTimeDirectEndpoint~new(timeService)
selector~register("DIRECT", .ConnectCallAdapter~new(endpoint, "DIRECT", "TIME"), "TIME")
gateway = .MiniNotesTimeGateway~new(selector, "TIME")

explain = selector~explain(.ConnectIntent~new("time.resolveIsoLocal", "REQUEST", "IMMEDIATE", "AUTO", "TIME"))
call assertEqual explain["ok"], .true, "selector route available"
call assertEqual explain["provider"], "DIRECT", "selector chooses direct route"

app = .MiniNotesApp~new(root)
app~timeService(gateway)

fields = .Array~new
spec = .Directory~new
spec["NAME"] = "DueDate"
spec["LABEL"] = "Due Date"
spec["TYPE"] = "DATE"
fields~append(spec)
spec = .Directory~new
spec["NAME"] = "MeetingAt"
spec["LABEL"] = "Meeting At"
spec["TYPE"] = "DATETIME"
spec["TIME_ZONE"] = "Europe/London"
fields~append(spec)
spec = .Directory~new
spec["NAME"] = "FoldWithPolicy"
spec["LABEL"] = "Fold With Policy"
spec["TYPE"] = "DATETIME"
spec["TIME_ZONE"] = "Europe/London"
spec["AMBIGUITY_POLICY"] = "EARLIER"
fields~append(spec)
app~installUserFormat("Timed TPS", fields)

values = .Directory~new
values["DueDate"] = "2026-10-31"
values["MeetingAt"] = "2026-10-31T12:00:00"
values["FoldWithPolicy"] = "2026-10-25T01:30:00"
document = app~createUserDocument("Timed TPS", fields, values)
call assertNotNil document, "valid temporal document created"
call assertEqual document~field("DueDate"), "2026-10-31", "date canonical"
call assertEqual document~field("MeetingAt"), "2026-10-31T12:00:00", "datetime canonical"
call assertEqual document~field("FoldWithPolicy"), "2026-10-25T01:30:00", "fold accepted by declared policy"

call assertEqual app~setUserDocumentField(document, "DueDate", "2026-02-29"), .false, "invalid Gregorian date rejected"
call assertEqual app~setUserDocumentField(document, "MeetingAt", "2026-03-29T01:30:00"), .false, "DST gap rejected"
call assertEqual app~setUserDocumentField(document, "MeetingAt", "2026-10-25T01:30:00"), .false, "DST fold rejected without policy"
call assertEqual app~setUserDocumentField(document, "FoldWithPolicy", "2026-10-25T01:30:00"), .true, "DST fold resolved with policy"

projection = app~semanticDocumentProjection(document)
foundZone = .false
foundDate = .false
do descriptor over projection["FIELDS"]
  if descriptor["NAME"]~upper == "DUEDATE" then do
    call assertEqual descriptor["SEMANTIC_TYPE"], "DATE", "date semantic projection"
    foundDate = .true
  end
  if descriptor["NAME"]~upper == "MEETINGAT" then do
    call assertEqual descriptor["TIME_ZONE"], "Europe/London", "timezone semantic projection"
    foundZone = .true
  end
end
call assertEqual foundDate, .true, "date descriptor found"
call assertEqual foundZone, .true, "zoned descriptor found"

fresh = .MiniNotesApp~new(root)
fresh~timeService(gateway)
freshFields = fresh~userFormatFields("Timed TPS")
call assertEqual freshFields[2]["TIME_ZONE"], "Europe/London", "timezone persisted"
call assertEqual freshFields[3]["AMBIGUITY_POLICY"], "EARLIER", "ambiguity policy persisted"
freshDoc = fresh~byKey(document~DocKey)
call assertNotNil freshDoc, "temporal document reloaded"
call assertEqual freshDoc~field("MeetingAt"), "2026-10-31T12:00:00", "datetime survives reload"

/* A temporal write without the required Time Service boundary fails closed. */
withoutTime = .MiniNotesApp~new(root)
withoutDoc = withoutTime~byKey(document~DocKey)
call assertEqual withoutTime~setUserDocumentField(withoutDoc, "DueDate", "2027-01-01"), .false, "temporal mutation requires Time Service"

address command "rm -rf " || root
say "PASS Mini NotNotes Time Service / ConnectSelector temporal field semantics"
exit 0

assertEqual: procedure
  use strict arg actual, expected, label
  if actual == expected then return
  say "FAIL:" label "expected=" expected "actual=" actual
  exit 1

assertNotNil: procedure
  use strict arg actual, label
  if actual \== .nil then return
  say "FAIL:" label "was .nil"
  exit 1

::requires 'src/MiniNotesApp.cls'
