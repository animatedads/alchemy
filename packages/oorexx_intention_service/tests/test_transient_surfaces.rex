parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

service = .IntentionService~new
service~registerBucket("TEST", .IntentionBucketPolicy~new("FLEXIBLE", 50, 8, .false, .false))
service~register("inspect related service", "INSPECT", "TEST")
discovery = .RelatedDiscovery~new
service~registerDiscoveryProvider(discovery)

d = service~input("inspect specialist")
call assertEq "READY", d~status, "transient surface proposes meaning"
call assertEq 1, service~discoverySurfaces~items, "surface active"
call assertEq "RELATED_SERVICE", service~discoverySurfaces~at(1)~surfaceId, "surface id"
call assertEq 1, service~discoverySurfaces~at(1)~discoveryGeneration, "surface generation"

discovery~removeRelated
service~refreshDiscovery
call assertEq 0, service~discoverySurfaces~items, "surface removed with relationship"
d = service~input("inspect specialist")
call assertEq "UNKNOWN", d~status, "removed surface no longer proposes"

say "PASS test_transient_surfaces"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::class RelatedDiscovery public
::method init
  expose present
  present = .true
::method removeRelated
  expose present
  present = .false
  return self
::method discover
  expose present
  use arg service
  if present then do
    s = .IntentionDiscoverySnapshot~new("MANAGEMENT", "WITH_RELATED")
    ad = .IntentionSurfaceAdvertisement~new("RELATED_SERVICE", .RelatedProvider~new, "OBJECT_A", "RELATED_TO", "SESSION", "DISCOVERY", "OBSERVED")
    s~addSurfaceAdvertisement(ad)
    return s
  end
  return .IntentionDiscoverySnapshot~new("MANAGEMENT", "NO_RELATED")

::class RelatedProvider public
::method propose
  use arg service, text
  if translate(strip(text)) \== "INSPECT SPECIALIST" then return .Array~new
  return .Array~of(.IntentionProposal~new("INSPECT_RELATED_SERVICE", 95, "RELATED_SURFACE", .true, "related surface advertisement"))

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
