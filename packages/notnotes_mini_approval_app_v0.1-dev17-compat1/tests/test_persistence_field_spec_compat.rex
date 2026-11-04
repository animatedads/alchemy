/* Legacy/current persisted field-spec decoding compatibility. */
root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then root = "tmp-field-spec-compat"
address command "rm -rf " || root
persistence = .MiniNotesPersistence~new(root)
legacy = c2x("Name") || ":" || c2x("Name") || ":" || c2x("TEXT") || ":::::::"
fields = persistence~decodeFieldSpecs(legacy)
call assertEqual fields~items, 1, "legacy row decoded"
call assertEqual fields[1]["NAME"], "Name", "legacy name"
call assertEqual fields[1]["TYPE"], "TEXT", "legacy type"
current = c2x("MeetingAt") || ":" || c2x("Meeting At") || ":" || c2x("DATETIME") || ":::::" || c2x("Europe/London") || ":" || c2x("EARLIER")
fields = persistence~decodeFieldSpecs(current)
call assertEqual fields[1]["TIME_ZONE"], "Europe/London", "current timezone"
call assertEqual fields[1]["AMBIGUITY_POLICY"], "EARLIER", "current ambiguity policy"
bad = c2x("Name") || ":" || c2x("Name") || ":" || c2x("TEXT") || ":::::::" || c2x("unexpected")
signal on syntax name ExpectedBad
ignore = persistence~decodeFieldSpecs(bad)
signal off syntax
say "FAIL: non-empty unknown trailing field accepted"
exit 1
ExpectedBad:
  signal off syntax
address command "rm -rf " || root
say "PASS Mini NotNotes persisted field-spec compatibility"
exit 0
assertEqual: procedure
  use strict arg actual, expected, label
  if actual == expected then return
  say "FAIL:" label "expected=" expected "actual=" actual
  exit 1
::requires 'src/MiniNotesPersistence.cls'
