failures = 0
model = .PresentationSpace5250~new
session = .TerminalSession~new("KNOWN-LIVE", model)

model~writeText(1, 10, "Welcome to A REAL IBM i")
model~writeText(5, 1, "Your user name:")
model~writeText(6, 1, "Password (max. 128):")
call assertTrue model~defineField("USER", 5, 25, 10, "", .true, .false)~ok, "user field"
call assertTrue model~defineField("PASSWORD", 6, 25, 128, "", .true, .false, .true)~ok, "password field"
model~setCursor(5, 25)
model~setKeyboardState("UNLOCKED")
model~setSessionState("OPERATOR_WAIT")
model~hostCommit
snap = session~commit

made = .KnownState5250Factory~ibmISignon(snap, "IBM_I_SIGNON", "TEST_HUMAN")
call assertTrue made~ok, "factory recognizes signon"
state = made~value
call assertEq state~stateId, "IBM_I_SIGNON", "state id"
call assertEq state~exemplarCount, 1, "exemplar stored"

catalog = .KnownStateCatalog~new
call assertTrue catalog~register(state)~ok, "register"
matched = catalog~match(snap)
call assertEq matched~status, "MATCH", "same screen matches"
call assertEq matched~matchedStateId, "IBM_I_SIGNON", "matched id"

/* Volatile header text is deliberately not in the criteria. */
model~writeText(1, 10, "Different server/device/news text")
model~hostCommit
snap2 = session~commit
call assertEq catalog~match(snap2)~status, "MATCH", "volatile text ignored"

/* Structural password change must stop a match. */
other = .PresentationSpace5250~new
otherSession = .TerminalSession~new("OTHER", other)
other~writeText(5, 1, "Your user name:")
other~writeText(6, 1, "Password:")
call assertTrue other~defineField("USER2", 5, 25, 10, "", .true, .false)~ok, "other user"
call assertTrue other~defineField("PASSWORD2", 6, 25, 16, "", .true, .false, .true)~ok, "other password"
other~setCursor(5,25)
other~setKeyboardState("UNLOCKED")
other~setSessionState("OPERATOR_WAIT")
other~hostCommit
otherSnap = otherSession~commit
call assertEq catalog~match(otherSnap)~status, "NO_MATCH", "different field topology not silently accepted"

/* Persistence keeps the safe exemplar and criteria. */
path = "known_5250_test.json"
saved = .KnownStateJsonStore~save(catalog, path)
call assertTrue saved~ok, "save catalog"
text = charin(path, 1, chars(path))
call assertTrue pos("<SECRET>", text) > 0, "nondisplay exemplar explicit redaction marker"
loaded = .KnownStateJsonStore~load(path)
call assertTrue loaded~ok, "load catalog"
call assertEq loaded~value~match(snap)~status, "MATCH", "loaded matcher works"
call sysFileDelete path

if failures > 0 then do
  say "FAIL test_known_state_5250" failures
  exit 1
end
say "PASS test_known_state_5250"
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

::requires "TN5250CredentialLogin.cls"
