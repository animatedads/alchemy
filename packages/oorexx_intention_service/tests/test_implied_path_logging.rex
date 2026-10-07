/* Session implication, path learning and logging qualification. */
log = .TestLogService~new
service = .IntentionService~new
service~logger(log)
service~registerBucket("COMMANDS", .IntentionBucketPolicy~new("FLEXIBLE", 1, 0, .false, .false))

service~register("remove tree", .nil, "COMMANDS")~alias("rm tree")
service~register("make directory", .nil, "COMMANDS")~alias("mkdir")
service~register("list directory", .nil, "COMMANDS")~alias("ls")
service~register("unzip archive", .nil, "COMMANDS")~alias("unzip")
service~register("grep records", .nil, "COMMANDS")~alias("grep")

/* First observed successful path. */
call execute service, "rm tree", "REMOVE_TREE"
call execute service, "mkdir", "MAKE_DIRECTORY"
call execute service, "ls", "LIST_DIRECTORY"
call execute service, "unzip", "UNZIP_ARCHIVE"
call execute service, "ls", "LIST_DIRECTORY"
call execute service, "grep", "GREP_RECORDS"
service~sealPath

/* Second run: prediction should become useful before the path completes. */
service~beginPath
call execute service, "rm tree", "REMOVE_TREE"
call execute service, "mkdir", "MAKE_DIRECTORY"
call execute service, "ls", "LIST_DIRECTORY"
call execute service, "unzip", "UNZIP_ARCHIVE"
predictions = service~predictNext
call assertTrue predictions~items > 0, "prediction exists"
call assertEq "LIST_DIRECTORY", predictions~at(1)~intentionId, "second-run next prediction"

nextDecision = service~input("next")
call assertEq "READY", nextDecision~status, "path cue ready"
call assertEq "LIST_DIRECTORY", nextDecision~registration~id, "path cue selects predicted intention"
service~dispatch(nextDecision)

again = service~input("do it again")
call assertEq "READY", again~status, "do it again ready"
call assertEq "LIST_DIRECTORY", again~registration~id, "do it again rolls prior intention"
call assertEq "IMPLIED_SESSION", again~proposal~providerName, "do it again source"

call assertTrue log~hasPoint("INTENTION.INPUT"), "input logged"
call assertTrue log~hasPoint("INTENTION.SELECT"), "selection logged"
call assertTrue log~hasPoint("INTENTION.DISPATCH"), "dispatch logged"
call assertTrue log~hasPoint("INTENTION.PATH.LEARN"), "path learning logged"
call assertTrue log~hasPoint("INTENTION.PATH.PREDICT"), "path prediction logged"

say "PASS test_implied_path_logging"
exit 0

execute: procedure
  use arg service, text, expectedId
  decision = service~input(text)
  call assertEq "READY", decision~status, "ready " || text
  call assertEq expectedId, decision~registration~id, "intent " || text
  service~dispatch(decision)
  return

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::class TestLogService
::method init
  expose events
  events = .Array~new
::method log
  expose events
  use arg level, payload, point
  row = .Directory~new
  row~put(level, "LEVEL")
  row~put(payload, "PAYLOAD")
  row~put(point, "POINT")
  events~append(row)
::method hasPoint
  expose events
  use arg wanted
  do i = 1 to events~items
    if events~at(i)~at("POINT") == wanted then return .true
  end
  return .false

::requires "IntentionService.cls"
