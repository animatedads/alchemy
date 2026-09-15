failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live catalog"
if \loaded~ok then exit 1
catalog = loaded~value
signon = catalog~state("IBM_I_SIGNON")~exemplars[1]~snapshot

observed = .TN5250DeviceIdentity~observeSignon(signon, "AIBOT0001", "AIBOT0001")
call assertTrue observed~ok, "observe confirmed signon display identity"
if observed~ok then do
  id = observed~value
  call assertEq id~assignedDeviceName, "AIBOT0001", "live exemplar assigned device"
  call assertEq id~effectiveDeviceName, "AIBOT0001", "host screen is effective identity"
  call assertEq id~source, "HOST_SIGNON_SCREEN", "source remains screen evidence"
  call assertEq id~generation, signon~generation, "identity generation"
  call assertEq id~evidenceRow, 4, "display-name evidence row"
  call assertTrue id~consistent, "matching negotiated/screen identity"
end

/* Recreate the newly observed server-assigned PUB400 form without changing the
 * historical sign-on exemplar itself. */
rows = signon~textRows
rows[4] = "                                               Display name. . . :   QPADEV0012 "
qpadev = .TerminalSnapshot~new(7, signon~terminalType, signon~rows, signon~columns, signon~cursorRow, signon~cursorColumn, signon~keyboardState, signon~sessionState, rows, signon~fields, signon~capabilities, signon~metadata, signon~contentDigest, signon~layoutFingerprint)
serverAssigned = .TN5250DeviceIdentity~observeSignon(qpadev, "", "")
call assertTrue serverAssigned~ok, "observe server-assigned QPADEV"
if serverAssigned~ok then do
  id2 = serverAssigned~value
  call assertEq id2~requestedDeviceName, "", "no requested device"
  call assertEq id2~negotiatedDeviceName, "", "no DEVNAME negotiated identity"
  call assertEq id2~assignedDeviceName, "QPADEV0012", "host assigned QPADEV"
  call assertEq id2~effectiveDeviceName, "QPADEV0012", "screen assignment becomes effective"
  call assertEq id2~source, "HOST_SIGNON_SCREEN", "server assignment evidence source"
  call assertTrue id2~consistent, "screen-only identity is internally consistent"
  safe = id2~safeDirectory
  call assertEq safe["assigned_device"], "QPADEV0012", "safe evidence directory"
end

mismatch = .TN5250DeviceIdentity~observeSignon(qpadev, "AIBOT0001", "AIBOT0001")
call assertTrue mismatch~ok, "retain conflicting evidence rather than discard it"
if mismatch~ok then do
  id3 = mismatch~value
  call assertEq id3~assignedDeviceName, "QPADEV0012", "conflict host identity"
  call assertEq id3~negotiatedDeviceName, "AIBOT0001", "conflict telnet identity"
  call assertTrue \id3~consistent, "conflicting evidence marked inconsistent"
  call assertEq id3~effectiveDeviceName, "QPADEV0012", "active host display remains effective identity"
end

negotiatedOnly = .TN5250DeviceIdentity~fromNegotiation("AIBOT0001", "AIBOT0003")
call assertEq negotiatedOnly~effectiveDeviceName, "AIBOT0003", "negotiated collision candidate effective without screen"
call assertEq negotiatedOnly~source, "TELNET_DEVNAME", "negotiated source"

main = catalog~state("IBM_I_MAIN_MENU")~exemplars[1]~snapshot
notSignon = .TN5250DeviceIdentity~observeSignon(main, "", "")
call assertTrue \notSignon~ok, "main menu cannot masquerade as signon device evidence"
call assertEq notSignon~code, "DEVICE_IDENTITY_NOT_SIGNON", "non-signon rejection code"

if failures > 0 then do
  say "FAIL test_tn5250_device_identity" failures
  exit 1
end
say "PASS test_tn5250_device_identity"
exit 0

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

::requires "TN5250DeviceIdentity.cls"
::requires "KnownStateJsonStore.cls"
