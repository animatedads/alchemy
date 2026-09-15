failures = 0

/* RFC 2877 section 6: initial environment exchange may supply preferred
 * DEVNAME; a subsequent SEND USERVAR DEVNAME means that name collided and the
 * client must send a different name. */
profile = .TN5250TelnetProfile~new("IBM-3179-2", "AIBOT0001")
telnet = .TelnetMachine~new(profile)

telnet~feed("FFFD27"x)
call assertEq telnet~drainOutbound~c2x, "FFFB27", "WILL NEW-ENVIRON"

/* Initial general request: preserve preferred name. */
telnet~feed("FFFA27010003FFF0"x)
expected1 = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "AIBOT0001" || "FFF0"x
call assertEq telnet~drainOutbound~c2x, expected1~c2x, "initial preferred DEVNAME"
call assertEq profile~deviceName, "AIBOT0001", "initial selected name"
call assertEq profile~deviceNameCollisionCount, 0, "initial collision count"

/* Server asks only for DEVNAME again: that is collision processing. */
retry = "FFFA270103"x || "DEVNAME" || "FFF0"x
telnet~feed(retry)
expected2 = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "AIBOT0002" || "FFF0"x
call assertEq telnet~drainOutbound~c2x, expected2~c2x, "first collision retry"
call assertEq profile~deviceName, "AIBOT0002", "first collision selected name"
call assertEq profile~deviceNameCollisionCount, 1, "first collision count"

telnet~feed(retry)
expected3 = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "AIBOT0003" || "FFF0"x
call assertEq telnet~drainOutbound~c2x, expected3~c2x, "second collision retry"
call assertEq profile~deviceName, "AIBOT0003", "second collision selected name"
call assertEq profile~deviceNameCollisionCount, 2, "second collision count"

/* If the very first request is specifically DEVNAME, it is not a collision. */
profile2 = .TN5250TelnetProfile~new("IBM-3179-2", "TERM")
telnet2 = .TelnetMachine~new(profile2)
telnet2~feed("FFFA270103"x || "DEVNAME" || "FFF0"x)
expected4 = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "TERM" || "FFF0"x
call assertEq telnet2~drainOutbound~c2x, expected4~c2x, "first specific DEVNAME request"
call assertEq profile2~deviceName, "TERM", "first specific request preserves name"
call assertEq profile2~deviceNameCollisionCount, 0, "first specific request no collision"

/* Names without a four-digit suffix gain a bounded deterministic suffix. */
telnet2~feed("FFFA270103"x || "DEVNAME" || "FFF0"x)
expected5 = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "TERM0001" || "FFF0"x
call assertEq telnet2~drainOutbound~c2x, expected5~c2x, "generated collision suffix"
call assertEq profile2~deviceName, "TERM0001", "generated retry name"

/* STRICT means the requested device is an identity, not a name seed.  A
 * repeated DEVNAME request is surfaced as a collision and emits no substitute. */
strictProfile = .TN5250TelnetProfile~new("IBM-3179-2", "QPADEV0037", "STRICT")
strictTelnet = .TelnetMachine~new(strictProfile)
strictTelnet~feed("FFFA27010003FFF0"x)
strictInitial = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "QPADEV0037" || "FFF0"x
call assertEq strictTelnet~drainOutbound~c2x, strictInitial~c2x, "strict initial device"
strictTelnet~feed("FFFA270103"x || "DEVNAME" || "FFF0"x)
call assertEq strictTelnet~drainOutbound~length, 0, "strict collision sends no substitute"
call assertEq strictProfile~deviceName, "QPADEV0037", "strict collision preserves exact device"
call assertEq strictProfile~deviceNameCollisionCount, 1, "strict collision counted"
call assertEq strictProfile~strictDeviceCollisionDetected, .true, "strict collision surfaced"
call assertEq strictProfile~collisionPolicy, "STRICT", "strict policy retained"

if failures > 0 then do
  say "FAIL test_tn5250_devname_collision" failures
  exit 1
end
say "PASS test_tn5250_devname_collision"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

::requires "TN5250Wire.cls"
