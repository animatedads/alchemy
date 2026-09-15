root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  use arg root
  say "RUNTIME REGISTRY V0.3 BUNDLE BUILDER START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)

  b1 = .RuntimeBundleBuilder~new
  call mustOk b1~addFile(root || "/fixtures/bundle/BundleBase_v1.cls", "BundleBase.cls"), "add v1 base"
  call mustOk b1~addFile(root || "/fixtures/bundle/BundleCapability.cls", "BundleCapability.cls"), "add capability"
  built1 = b1~build; call mustOk built1, "build bundle v1"; bundle1 = built1~value
  call assertEq 2, bundle1~unitCount, "two source units"
  call assertEq 1, bundle1~localRequiresRemoved~items, "one local ::requires removed"
  call assertTrue bundle1~canonicalSource~pos("RUNTIME-BUNDLE-LOCAL-REQUIRES: BundleBase.cls") > 0, "local require provenance marker retained"

  reverseBuilder = .RuntimeBundleBuilder~new
  call mustOk reverseBuilder~addFile(root || "/fixtures/bundle/BundleCapability.cls", "BundleCapability.cls"), "add reverse capability"
  call mustOk reverseBuilder~addFile(root || "/fixtures/bundle/BundleBase_v1.cls", "BundleBase.cls"), "add reverse base"
  reverseBuilt = reverseBuilder~build; call mustOk reverseBuilt, "build reverse-order bundle"
  call assertEq bundle1~canonicalSource, reverseBuilt~value~canonicalSource, "bundle canonical source independent of add order"

  call mustOk verifier~pin("fixture:bundle:v1", bundle1~sourceLines), "pin bundle v1"
  artifact1 = .RuntimeArtifact~new("demo.bundle", "CAPABILITY", "1.0.0", "fixture:bundle:v1", "BundleCapability", bundle1~sourceLines)
  staged1 = kernel~stage("prod", artifact1); call mustOk staged1, "stage bundle v1"; g1 = staged1~value
  call mustOk kernel~activate("prod", "demo.bundle", g1~generationId), "activate bundle v1"
  oldLeaseResult = kernel~acquire("prod", "demo.bundle"); call mustOk oldLeaseResult, "hold bundle v1 lease"; oldLease = oldLeaseResult~value
  call assertEq "BUNDLE-ONE:old", oldLease~module~value("old"), "v1 bundle behavior"

  b2 = .RuntimeBundleBuilder~new
  call mustOk b2~addFile(root || "/fixtures/bundle/BundleBase_v2.cls", "BundleBase.cls"), "add v2 base"
  call mustOk b2~addFile(root || "/fixtures/bundle/BundleCapability.cls", "BundleCapability.cls"), "add v2 capability"
  built2 = b2~build; call mustOk built2, "build bundle v2"; bundle2 = built2~value
  call mustOk verifier~pin("fixture:bundle:v2", bundle2~sourceLines), "pin bundle v2"
  artifact2 = .RuntimeArtifact~new("demo.bundle", "CAPABILITY", "2.0.0", "fixture:bundle:v2", "BundleCapability", bundle2~sourceLines)
  staged2 = kernel~stage("prod", artifact2); call mustOk staged2, "stage bundle v2"; g2 = staged2~value
  call mustOk kernel~activate("prod", "demo.bundle", g2~generationId), "activate bundle v2"

  call assertEq "BUNDLE-ONE:still-old", oldLease~module~value("still-old"), "old bundle lease remains v1"
  newLeaseResult = kernel~acquire("prod", "demo.bundle"); call mustOk newLeaseResult, "acquire bundle v2"; newLease = newLeaseResult~value
  call assertEq "BUNDLE-TWO:new", newLease~module~value("new"), "new lease sees v2 bundle"
  call assertTrue g1~packageIdentity \== g2~packageIdentity, "bundle generations own distinct package objects"
  call assertTrue g1~moduleClassIdentity \== g2~moduleClassIdentity, "same public class name is generation-private"

  call mustOk newLease~release, "release v2 lease"
  call mustOk oldLease~release, "release v1 lease"
  call assertEq "RETIRED", g1~state, "v1 bundle retires after old lease drains"

  duplicate = .RuntimeBundleBuilder~new
  call mustOk duplicate~addFile(root || "/fixtures/bundle/BundleBase_v1.cls", "one/BundleBase.cls"), "add first duplicate basename"
  duplicateResult = duplicate~addFile(root || "/fixtures/bundle/BundleBase_v2.cls", "two/BundleBase.cls")
  call assertFalse duplicateResult~ok, "duplicate basename rejected"
  call assertEq "BUNDLE_BASENAME_DUPLICATE", duplicateResult~code, "duplicate basename error code"

  external = .RuntimeBundleBuilder~new
  externalLines = .array~of("::class ExternalRequireProbe public", '::requires "json.cls"')
  call mustOk external~addUnit("ExternalRequireProbe.cls", externalLines), "add external require probe"
  externalBuilt = external~build; call mustOk externalBuilt, "build external require probe"
  call assertTrue externalBuilt~value~canonicalSource~pos('::requires "json.cls"') > 0, "non-bundle ::requires preserved"

  say "  bundle1_lines=" || bundle1~sourceLineCount
  say "  bundle2_lines=" || bundle2~sourceLineCount
  say "  old_state=" || g1~state
  say "RUNTIME REGISTRY V0.3 BUNDLE BUILDER: OK"
  return

mustOk:
  use arg r, label
  if \r~ok then do
    say "FAILED:" label r~code r~detail
    exit 50
  end
  return

assertTrue:
  use arg value, label
  if \value then do; say "FAILED:" label; exit 51; end
  return

assertFalse:
  use arg value, label
  if value then do; say "FAILED:" label; exit 52; end
  return

assertEq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 53
  end
  return

::requires "RuntimeBundleBuilder.cls"
