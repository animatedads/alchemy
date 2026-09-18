failures = 0
model = .PresentationSpace5250~new
session = .TerminalSession~new("S1", model)
watch = .TerminalWatchAlong~new(8)
session~addWatcher(watch)
agent = .Terminal5250AgentPort~new(session, model)

model~writeText(1, 25, "PUB400 TEST SIGN ON")
call assertTrue model~defineField("USER", 10, 20, 10, "", .true, .false)~ok, "define user"
call assertTrue model~defineField("PASSWORD", 11, 20, 10, "", .true, .false, .true)~ok, "define password"
model~setCursor(10, 20)
call assertTrue model~setPendingRead("READ_MDT")~ok, "host READ MDT pending"
model~setFingerprints("digest-signon-1", "layout-signon")
model~hostCommit
snap = session~commit
call assertEq snap~generation, 1, "first generation"
call assertEq watch~current~generation, 1, "watch sees commit"
call assertTrue pos("PUB400 TEST SIGN ON", watch~current~visibleText) > 0, "watch visible text"
call assertEq snap~field("PASSWORD")~value, "<SECRET>", "snapshot secret redacted"

observed = agent~snapshot
call assertEq observed~generation, 1, "agent observation"
call assertTrue agent~setField(1, "USER", "FRED")~ok, "set user"
call assertTrue agent~setField(1, "PASSWORD", "SECRET")~ok, "set password"
call assertEq model~modifiedFields~items, 2, "MDT fields"
read = agent~press(1, "ENTER")
call assertTrue read~ok, "press enter"
call assertEq read~value~aidName, "ENTER", "agent receives safe AID receipt"
call assertEq read~value~modifiedFieldIds~items, 2, "safe receipt names changed fields"
wireRead = model~takePendingReadModified
call assertEq wireRead~aidByte~c2x, "F1", "driver receives enter AID byte"
call assertEq wireRead~fields~items, 2, "wire read contains changed fields"
secretSeen = .false
do wf over wireRead~fields
  if wf~fieldId == "PASSWORD" & wf~value == "SECRET" then secretSeen = .true
end
call assertTrue secretSeen, "secret retained only on driver wire path"
postInputSnapshot = agent~snapshot
call assertEq postInputSnapshot~field("PASSWORD")~value, "<SECRET>", "AI snapshot cannot read secret"
call assertEq model~keyboardState, "LOCKED", "keyboard locked after AID"
call assertEq model~sessionState, "HOST_WAIT", "await host after AID"

/* Host changes generation.  Old agent action must be rejected. */
model~setKeyboardState("UNLOCKED")
model~setSessionState("READY")
model~hostCommit
session~commit
stale = agent~moveCursor(1, 1, 1)
call assertTrue \stale~ok, "stale action rejected"
call assertEq stale~code, "STALE_SCREEN", "stale error code"

/* WatchAlong has no methods that can operate the terminal. */
call assertTrue \watch~hasMethod("PRESS"), "watch has no press"
call assertTrue \watch~hasMethod("SETFIELD"), "watch has no setField"
call assertTrue \watch~hasMethod("MOVECURSOR"), "watch has no moveCursor"

if failures > 0 then do
  say "FAIL test_terminal5250" failures
  exit 1
end
say "PASS test_terminal5250"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "Terminal5250.cls"
