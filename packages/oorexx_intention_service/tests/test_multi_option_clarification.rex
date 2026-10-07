parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("DESK", .IntentionBucketPolicy~new("FLEXIBLE", 50, 10, .false, .false))
service~register("house open window", .DemoEvent~new("OPEN_WINDOW"), "DESK")~tag("CLASS", "HOUSE")~tag("METHOD", "OPEN_WINDOW")
service~register("house open door", .DemoEvent~new("OPEN_DOOR"), "DESK")~tag("CLASS", "HOUSE")~tag("METHOD", "OPEN_DOOR")
service~register("house window attribute", .DemoEvent~new("WINDOW_ATTRIBUTE"), "DESK")~tag("CLASS", "HOUSE")~tag("ATTRIBUTE", "WINDOW")
service~registerProvider(.ThreeWayProvider~new)

choice = service~input("HOUSE WINDOW")
call assertEq "CLARIFY", choice~status, "three-way ambiguity produces clarification"
call assertEq 3, choice~choices~items, "all three bounded alternatives retained"
call assertTrue pos("[1] CLASS: HOUSE METHOD: OPEN_WINDOW", choice~question) > 0, "first semantic option"
call assertTrue pos("[2] CLASS: HOUSE METHOD: OPEN_DOOR", choice~question) > 0, "second semantic option"
call assertTrue pos("[3] CLASS: HOUSE ATTRIBUTE: WINDOW", choice~question) > 0, "third semantic option"

invalid = service~input("9")
call assertEq "CLARIFY", invalid~status, "out-of-range numeric answer stays in clarification"
call assertEq 3, invalid~choices~items, "candidate set survives invalid choice"

selected = service~input("3")
call assertEq "READY", selected~status, "numbered answer resolves retained candidate"
call assertEq "HOUSE_WINDOW_ATTRIBUTE", selected~registration~id, "selected third intention"
call assertEq "WINDOW_ATTRIBUTE", service~dispatch(selected), "selected event dispatches"

/* Bound the rendered choice set even when more candidates tie. */
service2 = .IntentionService~new
service2~setMaxClarificationOptions(3)
service2~registerBucket("DESK", .IntentionBucketPolicy~new("FLEXIBLE", 50, 10, .false, .false))
do i = 1 to 5
  phrase = "candidate" i
  service2~register(phrase, .DemoEvent~new(phrase), "DESK")~tag("CLARIFICATION_LABEL", "OPTION " || i)
end
service2~registerProvider(.FiveWayProvider~new)
bounded = service2~input("ambiguous")
call assertEq "CLARIFY", bounded~status, "five-way tie still clarifies"
call assertEq 3, bounded~choices~items, "choice count obeys service bound"
call assertTrue pos("[3] OPTION 3", bounded~question) > 0, "third bounded choice visible"
call assertTrue pos("OPTION 4", bounded~question) = 0, "fourth choice not rendered beyond bound"

say "PASS test_multi_option_clarification"
exit 0

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

::class DemoEvent public
::method init
  expose answer
  use arg answer
::method invoke
  expose answer
  use arg decision
  return answer

::class ThreeWayProvider public
::method propose
  use arg service, text
  return .Array~of( -
      .IntentionProposal~new("HOUSE_OPEN_WINDOW", 90, "THREE_WAY", .false, "candidate one"), -
      .IntentionProposal~new("HOUSE_OPEN_DOOR", 89, "THREE_WAY", .false, "candidate two"), -
      .IntentionProposal~new("HOUSE_WINDOW_ATTRIBUTE", 88, "THREE_WAY", .false, "candidate three"))

::class FiveWayProvider public
::method propose
  use arg service, text
  proposals = .Array~new
  do i = 1 to 5
    proposals~append(.IntentionProposal~new("CANDIDATE_" || i, 90, "FIVE_WAY", .false, "tie"))
  end
  return proposals

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
