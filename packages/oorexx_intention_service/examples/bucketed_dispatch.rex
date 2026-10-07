/* Demonstrates loose and high-specificity intention buckets. */
parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

::class PrintEvent public
::method init
  expose label
  use arg label
::method invoke
  expose label
  use arg decision
  say "EVENT:" label
  return label

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"

service = .IntentionService~new
service~registerProvider(.DeterministicIntentionProvider~new)
service~registerBucket("COMMANDS", .IntentionBucketPolicy~new("FLEXIBLE", 55, 12, .true, .false))
service~registerBucket("DESTRUCTIVE_COMMANDS", .IntentionBucketPolicy~new("EXPLICIT", 75, 8, .true, .false))

service~register("list directory", .PrintEvent~new("LIST"), "COMMANDS")~alias("show files")
formatReg = service~register("format drive", .PrintEvent~new("FORMAT"), "DESTRUCTIVE_COMMANDS")
formatReg~requireSlot("DEVICE", "Which exact device should be formatted?", .true)
formatReg~slotRule("DEVICE", "DRIVE|DEVICE|DISK", "NEXT")

say "Type a request, then answer clarification/confirmation questions.  Empty line exits."
do forever
  pull input
  if strip(input) == "" then leave
  decision = service~input(input)
  say decision~status || ":" decision~question
  if decision~status == "READY" then service~dispatch(decision)
end
