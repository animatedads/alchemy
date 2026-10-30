/* Mini NotNotes temporal authority evidence persistence. */
root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then root = "tmp-temporal-evidence"
address command "rm -rf " || root

app = .MiniNotesApp~new(root)
app~timeService(.DeterministicTimeGateway~new)

fields = .Array~new
spec = .Directory~new
spec["NAME"] = "DueDate"; spec["LABEL"] = "Due Date"; spec["TYPE"] = "DATE"
fields~append(spec)
spec = .Directory~new
spec["NAME"] = "MeetingAt"; spec["LABEL"] = "Meeting At"; spec["TYPE"] = "DATETIME"; spec["TIME_ZONE"] = "Europe/London"
fields~append(spec)
spec = .Directory~new
spec["NAME"] = "OptionalAt"; spec["LABEL"] = "Optional At"; spec["TYPE"] = "DATETIME"
fields~append(spec)
app~installUserFormat("Timed TPS Evidence", fields)

values = .Directory~new
values["DueDate"] = "2026-10-31"
values["MeetingAt"] = "2026-10-31T12:00:00"
values["OptionalAt"] = ""
document = app~createUserDocument("Timed TPS Evidence", fields, values)
call assertNotNil document, "temporal document created"

civil = app~temporalEvidenceFor(document~DocKey, "DueDate")
call assertEqual civil["KIND"], "CIVIL_DATE", "civil date kind retained"
call assertEqual civil["VALUE"], "2026-10-31", "civil canonical value retained"

zoned = app~temporalEvidenceFor(document~DocKey, "MeetingAt")
call assertEqual zoned["KIND"], "ZONED_LOCAL_DATETIME", "zoned kind retained"
call assertEqual zoned["ZONE"], "Europe/London", "zone retained"
call assertEqual zoned["INSTANT_POSIX_SECONDS"], 1793448000, "resolved instant retained"
call assertEqual zoned["TZDB_EDITION"], "TEST-2026A", "tzdb authority retained"
call assertEqual zoned["RESOLUTION"], "UNIQUE", "resolution retained"
call assertEqual app~temporalEvidenceFor(document~DocKey, "OptionalAt"), .nil, "blank datetime invents no evidence"

projection = app~semanticDocumentProjection(document)
found = .false
do descriptor over projection["FIELDS"]
  if descriptor["NAME"]~upper = "MEETINGAT" then do
    call assertEqual descriptor["TIME_ZONE"], "Europe/London", "projection keeps zone policy"
    call assertEqual descriptor["TEMPORAL_EVIDENCE"]["TZDB_EDITION"], "TEST-2026A", "projection exposes accepted temporal evidence"
    found = .true
  end
end
call assertEqual found, .true, "zoned field descriptor found"

fresh = .MiniNotesApp~new(root)
freshEvidence = fresh~temporalEvidenceFor(document~DocKey, "MeetingAt")
call assertNotNil freshEvidence, "evidence reloaded without Time Service"
call assertEqual freshEvidence["INSTANT_POSIX_SECONDS"], 1793448000, "instant survives restart"
call assertEqual freshEvidence["TZDB_EDITION"], "TEST-2026A", "edition survives restart"

freshDoc = fresh~byKey(document~DocKey)
call assertEqual fresh~setUserDocumentField(freshDoc, "MeetingAt", "2026-11-01T12:00:00"), .false, "new temporal mutation fails closed without Time Service"
unchanged = fresh~temporalEvidenceFor(document~DocKey, "MeetingAt")
call assertEqual unchanged["INSTANT_POSIX_SECONDS"], 1793448000, "failed mutation preserves prior accepted evidence"

address command "rm -rf " || root
say "PASS Mini NotNotes temporal evidence persistence / semantic projection / fail-closed mutation"
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

::class DeterministicTimeGateway
::method normalizeDate
  use strict arg supplied
  outcome = .Directory~new
  if supplied~string~strip = "" then do
    outcome["STATUS"] = "EMPTY"; outcome["VALUE"] = ""; return outcome
  end
  outcome["STATUS"] = "VALID"
  outcome["VALUE"] = supplied~string~strip
  outcome["KIND"] = "CIVIL_DATE"
  return outcome

::method normalizeDateTime
  use strict arg supplied, zone = "", policy = ""
  outcome = .Directory~new
  if supplied~string~strip = "" then do
    outcome["STATUS"] = "EMPTY"; outcome["VALUE"] = ""; return outcome
  end
  outcome["STATUS"] = "VALID"
  outcome["VALUE"] = supplied~string~strip
  if zone~string~strip = "" then do
    outcome["KIND"] = "FLOATING_LOCAL_DATETIME"
    return outcome
  end
  outcome["KIND"] = "ZONED_LOCAL_DATETIME"
  outcome["ZONE"] = zone
  outcome["INSTANT_POSIX_SECONDS"] = 1793448000
  outcome["TZDB_EDITION"] = "TEST-2026A"
  outcome["RESOLUTION"] = "UNIQUE"
  return outcome

::requires 'src/MiniNotesApp.cls'
