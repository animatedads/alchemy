parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("LIVE", .IntentionBucketPolicy~new("FLEXIBLE", 50, 5, .false, .false))
service~register("find the last failed compile for Fred", "FIND_FAILED", "LIVE")

discovery = .ChangingDiscovery~new
service~registerDiscoveryProvider(discovery)
service~registerProvider(.LiveScopeProvider~new)

d1 = service~input("find the last failed compile for Fred")
call assertEq "READY", d1~status, "first live decision ready"
call assertEq "JOB00140", d1~slots~at("JOB_ID")~value, "generation one binding"
call assertEq 1, d1~discoveryGeneration, "first discovery generation"
call assertEq 1, service~evidenceFacts("MVS", "LATEST_FAILED_COMPILE")~items, "one live fact"

/* Same revision is a refresh but not a semantic generation change. */
service~refreshDiscovery
call assertEq 1, service~discoveryGeneration, "same revision keeps generation"

/* The world changes; the exact same English must bind from the new snapshot. */
discovery~advance
d2 = service~input("find the last failed compile for Fred")
call assertEq "READY", d2~status, "second live decision ready"
call assertEq "JOB00144", d2~slots~at("JOB_ID")~value, "generation two binding"
call assertEq 2, d2~discoveryGeneration, "changed discovery generation"
facts = service~evidenceFacts("MVS", "LATEST_FAILED_COMPILE")
call assertEq 1, facts~items, "stale discovery fact replaced"
call assertEq "JOB00144", facts~at(1)~value, "only current discovery fact remains"

say "PASS test_dynamic_discovery"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class ChangingDiscovery public
::method init
  expose generation
  generation = 1
::method advance
  expose generation
  generation = 2
  return self
::method discover
  expose generation
  use arg service
  if generation == 1 then do
    revision = "G1"
    job = "JOB00140"
  end
  else do
    revision = "G2"
    job = "JOB00144"
  end
  snapshot = .IntentionDiscoverySnapshot~new("MVS", revision)
  snapshot~addEvidenceFact(.IntentionEvidenceFact~new("MVS", "LATEST_FAILED_COMPILE", job, 100, "MVS_DISCOVERY", "OBSERVED", revision))
  return snapshot

::class LiveScopeProvider public
::method name
  return "LIVE_SCOPE"
::method propose
  use arg service, text
  if translate(strip(text)) \== "FIND THE LAST FAILED COMPILE FOR FRED" then return .Array~new
  fact = service~bestEvidence("MVS", "LATEST_FAILED_COMPILE")
  if fact == .nil then return .Array~new
  p = .IntentionProposal~new("FIND_THE_LAST_FAILED_COMPILE_FOR_FRED", 100, self~name, .true, "live discovery")
  p~putSlot("JOB_ID", fact~value, .false)
  p~addEvidenceFact(fact)
  return .Array~of(p)

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
