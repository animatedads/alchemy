parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)

safePolicy = .IntentionBucketPolicy~new("FLEXIBLE", 55, 12, .true, .false)
carefulPolicy = .IntentionBucketPolicy~new("EXPLICIT", 70, 8, .true, .false)
service~registerBucket("COMMANDS", safePolicy)
service~registerBucket("DESTRUCTIVE_COMMANDS", carefulPolicy)

service~register("list directory", .DemoEvent~new, "COMMANDS")~alias("show files")
formatReg = service~register("format drive", .DemoEvent~new, "DESTRUCTIVE_COMMANDS")
formatReg~alias("format disk")
formatReg~requireSlot("DEVICE", "Which exact device should be formatted?", .true)
formatReg~slotRule("DEVICE", "DRIVE|DEVICE|DISK", "NEXT")

listDecision = service~input("show files please")
call assertEquals "CONFIRM", listDecision~status, "flexible command may resolve loosely"
service~reset

formatDecision = service~input("format drive")
call assertEquals "CLARIFY", formatDecision~status, "destructive command requires device"
call assertContains formatDecision~question, "device", "clarification names missing detail"

formatDecision = service~input("/dev/sdb")
call assertEquals "CONFIRM", formatDecision~status, "clarification detail is recycled into the unresolved request"
formatDecision = service~input("yes")
call assertEquals "READY", formatDecision~status, "explicit target confirmed"
call assertEquals "/DEV/SDB", formatDecision~proposal~slot("DEVICE")~value, "device retained"

say "PASS test_bucket_policy"
exit 0

assertEquals: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertContains: procedure
  use arg haystack, needle, label
  if pos(translate(needle), translate(haystack)) > 0 then return
  say "FAIL" label "text=" haystack
  exit 1

::class DemoEvent public
::method invoke
  use arg decision
  return "OK"

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
